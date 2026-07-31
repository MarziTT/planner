"""Resilient client for OpenAI-compatible relay providers."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Any

import requests

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class LlmTarget:
    name: str
    api_key: str
    base_url: str
    models: tuple[str, ...]


def _split_models(value: Any, default: str = "gpt-4o-mini") -> tuple[str, ...]:
    if isinstance(value, (list, tuple)):
        models = [str(item).strip() for item in value]
    else:
        models = [item.strip() for item in str(value or default).split(",")]
    return tuple(dict.fromkeys(item for item in models if item)) or (default,)


def resolve_targets(config: dict[str, Any]) -> list[LlmTarget]:
    """Resolve multi-provider config while preserving legacy settings."""
    raw_providers = config.get("LLM_PROVIDERS")
    if isinstance(raw_providers, str):
        try:
            raw_providers = json.loads(raw_providers)
        except (TypeError, ValueError):
            logger.warning("Ignoring invalid LLM_PROVIDERS JSON")
            raw_providers = None

    targets: list[LlmTarget] = []
    if isinstance(raw_providers, list):
        for index, provider in enumerate(raw_providers):
            if not isinstance(provider, dict) or not provider.get("api_key"):
                continue
            targets.append(LlmTarget(
                name=str(provider.get("name") or f"relay-{index + 1}"),
                api_key=str(provider["api_key"]),
                base_url=str(provider.get("base_url") or "https://api.openai.com/v1").rstrip("/"),
                models=_split_models(provider.get("models") or provider.get("model")),
            ))

    legacy_key = str(config.get("OPENAI_API_KEY") or "")
    if legacy_key:
        targets.insert(0, LlmTarget(
            name="primary",
            api_key=legacy_key,
            base_url=str(config.get("OPENAI_BASE_URL") or "https://api.openai.com/v1").rstrip("/"),
            models=_split_models(config.get("OPENAI_MODELS") or config.get("OPENAI_MODEL")),
        ))

    unique: list[LlmTarget] = []
    seen: set[tuple[str, str]] = set()
    for target in targets:
        identity = (target.base_url, target.api_key)
        if identity not in seen:
            seen.add(identity)
            unique.append(target)
    return unique


def chat_completion(
    messages: list[dict[str, Any]],
    config: dict[str, Any],
    *,
    temperature: float = 0.0,
    max_tokens: int = 500,
    timeout: float = 15,
    extra_payload: dict[str, Any] | None = None,
) -> str | None:
    """Try providers and models in order, returning the first valid response."""
    for target in resolve_targets(config):
        url = f"{target.base_url}/chat/completions"
        headers = {"Authorization": f"Bearer {target.api_key}", "Content-Type": "application/json"}
        for model in target.models:
            payload = {
                "model": model,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": max_tokens,
                **(extra_payload or {}),
            }
            try:
                response = requests.post(url, headers=headers, json=payload, timeout=timeout)
                if response.status_code in (401, 403):
                    logger.warning("LLM provider %s rejected credentials", target.name)
                    break
                if response.status_code in (400, 404, 422):
                    logger.warning("LLM model %s unavailable on provider %s", model, target.name)
                    continue
                response.raise_for_status()
                content = response.json()["choices"][0]["message"]["content"]
                if isinstance(content, str) and content.strip():
                    return content.strip()
                logger.warning("LLM provider %s returned empty content", target.name)
            except (requests.Timeout, requests.ConnectionError):
                logger.warning("LLM provider %s is unreachable", target.name)
                break
            except (requests.RequestException, KeyError, TypeError, ValueError) as exc:
                logger.warning("LLM request failed via %s/%s: %s", target.name, model, type(exc).__name__)
                continue
    return None

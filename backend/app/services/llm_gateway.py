"""Resilient client for OpenAI-compatible relay providers."""

from __future__ import annotations

import json
import logging
import threading
import time
from dataclasses import dataclass
from typing import Any

import requests

logger = logging.getLogger(__name__)

_COOLDOWN_SECONDS = 30.0
_RATE_LIMIT_COOLDOWN_SECONDS = 60.0
_provider_cooldowns: dict[str, float] = {}
_cooldown_lock = threading.Lock()


@dataclass(frozen=True)
class LlmTarget:
    name: str
    api_key: str
    base_url: str
    models: tuple[str, ...]
    vision_models: tuple[str, ...] = ()


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
                vision_models=_split_models(provider.get("vision_models"), default="") if provider.get("vision_models") else (),
            ))

    legacy_key = str(config.get("OPENAI_API_KEY") or "")
    if legacy_key:
        targets.insert(0, LlmTarget(
            name="primary",
            api_key=legacy_key,
            base_url=str(config.get("OPENAI_BASE_URL") or "https://api.openai.com/v1").rstrip("/"),
            models=_split_models(config.get("OPENAI_MODELS") or config.get("OPENAI_MODEL")),
            vision_models=_split_models(config.get("OPENAI_VISION_MODELS"), default="") if config.get("OPENAI_VISION_MODELS") else (),
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
    capability: str = "text",
) -> str | None:
    """Try providers and models in order, returning the first valid response."""
    for target in resolve_targets(config):
        if _is_cooling_down(target):
            logger.info("Skipping cooled-down LLM provider %s", target.name)
            continue
        url = f"{target.base_url}/chat/completions"
        headers = {"Authorization": f"Bearer {target.api_key}", "Content-Type": "application/json"}
        models = target.vision_models or target.models if capability == "vision" else target.models
        for model in models:
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
                if response.status_code == 429:
                    cooldown = _retry_after_seconds(response) or _RATE_LIMIT_COOLDOWN_SECONDS
                    _mark_cooldown(target, cooldown)
                    logger.warning("LLM provider %s is rate limited; cooling down %.0fs", target.name, cooldown)
                    break
                if response.status_code >= 500:
                    _mark_cooldown(target)
                    logger.warning("LLM provider %s returned %s; cooling down", target.name, response.status_code)
                    break
                response.raise_for_status()
                content = response.json()["choices"][0]["message"]["content"]
                if isinstance(content, str) and content.strip():
                    return content.strip()
                logger.warning("LLM provider %s returned empty content", target.name)
            except (requests.Timeout, requests.ConnectionError):
                logger.warning("LLM provider %s is unreachable", target.name)
                _mark_cooldown(target)
                break
            except (requests.RequestException, KeyError, TypeError, ValueError) as exc:
                logger.warning("LLM request failed via %s/%s: %s", target.name, model, type(exc).__name__)
                continue
    return None


def _target_key(target: LlmTarget) -> str:
    return f"{target.name}:{target.base_url}"


def _is_cooling_down(target: LlmTarget) -> bool:
    now = time.monotonic()
    with _cooldown_lock:
        until = _provider_cooldowns.get(_target_key(target), 0.0)
        if until <= now:
            _provider_cooldowns.pop(_target_key(target), None)
            return False
        return True


def _retry_after_seconds(response: requests.Response) -> float | None:
    value = response.headers.get("Retry-After")
    try:
        seconds = float(value)
        return max(0.0, min(seconds, 300.0))
    except (TypeError, ValueError):
        return None


def _mark_cooldown(target: LlmTarget, seconds: float = _COOLDOWN_SECONDS) -> None:
    with _cooldown_lock:
        _provider_cooldowns[_target_key(target)] = time.monotonic() + max(0.0, seconds)

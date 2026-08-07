from unittest.mock import Mock, patch

import requests

from app.services import llm_gateway
from app.services.llm_gateway import chat_completion, resolve_targets


def test_resolve_targets_supports_legacy_and_multiple_relays():
    targets = resolve_targets({
        "OPENAI_API_KEY": "primary-key",
        "OPENAI_BASE_URL": "https://primary.example/v1",
        "OPENAI_MODEL": "best-model,fallback-model",
        "LLM_PROVIDERS": [
            {"name": "backup", "api_key": "backup-key", "base_url": "https://backup.example/v1", "models": ["m1"]},
        ],
    })
    assert [target.name for target in targets] == ["primary", "backup"]
    assert targets[0].models == ("best-model", "fallback-model")


def test_resolve_targets_adds_keyless_deepseek_first():
    targets = resolve_targets({
        "DEEPSEEK_API_BASE_URL": "https://deepseek.example/v1/",
        "DEEPSEEK_MODEL": "deepseek-r1:7b",
        "DEEPSEEK_TIMEOUT_SECONDS": "120",
        "OPENAI_API_KEY": "fallback-key",
    })

    assert [target.name for target in targets] == ["deepseek", "primary"]
    assert targets[0].api_key == ""
    assert targets[0].base_url == "https://deepseek.example/v1"
    assert targets[0].timeout == 120


@patch("app.services.llm_gateway.requests.post")
def test_keyless_deepseek_uses_custom_timeout_and_reasoning_fallback(mock_post):
    response = Mock(status_code=200)
    response.raise_for_status.return_value = None
    response.json.return_value = {
        "choices": [{"message": {"content": "", "reasoning": "连接成功"}}],
    }
    mock_post.return_value = response

    result = chat_completion([{"role": "user", "content": "hello"}], {
        "DEEPSEEK_API_BASE_URL": "https://deepseek.example/v1",
        "DEEPSEEK_MODEL": "deepseek-r1:7b",
        "DEEPSEEK_TIMEOUT_SECONDS": 120,
    })

    assert result == "连接成功"
    assert "Authorization" not in mock_post.call_args.kwargs["headers"]
    assert mock_post.call_args.kwargs["timeout"] == 120


@patch("app.services.llm_gateway.requests.post")
def test_vision_requests_skip_text_only_deepseek(mock_post):
    response = Mock(status_code=200)
    response.raise_for_status.return_value = None
    response.json.return_value = {"choices": [{"message": {"content": "vision"}}]}
    mock_post.return_value = response

    result = chat_completion([], {
        "DEEPSEEK_API_BASE_URL": "https://deepseek.example/v1",
        "DEEPSEEK_MODEL": "deepseek-r1:7b",
        "OPENAI_API_KEY": "vision-key",
        "OPENAI_MODEL": "text-model",
        "OPENAI_VISION_MODELS": "vision-model",
    }, capability="vision")

    assert result == "vision"
    assert mock_post.call_args.kwargs["json"]["model"] == "vision-model"


@patch("app.services.llm_gateway.requests.post")
def test_vision_capability_prefers_vision_models(mock_post):
    response = Mock(status_code=200)
    response.raise_for_status.return_value = None
    response.json.return_value = {"choices": [{"message": {"content": "vision"}}]}
    mock_post.return_value = response

    result = chat_completion([], {
        "OPENAI_API_KEY": "key",
        "OPENAI_MODEL": "text-model",
        "OPENAI_VISION_MODELS": "vision-a,vision-b",
    }, capability="vision")

    assert result == "vision"
    assert mock_post.call_args.kwargs["json"]["model"] == "vision-a"


@patch("app.services.llm_gateway.requests.post")
def test_chat_completion_switches_model_then_provider(mock_post):
    unavailable = Mock(status_code=404)
    unavailable.raise_for_status.return_value = None
    server_error = Mock(status_code=503)
    server_error.raise_for_status.side_effect = requests.HTTPError("server down")
    success = Mock(status_code=200)
    success.raise_for_status.return_value = None
    success.json.return_value = {"choices": [{"message": {"content": "ok"}}]}
    mock_post.side_effect = [unavailable, server_error, success]

    result = chat_completion([{"role": "user", "content": "hello"}], {
        "OPENAI_API_KEY": "a",
        "OPENAI_BASE_URL": "https://a.example/v1",
        "OPENAI_MODELS": "model-a,model-b",
        "LLM_PROVIDERS": [{"name": "b", "api_key": "b", "base_url": "https://b.example/v1", "model": "model-c"}],
    })

    assert result == "ok"
    assert [call.kwargs["json"]["model"] for call in mock_post.call_args_list] == ["model-a", "model-b", "model-c"]


@patch("app.services.llm_gateway.requests.post")
def test_auth_failure_skips_remaining_models_on_same_provider(mock_post):
    denied = Mock(status_code=401)
    backup = Mock(status_code=200)
    backup.raise_for_status.return_value = None
    backup.json.return_value = {"choices": [{"message": {"content": "backup"}}]}
    mock_post.side_effect = [denied, backup]

    result = chat_completion([{"role": "user", "content": "hello"}], {
        "OPENAI_API_KEY": "bad",
        "OPENAI_MODELS": "one,two",
        "LLM_PROVIDERS": [{"name": "backup", "api_key": "good", "base_url": "https://b.example/v1", "model": "three"}],
    })

    assert result == "backup"
    assert mock_post.call_count == 2


@patch("app.services.llm_gateway.requests.post")
def test_unreachable_provider_is_temporarily_cooled_down(mock_post):
    llm_gateway._provider_cooldowns.clear()
    mock_post.side_effect = requests.ConnectionError("offline")
    config = {
        "OPENAI_API_KEY": "bad",
        "OPENAI_BASE_URL": "https://offline.example/v1",
        "OPENAI_MODEL": "model-a",
    }

    assert chat_completion([], config) is None
    assert chat_completion([], config) is None
    assert mock_post.call_count == 1


@patch("app.services.llm_gateway.requests.post")
def test_rate_limited_provider_is_cooled_down_and_backup_takes_over(mock_post):
    llm_gateway._provider_cooldowns.clear()
    limited = Mock(status_code=429, headers={"Retry-After": "120"})
    backup = Mock(status_code=200)
    backup.raise_for_status.return_value = None
    backup.json.return_value = {"choices": [{"message": {"content": "backup"}}]}
    mock_post.side_effect = [limited, backup]

    result = chat_completion([], {
        "OPENAI_API_KEY": "primary",
        "OPENAI_BASE_URL": "https://primary.example/v1",
        "OPENAI_MODEL": "primary-model",
        "LLM_PROVIDERS": [{"name": "backup", "api_key": "backup", "base_url": "https://backup.example/v1", "model": "backup-model"}],
    })

    assert result == "backup"
    assert mock_post.call_count == 2

from app.services.agent import _build_multi_intent_prompt, _build_suggest_prompt


def test_zzz_zero_suggestion_prompt_uses_existing_persona_style():
    prompt = _build_suggest_prompt("零", "zzz_zero")

    assert "零号" in prompt
    assert "冷静、克制、短句、任务导向" in prompt
    assert "不要使用热情寒暄、emoji" in prompt


def test_default_suggestion_prompt_does_not_force_zero_style():
    prompt = _build_suggest_prompt("贾维斯", "default")

    assert "零号" not in prompt


def test_butler_tone_is_injected_into_prompts():
    tone = "温和、简洁、先结论后建议"

    suggest_prompt = _build_suggest_prompt("贾维斯", "default", tone)
    multi_prompt = _build_multi_intent_prompt("default", tone)

    assert tone in suggest_prompt
    assert tone in multi_prompt

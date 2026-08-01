from app.services.agent import _build_suggest_prompt


def test_zzz_zero_suggestion_prompt_uses_existing_persona_style():
    prompt = _build_suggest_prompt("零", "zzz_zero")

    assert "零号" in prompt
    assert "冷静、克制、短句、任务导向" in prompt
    assert "不要使用热情寒暄、emoji" in prompt


def test_default_suggestion_prompt_does_not_force_zero_style():
    prompt = _build_suggest_prompt("贾维斯", "default")

    assert "零号" not in prompt

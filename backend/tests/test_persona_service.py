from app.services.persona_service import resolve_persona


def test_zzz_aliases_resolve_to_zero():
    for alias in ("zzz", "zzzTheme", "zzz_zero", "零号", "零"):
        persona = resolve_persona(alias)
        assert persona["preset_id"] == "zzz_zero"
        assert persona["display_name"] == "零"


def test_custom_name_overrides_preset_display_name_only():
    persona = resolve_persona("zzz_zero", custom_name="小零")
    assert persona["display_name"] == "小零"
    assert persona["preset_id"] == "zzz_zero"
    assert "冷静" in persona["style"]

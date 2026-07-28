"""Application clock abstraction used by time-sensitive business logic."""

from __future__ import annotations

from datetime import datetime, timezone, timedelta

from flask import current_app, has_app_context

SHANGHAI_TZ = timezone(timedelta(hours=8))


class Clock:
    """Small injectable clock interface.

    Production uses :class:`SystemClock`; tests can install a fixed clock in
    ``app.extensions["clock"]`` without monkeypatching the standard library.
    """

    def now_utc(self) -> datetime:
        raise NotImplementedError

    def now_local(self) -> datetime:
        raise NotImplementedError


class SystemClock(Clock):
    def now_utc(self) -> datetime:
        return datetime.now(timezone.utc)

    def now_local(self) -> datetime:
        return self.now_utc().astimezone(SHANGHAI_TZ)


def get_clock() -> Clock:
    if has_app_context():
        return current_app.extensions.get("clock", _SYSTEM_CLOCK)
    return _SYSTEM_CLOCK


_SYSTEM_CLOCK = SystemClock()


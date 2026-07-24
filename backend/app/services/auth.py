from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt


def _create_token(*, user_id: int, secret: str, issuer: str, ttl_seconds: int, token_type: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "iss": issuer,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=ttl_seconds)).timestamp()),
        "type": token_type,
        "jti": uuid4().hex,
    }
    return jwt.encode(payload, secret, algorithm="HS256")


def create_token_pair(*, user_id: int, secret: str, issuer: str, access_ttl_seconds: int, refresh_ttl_seconds: int):
    return {
        "accessToken": _create_token(
            user_id=user_id,
            secret=secret,
            issuer=issuer,
            ttl_seconds=access_ttl_seconds,
            token_type="access",
        ),
        "refreshToken": _create_token(
            user_id=user_id,
            secret=secret,
            issuer=issuer,
            ttl_seconds=refresh_ttl_seconds,
            token_type="refresh",
        ),
        "tokenType": "Bearer",
        "expiresIn": access_ttl_seconds,
    }


def decode_token(*, token: str, secret: str, issuer: str):
    return jwt.decode(token, secret, algorithms=["HS256"], issuer=issuer)

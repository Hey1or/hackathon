"""Small first-party email/password auth for the hackathon MVP."""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import time
from typing import Any

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

_TOKEN_SECRET = os.getenv("AUTH_SECRET") or secrets.token_urlsafe(48)
_bearer = HTTPBearer(auto_error=False)
_ITERATIONS = 310_000


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    derived = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, _ITERATIONS)
    return f"pbkdf2_sha256${_ITERATIONS}${_b64(salt)}${_b64(derived)}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algorithm, iterations, salt, expected = stored.split("$")
        if algorithm != "pbkdf2_sha256":
            return False
        salt_bytes = base64.urlsafe_b64decode(salt + "=" * (-len(salt) % 4))
        expected_bytes = base64.urlsafe_b64decode(expected + "=" * (-len(expected) % 4))
        actual = hashlib.pbkdf2_hmac("sha256", password.encode(), salt_bytes, int(iterations))
        return hmac.compare_digest(actual, expected_bytes)
    except (ValueError, TypeError):
        return False


def create_token(user: dict[str, Any]) -> str:
    now = int(time.time())
    header = _b64(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    payload = _b64(json.dumps({"sub": user["id"], "email": user["email"], "name": user.get("name", ""), "role": user["role"], "sv": user.get("session_version", 0), "ev": True, "iat": now, "exp": now + 60 * 60 * 24 * 14}, separators=(",", ":")).encode())
    signing_input = f"{header}.{payload}".encode()
    signature = _b64(hmac.new(_TOKEN_SECRET.encode(), signing_input, hashlib.sha256).digest())
    return f"{header}.{payload}.{signature}"


def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> dict[str, Any]:
    if not credentials:
        raise HTTPException(status_code=401, detail="Войдите в аккаунт, чтобы продолжить")
    try:
        header, payload, signature = credentials.credentials.split(".")
        signing_input = f"{header}.{payload}".encode()
        expected = _b64(hmac.new(_TOKEN_SECRET.encode(), signing_input, hashlib.sha256).digest())
        if not hmac.compare_digest(signature, expected):
            raise ValueError("signature")
        decoded = base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4))
        claims = json.loads(decoded)
        if int(claims.get("exp", 0)) < int(time.time()) or claims.get("ev") is not True:
            raise ValueError("expired")
        from .storage import store

        profile = store.get_user(claims["sub"])
        if not profile or not profile.get("is_active", True):
            raise HTTPException(status_code=403, detail="Доступ к аккаунту отключён администратором")
        if int(claims.get("sv", 0)) != int(profile.get("session_version", 0)):
            raise HTTPException(status_code=401, detail="Пароль изменён. Войдите снова")
        admin_email = os.getenv("ADMIN_EMAIL", "").strip().lower()
        role = "admin" if profile.get("is_owner") or (admin_email and profile["email"].strip().lower() == admin_email) else profile["role"]
        return {"id": profile["id"], "email": profile["email"], "name": profile["name"], "role": role, "is_active": True}
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        raise HTTPException(status_code=401, detail="Сессия истекла. Войдите снова") from None


def require_role(user: dict[str, Any], role: str) -> None:
    if user["role"] != role and not (user["role"] == "admin" and role == "business"):
        raise HTTPException(status_code=403, detail="Для этого действия нужен аккаунт соответствующей роли")


def require_admin(user: dict[str, Any]) -> None:
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Личный кабинет доступен только владельцу сайта")

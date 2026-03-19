"""
JWT token creation/verification and bcrypt password hashing.
Uses bcrypt directly (passlib has compatibility issues with bcrypt 5.x).
"""

from datetime import datetime, timedelta, timezone
from uuid import uuid4
from jose import jwt, JWTError
import bcrypt
from config import settings

# ── In-memory token blacklist (revoked JTIs) ──
_blacklisted_jtis: set[str] = set()


def blacklist_token(token: str) -> None:
    """Revoke a token by adding its JTI to the blacklist."""
    payload = decode_token(token)
    if payload and "jti" in payload:
        _blacklisted_jtis.add(payload["jti"])


def is_token_blacklisted(token: str) -> bool:
    """Check whether a token's JTI has been revoked."""
    payload = decode_token(token)
    if payload and "jti" in payload:
        return payload["jti"] in _blacklisted_jtis
    return False


def hash_password(password: str) -> str:
    """Hash a plain-text password with bcrypt."""
    password_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return bcrypt.checkpw(
        plain_password.encode('utf-8'),
        hashed_password.encode('utf-8'),
    )


def create_access_token(data: dict) -> str:
    """Create a JWT access token with a unique JTI."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire, "type": "access", "jti": str(uuid4())})
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(data: dict) -> str:
    """Create a JWT refresh token with a unique JTI."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh", "jti": str(uuid4())})
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict | None:
    """Decode and verify a JWT token. Returns payload or None if invalid."""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        return payload
    except JWTError:
        return None

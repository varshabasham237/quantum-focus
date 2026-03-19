"""
Auth routes — Register, Login, Refresh Token, Get Profile.
"""

from fastapi import APIRouter, HTTPException, status, Depends
from datetime import datetime, timezone
from bson import ObjectId

from database import get_db
from models.user import (
    UserRegister, UserLogin, UserResponse,
    TokenResponse, RefreshRequest, MessageResponse,
)
from utils.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token,
)
from utils.dependencies import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(user_data: UserRegister):
    """
    Register a new user.
    - Hash password with bcrypt
    - Store in MongoDB
    - Return JWT access + refresh tokens
    """
    db = get_db()

    # Check if email already exists
    existing = await db.users.find_one({"email": user_data.email})
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    # Create user document
    user_doc = {
        "name": user_data.name,
        "email": user_data.email,
        "password_hash": hash_password(user_data.password),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "settings": {
            "focus_duration": 25,
            "short_break": 5,
            "long_break": 15,
            "sessions_before_long": 4,
            "notifications_enabled": True,
            "checkin_interval": 5,
        },
        "strictness_settings": {
            "warnings": 0,
            "level": "NORMAL",
            "active_penalties": [],
            "last_evaluated": None
        }
    }

    result = await db.users.insert_one(user_doc)
    user_id = str(result.inserted_id)

    # Generate tokens
    token_data = {"sub": user_id, "email": user_data.email}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse(
            id=user_id,
            name=user_data.name,
            email=user_data.email,
            created_at=user_doc["created_at"],
        ),
    )


@router.post("/login", response_model=TokenResponse)
async def login(user_data: UserLogin):
    """
    Login with email + password.
    - Verify password against bcrypt hash
    - Return JWT access + refresh tokens
    """
    db = get_db()

    # Find user by email
    user = await db.users.find_one({"email": user_data.email})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    # Verify password
    if not verify_password(user_data.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    user_id = str(user["_id"])
    token_data = {"sub": user_id, "email": user["email"]}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse(
            id=user_id,
            name=user["name"],
            email=user["email"],
            created_at=user.get("created_at"),
        ),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(data: RefreshRequest):
    """
    Refresh access token using a valid refresh token.
    """
    payload = decode_token(data.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    db = get_db()
    user = await db.users.find_one({"_id": ObjectId(payload["sub"])})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    user_id = str(user["_id"])
    token_data = {"sub": user_id, "email": user["email"]}
    new_access = create_access_token(token_data)
    new_refresh = create_refresh_token(token_data)

    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        user=UserResponse(
            id=user_id,
            name=user["name"],
            email=user["email"],
            created_at=user.get("created_at"),
        ),
    )


@router.get("/profile", response_model=UserResponse)
async def get_profile(current_user: dict = Depends(get_current_user)):
    """Get the authenticated user's profile."""
    return UserResponse(
        id=current_user["id"],
        name=current_user["name"],
        email=current_user["email"],
        created_at=current_user.get("created_at"),
    )

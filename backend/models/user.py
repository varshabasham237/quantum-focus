"""
User model — Pydantic schemas for registration, login, and response.
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


class UserRegister(BaseModel):
    """Schema for user registration."""
    name: str = Field(..., min_length=2, max_length=100, examples=["Varsha"])
    email: EmailStr = Field(..., examples=["varsha@example.com"])
    password: str = Field(..., min_length=6, max_length=128, examples=["mypassword123"])


class UserLogin(BaseModel):
    """Schema for user login."""
    email: EmailStr = Field(..., examples=["varsha@example.com"])
    password: str = Field(..., examples=["mypassword123"])


class UserResponse(BaseModel):
    """Schema for user data in API responses."""
    id: str
    name: str
    email: str
    created_at: Optional[str] = None


class TokenResponse(BaseModel):
    """Schema for auth token response."""
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    user: UserResponse


class RefreshRequest(BaseModel):
    """Schema for token refresh."""
    refresh_token: str


class MessageResponse(BaseModel):
    """Generic message response."""
    message: str
    status: str = "success"

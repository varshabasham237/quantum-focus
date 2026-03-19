"""
Session model — Pydantic schemas for study sessions.
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class SessionCreate(BaseModel):
    """Schema for starting a session."""
    focus_duration: int = Field(default=25, ge=5, le=120, description="Focus duration in minutes")


class CheckinCreate(BaseModel):
    """Schema for a focus check-in."""
    observation: str = Field(..., pattern="^(focused|drifting|distracted)$")


class SessionResponse(BaseModel):
    """Schema for session in API responses."""
    id: str
    user_id: str
    start_time: str
    end_time: Optional[str] = None
    duration_min: int = 0
    focus_score: int = 0
    phase: str = "focus"
    pomodoros_completed: int = 0
    checkins: List[dict] = []


class StatsResponse(BaseModel):
    """Schema for daily stats."""
    sessions_count: int = 0
    total_minutes: int = 0
    average_score: int = 0
    streak: int = 0


class WeeklyDay(BaseModel):
    label: str
    date: str
    sessions: int = 0
    minutes: int = 0
    score: int = 0

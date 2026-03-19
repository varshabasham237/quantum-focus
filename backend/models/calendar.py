"""
Calendar & Deadlines models — Pydantic schemas for Module 3.4.
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum
from datetime import date as dt_date


class EventType(str, Enum):
    exam = "exam"
    assignment = "assignment"
    task = "task"
    holiday = "holiday"


class CreateEventRequest(BaseModel):
    """Payload to create a new calendar event."""
    title: str = Field(..., min_length=1, max_length=200, examples=["Math Final Exam"])
    type: EventType = Field(..., examples=["exam"])
    date: dt_date = Field(..., examples=["2026-03-17"])
    note: Optional[str] = Field(None, max_length=500, examples=["Chapter 5 & 6"])


class UpdateEventRequest(BaseModel):
    """Payload to update an existing calendar event (all optional)."""
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    type: Optional[EventType] = None
    date: Optional[dt_date] = None
    note: Optional[str] = Field(None, max_length=500)
    completed: Optional[bool] = None


class CalendarEvent(BaseModel):
    """A single calendar event as stored and returned by the API."""
    id: str
    title: str
    type: EventType
    date: str           # ISO date string "YYYY-MM-DD"
    note: Optional[str] = None
    reminder_sent: bool = False
    completed: bool = False


class EventListResponse(BaseModel):
    """API response for a list of calendar events."""
    events: List[CalendarEvent]
    total: int

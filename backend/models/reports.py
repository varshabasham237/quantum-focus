"""
Reports models — Pydantic schemas for Module 3.5 Analysis & Reports.
"""

from pydantic import BaseModel, Field
from typing import List, Dict


class AppUsageRequest(BaseModel):
    """Payload to log daily app usage."""
    date: str = Field(..., examples=["2026-03-16"])  # YYYY-MM-DD
    apps: Dict[str, int] = Field(..., description="Map of app name to minutes used", examples=[{"Instagram": 45, "YouTube": 30}])


class AppUsageDB(BaseModel):
    """App usage log as stored in MongoDB."""
    user_id: str
    date: str
    apps: Dict[str, int]
    total_minutes: int


class WeeklyReportResponse(BaseModel):
    """Response schema for the weekly report."""
    labels: List[str] = Field(description="Days of the week, e.g. ['Mon', 'Tue', ...]")
    focus_time: List[int] = Field(description="Focus minutes per day")
    distraction_time: List[int] = Field(description="Distraction minutes per day")


class MonthlyReportResponse(BaseModel):
    """Response schema for the monthly report."""
    labels: List[str] = Field(description="Days/Weeks of the month")
    focus_time: List[int] = Field(description="Focus minutes per period")
    distraction_time: List[int] = Field(description="Distraction minutes per period")


class AppUsageItem(BaseModel):
    name: str
    minutes: int


class PerformanceSummaryResponse(BaseModel):
    """Response schema for performance summary."""
    focus_time_total: int
    distraction_time_total: int
    productivity_score: int
    task_completion_rate: int
    top_distracted_apps: List[AppUsageItem]

"""
Reports routes — endpoints for Analysis & Reports (Module 3.5).
"""

from fastapi import APIRouter, Depends, status
from bson import ObjectId
from pydantic import BaseModel

from database import get_db
from models.reports import (
    AppUsageRequest,
    WeeklyReportResponse,
    MonthlyReportResponse,
    PerformanceSummaryResponse,
)
from services.reports_service import (
    generate_weekly_report,
    generate_monthly_report,
    generate_performance_summary,
)
from utils.dependencies import get_current_user

router = APIRouter(prefix="/reports", tags=["Analysis & Reports"])


class FocusSessionLog(BaseModel):
    date: str  # YYYY-MM-DD
    duration: int  # minutes
    focus_score: int


# ─────────────────────────────────────────────────────────────
# POST /reports/app-usage  — Log app usage data
# ─────────────────────────────────────────────────────────────
@router.post("/app-usage", status_code=status.HTTP_201_CREATED)
async def log_app_usage(
    data: AppUsageRequest,
    current_user: dict = Depends(get_current_user)
):
    """Log the time spent on various apps for today."""
    log_entry = {
        "date": data.date,
        "apps": data.apps,
        "total_minutes": sum(data.apps.values()),
    }
    
    db = get_db()
    # Add to reports.app_usage array
    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$push": {"reports.app_usage": log_entry}}
    )
    return {"message": "App usage logged successfully"}


# ─────────────────────────────────────────────────────────────
# POST /reports/focus-session  — Log focus session
# ─────────────────────────────────────────────────────────────
@router.post("/focus-session", status_code=status.HTTP_201_CREATED)
async def log_focus_session(
    data: FocusSessionLog,
    current_user: dict = Depends(get_current_user)
):
    """Log a completed focus session."""
    db = get_db()
    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$push": {"reports.focus_sessions": data.model_dump()}}
    )
    return {"message": "Focus session logged successfully"}


# ─────────────────────────────────────────────────────────────
# GET /reports/weekly  — Get weekly report
# ─────────────────────────────────────────────────────────────
@router.get("/weekly", response_model=WeeklyReportResponse)
async def get_weekly_report(current_user: dict = Depends(get_current_user)):
    """Get the weekly focus and distraction time."""
    report = generate_weekly_report(current_user)
    return WeeklyReportResponse(**report)


# ─────────────────────────────────────────────────────────────
# GET /reports/monthly  — Get monthly report
# ─────────────────────────────────────────────────────────────
@router.get("/monthly", response_model=MonthlyReportResponse)
async def get_monthly_report(current_user: dict = Depends(get_current_user)):
    """Get the monthly focus and distraction time."""
    report = generate_monthly_report(current_user)
    return MonthlyReportResponse(**report)


# ─────────────────────────────────────────────────────────────
# GET /reports/summary  — Get performance summary
# ─────────────────────────────────────────────────────────────
@router.get("/summary", response_model=PerformanceSummaryResponse)
async def get_performance_summary(current_user: dict = Depends(get_current_user)):
    """Get overall productivity score, totals, and task completion."""
    summary = generate_performance_summary(current_user)
    return PerformanceSummaryResponse(**summary)

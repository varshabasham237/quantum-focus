from fastapi import APIRouter, Depends, Query
from datetime import datetime, timezone
from utils.dependencies import get_current_user
from models.analytics import BehaviorAnalysisResponse
from services.ai_analyzer import calculate_behavior_metrics

router = APIRouter(prefix="/analytics", tags=["AI / ML Module"])

@router.get("/behavior-analysis", response_model=BehaviorAnalysisResponse)
async def get_behavior_analysis(
    date: str = Query(None, description="Date in YYYY-MM-DD. Defaults to today."),
    current_user: dict = Depends(get_current_user)
):
    """
    Module 7: Analyze student behavior.
    Calculates Distraction Score, Productivity Index, and Risk Level based on app usage limits,
    task completion rates, and focus session strictness penalties for the requested date.
    """
    if not date:
        date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        
    user_id = str(current_user["_id"])
    result = await calculate_behavior_metrics(user_id, date)
    return BehaviorAnalysisResponse(**result)

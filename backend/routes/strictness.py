from fastapi import APIRouter, Depends, HTTPException, status
from bson import ObjectId
from datetime import date
from database import get_db
from models.strictness import StrictnessStatus, EvaluateRequest
from services.strictness_service import evaluate_user_strictness
from utils.dependencies import get_current_user

router = APIRouter(prefix="/strictness", tags=["Strictness System"])

@router.get("/status", response_model=StrictnessStatus)
async def get_strictness_status(current_user: dict = Depends(get_current_user)):
    """Get the current strictness level and warnings for the user."""
    db = get_db()
    user = await db.users.find_one({"_id": ObjectId(current_user["id"])})
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    strictness = user.get("strictness_settings", {
        "warnings": 0,
        "level": "NORMAL",
        "active_penalties": [],
        "last_evaluated": None
    })
    strictness["strictness_level"] = strictness.pop("level", "NORMAL")
    return StrictnessStatus(**strictness)

@router.post("/evaluate", response_model=StrictnessStatus)
async def evaluate_strictness(req: EvaluateRequest, current_user: dict = Depends(get_current_user)):
    """Evaluate performance for a specific date and update strictness."""
    result = await evaluate_user_strictness(current_user["id"], req.date)
    
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    result["strictness_level"] = result.pop("level", "NORMAL")
    return StrictnessStatus(**result)

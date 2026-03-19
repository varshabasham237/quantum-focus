"""
Planner routes — generate and update study plans.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from bson import ObjectId

from database import get_db
from models.planner import StudyPlanResponse, PlanUpdateRequest, PlanMode
from services.planner_service import generate_plans
from utils.dependencies import get_current_user

router = APIRouter(prefix="/planner", tags=["Study Planner"])


@router.get("/generate", response_model=StudyPlanResponse)
async def generate_study_plan(current_user: dict = Depends(get_current_user)):
    """
    Generate Heavy / Medium / Light study plans based on the student's profile.
    Uses daily_study_hours, subjects, and subject_ranking from onboarding data.
    """
    profile = current_user.get("student_profile", {})
    academic = profile.get("academic", {})
    lifestyle = profile.get("lifestyle", {})

    daily_study_hours = float(academic.get("daily_study_hours", 4.0))
    subjects = list(academic.get("subjects", []))
    subject_ranking = list(academic.get("subject_ranking", subjects))

    if not subjects:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please complete your academic profile first (add subjects).",
        )

    plans = generate_plans(daily_study_hours, subjects, subject_ranking)

    return StudyPlanResponse(
        heavy=plans[PlanMode.heavy],
        medium=plans[PlanMode.medium],
        light=plans[PlanMode.light],
    )


@router.patch("/update", response_model=dict)
async def update_plan_blocks(
    data: PlanUpdateRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Save user edits to study blocks (subject name + duration only).
    Break and free-time blocks cannot be modified — validated server-side.
    """
    # Re-generate the base plan to validate block indices
    profile = current_user.get("student_profile", {})
    academic = profile.get("academic", {})

    daily_study_hours = float(academic.get("daily_study_hours", 4.0))
    subjects = list(academic.get("subjects", []))
    subject_ranking = list(academic.get("subject_ranking", subjects))

    if not subjects:
        raise HTTPException(status_code=400, detail="No academic profile found.")

    plans = generate_plans(daily_study_hours, subjects, subject_ranking)
    plan = plans[data.mode]

    # Apply updates — only to editable (study) blocks
    for update in data.updates:
        idx = update.block_index
        if idx < 0 or idx >= len(plan.blocks):
            raise HTTPException(
                status_code=400,
                detail=f"Invalid block index: {idx}",
            )
        block = plan.blocks[idx]
        if not block.editable:
            raise HTTPException(
                status_code=403,
                detail=f"Block {idx} (type={block.type}) is locked and cannot be edited.",
            )
        if update.subject is not None:
            block.subject = update.subject
        if update.duration_min is not None:
            block.duration_min = update.duration_min

    # Persist the customised plan to MongoDB under the user document
    db = get_db()
    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": {f"custom_plan.{data.mode}": plan.model_dump()}},
    )

    return {"message": f"{data.mode} plan updated successfully", "blocks": len(plan.blocks)}

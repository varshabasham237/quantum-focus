"""
Planner routes — generate and update study plans.
"""

from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from bson import ObjectId

from database import get_db
from models.planner import (
    StudyPlanResponse, PlanUpdateRequest, PlanMode,
    DailySessionRequest, DailySessionResponse,
    DailySessionTaskUpdate,
)
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


# ── Daily Session (lock a plan for today) ─────────────────────────

@router.post("/daily-session", response_model=DailySessionResponse)
async def lock_daily_session(
    data: DailySessionRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Lock a study plan mode for today. Once locked, the session cannot be
    changed until the next day.
    """
    today = date.today().isoformat()
    db = get_db()

    # Check if already locked today
    existing = current_user.get("daily_session")
    if existing and existing.get("date") == today and existing.get("locked"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Today's session is already locked. Come back tomorrow!",
        )

    # Generate the plan for the chosen mode
    profile = current_user.get("student_profile", {})
    academic = profile.get("academic", {})
    daily_study_hours = float(academic.get("daily_study_hours", 4.0))
    subjects = list(academic.get("subjects", []))
    subject_ranking = list(academic.get("subject_ranking", subjects))

    if not subjects:
        raise HTTPException(status_code=400, detail="No academic profile found.")

    plans = generate_plans(daily_study_hours, subjects, subject_ranking)
    plan = plans[data.mode]

    # Build the locked session document
    session_doc = {
        "date": today,
        "mode": data.mode.value,
        "blocks": [b.model_dump() for b in plan.blocks],
        "locked": True,
    }

    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": {"daily_session": session_doc}},
    )

    return DailySessionResponse(**session_doc)


@router.get("/daily-session")
async def get_daily_session(current_user: dict = Depends(get_current_user)):
    """
    Get today's locked session. Returns null if no session is locked for today.
    """
    today = date.today().isoformat()
    existing = current_user.get("daily_session")

    if existing and existing.get("date") == today:
        return existing

    return {"locked": False, "date": today, "message": "No session locked for today"}


@router.patch("/daily-session/task")
async def update_daily_session_task(
    data: DailySessionTaskUpdate,
    current_user: dict = Depends(get_current_user),
):
    """
    Update the specific task string for a block in today's locked session.
    """
    today = date.today().isoformat()
    db = get_db()

    existing = current_user.get("daily_session")
    if not existing or existing.get("date") != today:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No daily session locked for today.",
        )

    blocks = existing.get("blocks", [])
    idx = data.block_index
    if idx < 0 or idx >= len(blocks):
        raise HTTPException(status_code=400, detail="Invalid block index.")

    block = blocks[idx]
    if block.get("type") != "study":
        raise HTTPException(status_code=403, detail="Can only set tasks for study blocks.")

    # Update the task string
    db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": {f"daily_session.blocks.{idx}.task": data.task}},
    )

    return {"message": "Task updated successfully", "task": data.task}



"""
Profile routes — Student details collection (onboarding).
"""

from fastapi import APIRouter, Depends, HTTPException, status
from bson import ObjectId

from database import get_db
from models.student_profile import (
    StudentProfile, StudentProfileResponse, ProfileUpdate,
    PersonalDetails, AcademicDetails, LifestyleDetails,
)
from utils.dependencies import get_current_user

router = APIRouter(prefix="/profile", tags=["Student Profile"])


@router.post("/complete", response_model=StudentProfileResponse)
async def save_complete_profile(
    profile: StudentProfile,
    current_user: dict = Depends(get_current_user),
):
    """Save complete student profile (all 3 steps at once)."""
    db = get_db()

    profile_doc = {
        "personal": profile.personal.model_dump(),
        "academic": profile.academic.model_dump(),
        "lifestyle": profile.lifestyle.model_dump(),
        "profile_complete": True,
    }

    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": {"student_profile": profile_doc}},
    )

    return StudentProfileResponse()


@router.post("/step/personal", response_model=dict)
async def save_personal_details(
    data: PersonalDetails,
    current_user: dict = Depends(get_current_user),
):
    """Save Step 1: Personal Details."""
    db = get_db()
    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": {"student_profile.personal": data.model_dump()}},
    )
    return {"message": "Personal details saved", "step": 1}


@router.post("/step/academic", response_model=dict)
async def save_academic_details(
    data: AcademicDetails,
    current_user: dict = Depends(get_current_user),
):
    """Save Step 2: Academic Details."""
    db = get_db()
    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": {"student_profile.academic": data.model_dump()}},
    )
    return {"message": "Academic details saved", "step": 2}


@router.post("/step/lifestyle", response_model=dict)
async def save_lifestyle_details(
    data: LifestyleDetails,
    current_user: dict = Depends(get_current_user),
):
    """Save Step 3: Lifestyle & Distraction Details."""
    db = get_db()
    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": {
            "student_profile.lifestyle": data.model_dump(),
            "student_profile.profile_complete": True,
        }},
    )
    return {"message": "Lifestyle details saved, profile complete", "step": 3}


@router.get("/", response_model=dict)
async def get_profile(current_user: dict = Depends(get_current_user)):
    """Get the student's profile."""
    profile = current_user.get("student_profile", {})
    return {
        "profile": profile,
        "profile_complete": profile.get("profile_complete", False),
    }


@router.patch("/", response_model=dict)
async def update_profile(
    data: ProfileUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update editable student details (hobbies, daily_study_hours)."""
    db = get_db()
    
    update_fields = {}
    if data.hobbies is not None:
        update_fields["student_profile.lifestyle.hobbies"] = data.hobbies
    if data.daily_study_hours is not None:
        update_fields["student_profile.academic.daily_study_hours"] = data.daily_study_hours

    if not update_fields:
        return {"message": "No fields to update"}

    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": update_fields},
    )
    return {"message": "Profile updated successfully"}

"""
Student Profile model — Pydantic schemas for onboarding data.
"""

from pydantic import BaseModel, Field
from typing import List, Optional


class PersonalDetails(BaseModel):
    """Step 1: Personal Details"""
    age: int = Field(..., ge=10, le=60, examples=[18])
    category: str = Field(..., pattern="^(school|ug|pg)$", examples=["ug"])


class AcademicDetails(BaseModel):
    """Step 2: Academic Details"""
    num_subjects: int = Field(..., ge=1, le=20, examples=[5])
    subjects: List[str] = Field(..., min_length=1, examples=[["Math", "Physics", "Chemistry"]])
    subject_ranking: List[str] = Field(..., min_length=1, examples=[["Math", "Chemistry", "Physics"]])
    daily_study_hours: float = Field(..., ge=0, le=24, examples=[4.0])


class LifestyleDetails(BaseModel):
    """Step 3: Lifestyle & Distraction Details"""
    hobbies: List[str] = Field(default=[], examples=[["Reading", "Gaming"]])
    hobby_hours: float = Field(default=0, ge=0, le=24, examples=[2.0])
    daily_distractions: List[str] = Field(default=[], examples=[["Social Media", "YouTube"]])
    distracting_apps: List[str] = Field(default=[], examples=[["Instagram", "TikTok", "YouTube"]])


class StudentProfile(BaseModel):
    """Complete student profile combining all three steps."""
    personal: PersonalDetails
    academic: AcademicDetails
    lifestyle: LifestyleDetails


class StudentProfileResponse(BaseModel):
    """Response after saving profile."""
    message: str = "Profile saved successfully"
    profile_complete: bool = True


class ProfileUpdate(BaseModel):
    """Request to update editable parts of the profile."""
    hobbies: Optional[List[str]] = Field(None, examples=[["Reading", "Gaming", "Coding"]])
    daily_study_hours: Optional[float] = Field(None, ge=0, le=24, examples=[5.0])

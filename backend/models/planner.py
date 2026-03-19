"""
Planner models — Pydantic schemas for study plan generation.
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum


class PlanMode(str, Enum):
    heavy = "heavy"
    medium = "medium"
    light = "light"


class BlockType(str, Enum):
    study = "study"
    break_ = "break"
    free = "free"


class PlanBlock(BaseModel):
    """A single time block in the plan."""
    type: BlockType
    subject: Optional[str] = None       # only for 'study' blocks
    duration_min: int                    # duration in minutes
    editable: bool = False               # only study blocks are editable


class DayPlan(BaseModel):
    """A full day plan for one mode."""
    mode: PlanMode
    total_study_min: int
    total_break_min: int
    total_free_min: int
    blocks: List[PlanBlock]


class StudyPlanResponse(BaseModel):
    """API response containing all 3 mode plans."""
    heavy: DayPlan
    medium: DayPlan
    light: DayPlan


class PlanBlockUpdate(BaseModel):
    """Payload to update a single study block."""
    block_index: int = Field(..., ge=0)
    subject: Optional[str] = None
    duration_min: Optional[int] = Field(None, ge=5, le=120)


class PlanUpdateRequest(BaseModel):
    """Request to update editable fields in a specific plan."""
    mode: PlanMode
    updates: List[PlanBlockUpdate]

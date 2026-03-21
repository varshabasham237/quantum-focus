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
    task: Optional[str] = None          # the specific to-do task (e.g., "Read Chapter 3")
    duration_min: int                    # duration in minutes
    editable: bool = False               # only study blocks are editable


class DailySessionTaskUpdate(BaseModel):
    block_index: int
    task: str


class BlockCompleteRequest(BaseModel):
    """Mark a study block as completed or mark it pending (incomplete)."""
    block_index: int
    completed: bool              # True = done, False = not finished
    priority_boost: bool = False # bump priority when pending


class PendingTask(BaseModel):
    """A study task deferred to a future session."""
    subject: str
    task: Optional[str] = None
    duration_min: int
    priority: int = 1            # higher = schedule first tomorrow


class RescheduleResponse(BaseModel):
    message: str
    blocks_added: int


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


class DailySessionRequest(BaseModel):
    """Request to lock a study plan mode for today."""
    mode: PlanMode


class DailySessionResponse(BaseModel):
    """Response containing the locked daily session."""
    date: str
    mode: PlanMode
    blocks: List[PlanBlock]
    locked: bool = True

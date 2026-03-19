from pydantic import BaseModel
from typing import Optional
from datetime import date

class StrictnessStatus(BaseModel):
    warnings: int = 0
    strictness_level: str = "NORMAL"
    active_penalties: list[str] = []
    last_evaluated: Optional[str] = None

class EvaluateRequest(BaseModel):
    date: str # ISO date string

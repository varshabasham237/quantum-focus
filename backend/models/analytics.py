from pydantic import BaseModel, Field

class BehaviorAnalysisResponse(BaseModel):
    """
    Response schema for the AI/ML Module 7 Behavior Analysis.
    """
    date: str = Field(..., description="The date of analysis in YYYY-MM-DD")
    distraction_score: int = Field(..., ge=0, description="0-100, lower is better. Heavily impacted by Focus switches and emergency exits.")
    productivity_index: int = Field(..., ge=0, description="0-100, higher is better. Measures task completion and schedule adherence.")
    risk_level: str = Field(..., description="Categorical risk: LOW, MEDIUM, or HIGH burnout/procrastination risk.")
    factors: dict = Field(default_factory=dict, description="A breakdown of the metrics used to calculate the scores.")

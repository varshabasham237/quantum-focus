from pydantic import BaseModel, Field
from typing import Dict

class QuantumEvaluationResponse(BaseModel):
    """
    Response schema for the Quantum-Inspired Module 8 Decision Engine.
    """
    date: str
    distraction_score: int
    productivity_index: int
    
    superposition_probabilities: Dict[str, float] = Field(
        ..., 
        description="The calculated probability amplitudes of each state before collapse."
    )
    collapsed_state: str = Field(
        ..., 
        description="The final state after the quantum wave-function collapse simulation."
    )
    triggered_action: str = Field(
        ..., 
        description="The automated action executed by the backend based on the collapsed state."
    )
    message: str

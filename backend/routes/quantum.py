from fastapi import APIRouter, Depends
from utils.dependencies import get_current_user
from models.quantum import QuantumEvaluationResponse
from services.quantum_engine import evaluate_quantum_state

router = APIRouter(prefix="/quantum", tags=["Quantum-Inspired Module"])

@router.post("/evaluate-state", response_model=QuantumEvaluationResponse)
async def evaluate_state(current_user: dict = Depends(get_current_user)):
    """
    Module 8: Quantum Engine.
    Forces a wave-function collapse on the student's behavior state.
    Calculates probability weights from AI Analytics:
    - Collapses to |Focused> -> Returns Motivational Alert
    - Collapses to |Partially Distracted> -> Suggests Break
    - Collapses to |Highly Distracted> -> Forces focus session lock OR increments strictness warning penalty!
    """
    user_id = str(current_user["_id"])
    result = await evaluate_quantum_state(user_id)
    return QuantumEvaluationResponse(**result)

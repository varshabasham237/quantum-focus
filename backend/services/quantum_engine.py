import random
from datetime import datetime, timezone
from database import get_db
from bson import ObjectId
from services.ai_analyzer import calculate_behavior_metrics
from services.strictness_service import apply_emergency_exit_penalty

# Define the basis states
STATE_FOCUSED = "|Focused>"
STATE_PARTIAL = "|Partially Distracted>"
STATE_HIGH = "|Highly Distracted>"

async def evaluate_quantum_state(user_id: str) -> dict:
    """
    Module 8: Quantum-Inspired Decision Engine.
    Simulates a wave-function collapse based on real-time behavior metrics
    to trigger automated enforcement actions.
    """
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    
    # 1. Fetch AI Behavior Metrics (acts as observation amplitudes)
    metrics = await calculate_behavior_metrics(user_id, date_str)
    D = metrics["distraction_score"]
    P = metrics["productivity_index"]
    
    # 2. Probability Weighting Logic
    # D & P are 0-100. Let's convert them to relative weights.
    
    # If perfectly focused (High P, Low D) -> Strong weight towards |Focused>
    weight_focused = max(0.1, P / 100.0)
    
    # If highly distracted (High D) -> Strong weight towards |Highly Distracted>
    weight_high = max(0.1, D / 100.0)
    
    # Partial is the natural baseline/uncertainty
    weight_partial = 0.5 
    
    # Normalize weights so they sum to 100%
    total_weight = weight_focused + weight_high + weight_partial
    prob_focused = weight_focused / total_weight
    prob_partial = weight_partial / total_weight
    prob_high = weight_high / total_weight
    
    # 3. Simulated State Collapse (Quantum Measurement)
    states = [STATE_FOCUSED, STATE_PARTIAL, STATE_HIGH]
    weights = [prob_focused, prob_partial, prob_high]
    
    collapsed_state = random.choices(states, weights=weights, k=1)[0]
    
    # 4. Action Trigger based on Collapsed State
    triggered_action = "None"
    message = ""
    db = get_db()
    
    if collapsed_state == STATE_FOCUSED:
        triggered_action = "Motivational Alert"
        message = "Observation collapsed to |Focused>. Keep up the great work!"
        
    elif collapsed_state == STATE_PARTIAL:
        triggered_action = "Suggest Break"
        message = "Observation collapsed to |Partially Distracted>. Consider taking a 5-minute break."
        
    elif collapsed_state == STATE_HIGH:
        # 50/50 Chance to either FORCE LOCK the session, or ADD STRICTNESS WARNING
        punishment = random.choice(["LOCK_APPS", "INCREASE_STRICTNESS"])
        
        if punishment == "LOCK_APPS":
            # Force the current session to lock, stripping their switches
            await db.focus_sessions.update_one(
                {"user_id": user_id},
                {"$set": {"focus_locked": True, "switch_count": 3}}
            )
            triggered_action = "Lock Apps"
            message = "Observation collapsed to |Highly Distracted>. Your focus session has been FORCE LOCKED."
        else:
            # Reusing the emergency exit penalty function to add a warning
            await apply_emergency_exit_penalty(user_id)
            triggered_action = "Increase Strictness"
            message = "Observation collapsed to |Highly Distracted>. Added a Warning to your Adaptive Strictness Profile."

    return {
        "date": date_str,
        "distraction_score": D,
        "productivity_index": P,
        "superposition_probabilities": {
            STATE_FOCUSED: round(prob_focused, 3),
            STATE_PARTIAL: round(prob_partial, 3),
            STATE_HIGH: round(prob_high, 3),
        },
        "collapsed_state": collapsed_state,
        "triggered_action": triggered_action,
        "message": message
    }

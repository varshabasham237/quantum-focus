from datetime import datetime, timedelta, timezone
from bson import ObjectId
from database import get_db

async def evaluate_user_strictness(user_id: str, date_str: str) -> dict:
    """
    Evaluates a user's performance for the given date and updates their
    strictness warnings and level if productivity was too low.
    """
    db = get_db()
    
    # 1. Fetch user to check current strictness and prevent double evaluation
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        return {"error": "User not found"}
        
    strictness = user.get("strictness_settings", {
        "warnings": 0,
        "level": "NORMAL",
        "active_penalties": [],
        "last_evaluated": None
    })
    
    if strictness["last_evaluated"] == date_str:
        return strictness  # Already evaluated today
        
    # 2. Check performance for the target date
    # In a real scenario, this would aggregate focus vs distraction time
    # For now, we simulate pulling the 'productivity_score' from sessions on that date
    
    # Get start and end of the target date
    try:
        target_date = datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        return {"error": "Invalid date format"}
        
    start_time = target_date.replace(hour=0, minute=0, second=0).isoformat()
    end_time = target_date.replace(hour=23, minute=59, second=59).isoformat()
    
    # Find sessions completed on that date
    sessions = await db.sessions.find({
        "user_id": user_id,
        "completed_at": {"$gte": start_time, "$lt": end_time}
    }).to_list(length=100)
    
    # Simple metric: Needs at least 1 session with a positive score, or we assume productivity was 0
    total_score = sum([s.get("productivity_score", 0) for s in sessions if "productivity_score" in s])
    
    # 3. Apply Rules
    # Determine if poor performance (e.g. total_score < 50)
    poor_performance = total_score < 50
    
    if poor_performance:
        strictness["warnings"] += 1
    else:
        # Gradually reduce warnings if performance is good
        strictness["warnings"] = max(0, strictness["warnings"] - 1)
        
    # Cap warnings at 3
    strictness["warnings"] = min(3, strictness["warnings"])
    
    # 4. Map Warnings to Strictness Level and Penalties
    if strictness["warnings"] == 0:
        strictness["level"] = "NORMAL"
        strictness["active_penalties"] = []
    elif strictness["warnings"] == 1:
        strictness["level"] = "WARNING_1"
        strictness["active_penalties"] = ["None (Warning Only)"]
    elif strictness["warnings"] == 2:
        strictness["level"] = "WARNING_2"
        strictness["active_penalties"] = ["Free Mode Halved"]
    elif strictness["warnings"] >= 3:
        strictness["level"] = "LOCKDOWN"
        strictness["active_penalties"] = ["Strict App Blocking", "Free Mode Disabled"]
        
    strictness["last_evaluated"] = date_str
    
    # 5. Save back to DB
    await db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"strictness_settings": strictness}}
    )
    
    return strictness

async def apply_emergency_exit_penalty(user_id: str) -> dict:
    """
    Applies an immediate penalty (1 warning) for using the Emergency Exit.
    """
    db = get_db()
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        return {"error": "User not found"}
        
    strictness = user.get("strictness_settings", {
        "warnings": 0,
        "level": "NORMAL",
        "active_penalties": [],
        "last_evaluated": None
    })
    
    # Increment warnings by 1, cap at 3
    strictness["warnings"] = min(3, strictness["warnings"] + 1)
    
    # Recalculate level
    if strictness["warnings"] == 0:
        strictness["level"] = "NORMAL"
        strictness["active_penalties"] = []
    elif strictness["warnings"] == 1:
        strictness["level"] = "WARNING_1"
        strictness["active_penalties"] = ["None (Warning Only)"]
    elif strictness["warnings"] == 2:
        strictness["level"] = "WARNING_2"
        strictness["active_penalties"] = ["Free Mode Halved"]
    elif strictness["warnings"] >= 3:
        strictness["level"] = "LOCKDOWN"
        strictness["active_penalties"] = ["Strict App Blocking", "Free Mode Disabled"]
        
    await db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"strictness_settings": strictness}}
    )
    
    return strictness

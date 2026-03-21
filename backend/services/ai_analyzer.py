from datetime import datetime, timezone
from bson import ObjectId
from database import get_db

async def calculate_behavior_metrics(user_id: str, date_str: str) -> dict:
    """
    Module 7: AI/ML Rule-Based Analyzer.
    Analyzes the student's behavior for a given date and returns Distraction Score,
    Productivity Index, and categorical Risk Level.
    """
    db = get_db()
    
    # Defaults
    distraction_score = 0
    tasks_completed = 0
    tasks_total = 0
    planned_minutes = 0
    actual_minutes = 0
    
    # 1. Evaluate Task Completion Rate from `events`
    # Match events that are due on this date (simple check)
    target_date_start = f"{date_str}T00:00:00"
    target_date_end = f"{date_str}T23:59:59"
    events_cursor = db.events.find({
        "user_id": user_id,
        "date": {"$gte": target_date_start, "$lt": target_date_end}
    })
    events = await events_cursor.to_list(length=100)
    for ev in events:
        tasks_total += 1
        if ev.get("is_completed", False):
            tasks_completed += 1

    # 2. Evaluate App Usage / Focus Session Stability from `focus_sessions`
    # We pull the current session stats (switch count, emergency exit usage)
    focus_sess = await db.focus_sessions.find_one({"user_id": user_id})
    if focus_sess:
        switches = focus_sess.get("switch_count", 0)
        distraction_score += switches * 10
        
        # Penalize if they used an emergency exit today
        if focus_sess.get("last_emergency_exit_date") == date_str:
            distraction_score += 50
            
    # 3. Evaluate Schedule Adherence & Focus Quality from `sessions`
    # (Timer sessions completed today)
    sessions_cursor = db.sessions.find({
        "user_id": user_id,
        "start_time": {"$gte": target_date_start, "$lt": target_date_end}
    })
    timer_sessions = await sessions_cursor.to_list(length=100)
    
    for s in timer_sessions:
        planned_minutes += s.get("focus_duration", 25)
        # If ended_at exists, they completed the session block.
        if "end_time" in s and s["end_time"]:
            actual_minutes += s.get("duration_min", 25)
            
        # Penalize for drifting/distracted check-ins
        for checkin in s.get("checkins", []):
            if checkin.get("observation") in ["drifting", "distracted"]:
                distraction_score += 20
                
    # Normalize Productivity Score (0-100)
    # 50% from Tasks, 50% from Timer Adherence
    task_score = 0
    if tasks_total > 0:
        task_score = (tasks_completed / tasks_total) * 50
    else:
        task_score = 25 # Default mid-score if no tasks planned
        
    time_score = 0
    if planned_minutes > 0:
        adherence_ratio = min(actual_minutes / planned_minutes, 1.0)
        time_score = adherence_ratio * 50
    else:
        time_score = 25
        
    productivity_index = int(task_score + time_score)
    
    # Cap Distraction Score at 100
    distraction_score = min(100, distraction_score)
    
    # 4. Determine Risk Level
    if productivity_index < 40 and distraction_score > 60:
        risk_level = "HIGH"
    elif productivity_index < 60 or distraction_score > 40:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"
        
    return {
        "date": date_str,
        "distraction_score": distraction_score,
        "productivity_index": productivity_index,
        "risk_level": risk_level,
        "factors": {
            "tasks_completion_ratio": f"{tasks_completed}/{tasks_total}",
            "focus_minutes_ratio": f"{actual_minutes}/{planned_minutes}",
            "switches_used": focus_sess.get("switch_count", 0) if focus_sess else 0,
            "emergency_exit_used": focus_sess.get("last_emergency_exit_date") == date_str if focus_sess else False
        }
    }

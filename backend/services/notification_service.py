from datetime import datetime, timezone, timedelta
from database import get_db
from models.notifications import Notification
from bson import ObjectId

# Alert types
SOFT_REMINDER = "SOFT_REMINDER"
WARNING = "WARNING"
RESTRICTION_ALERT = "RESTRICTION_ALERT"
MOTIVATION = "MOTIVATION"

async def _create_notification(db, user_id: str, type: str, title: str, message: str, unique_key: str = None):
    """
    Helper to insert a notification. 
    Uses unique_key to prevent duplicate generation (e.g., reminding about the same assignment).
    """
    # If a unique key applies, check if it already exists within the last 24h
    if unique_key:
        past_24h = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
        exists = await db.notifications.find_one({
            "user_id": user_id, 
            "unique_key": unique_key,
            "created_at": {"$gte": past_24h}
        })
        if exists:
            return

    notif = {
        "user_id": user_id,
        "type": type,
        "title": title,
        "message": message,
        "is_read": False,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    if unique_key:
        notif["unique_key"] = unique_key
        
    await db.notifications.insert_one(notif)


async def generate_pending_notifications(user_id: str):
    """
    Module 9: Main background function to generate automated notifications.
    Checks deadlines, AI metrics, and strictness state.
    """
    db = get_db()
    now_utc = datetime.now(timezone.utc)
    now_iso = now_utc.isoformat()
    tomorrow_iso = (now_utc + timedelta(days=1)).isoformat()
    
    # 1. TRIGGER: Deadlines (Events within 24 hours, not completed)
    expiring_events_cursor = db.events.find({
        "user_id": user_id,
        "is_completed": False,
        "date": {"$gte": now_iso, "$lt": tomorrow_iso}
    })
    events = await expiring_events_cursor.to_list(length=50)
    for ev in events:
        await _create_notification(
            db, user_id, SOFT_REMINDER, 
            "Upcoming Deadline", 
            f"Your task '{ev.get('title')}' is due within 24 hours.",
            unique_key=f"deadline_{str(ev['_id'])}"
        )
        
    # 2. TRIGGER: AI Analyzer & Strictness (Daily Warnings)
    # Check strictness profile
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if user and "strictness_settings" in user:
        warnings = user["strictness_settings"].get("warnings", 0)
        lockdown = user["strictness_settings"].get("lockdown_enabled", False)
        
        if lockdown:
            await _create_notification(
                db, user_id, RESTRICTION_ALERT,
                "Lockdown Active",
                "You have accumulated 3 warnings! All free-time features are temporarily disabled.",
                unique_key="lockdown_alert"
            )
        elif warnings > 0:
            await _create_notification(
                db, user_id, WARNING,
                "Strictness Warning",
                f"You currently have {warnings}/3 warnings. Another rule violation will trigger Lockdown.",
                unique_key=f"warning_{warnings}"
            )
            
    # Note: Triggering the Quantum Engine or AI Analyzer directly here 
    # would result in an infinite loop if not gated, as they are computed on-demand.
    # The current assumption is that the Quantum Engine writes RESTRICTION_ALERT internally,
    # or the user checks their stats. For now, checking Strictness Profile is sufficient.

async def get_unread_notifications(user_id: str) -> list:
    """Fetch unread notifications for a user."""
    db = get_db()
    # First, generate pending notifications so they are fresh
    await generate_pending_notifications(user_id)
    
    cursor = db.notifications.find({"user_id": user_id, "is_read": False}).sort("created_at", -1)
    notifs = []
    async for d in cursor:
        d["_id"] = str(d["_id"])
        notifs.append(d)
    return notifs

async def mark_notification_read(notif_id: str, user_id: str):
    """Mark a notification as read."""
    db = get_db()
    await db.notifications.update_one(
        {"_id": ObjectId(notif_id), "user_id": user_id},
        {"$set": {"is_read": True}}
    )
    return {"message": "Notification marked as read."}

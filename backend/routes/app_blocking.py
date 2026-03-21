from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from datetime import datetime, timezone
from database import get_db
from models.app_blocking import BlockedApp
from utils.security import get_current_user

router = APIRouter(prefix="/app-blocking", tags=["app-blocking"])

# ─────────────────────────────────────────────────────────────────────────────
# BLOCKLIST MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/blocklist", response_model=List[dict])
async def get_blocklist(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Return the current user's list of blocked apps."""
    user_id = str(current_user["_id"])
    cursor = db["blocked_apps"].find({"user_id": user_id}, {"_id": 0})
    apps = await cursor.to_list(length=200)
    return apps


@router.post("/blocklist", status_code=status.HTTP_201_CREATED)
async def add_to_blocklist(
    app: BlockedApp,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Add an app to the user's blocklist."""
    user_id = str(current_user["_id"])

    # Prevent duplicates
    existing = await db["blocked_apps"].find_one({
        "user_id": user_id,
        "package_name": app.package_name
    })
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="App is already in the blocklist."
        )

    record = {
        "user_id": user_id,
        "package_name": app.package_name,
        "app_name": app.app_name,
        "added_at": datetime.now(timezone.utc).isoformat()
    }
    await db["blocked_apps"].insert_one(record)
    return {"message": f"{app.app_name} added to blocklist."}


@router.delete("/blocklist/{package_name}")
async def remove_from_blocklist(
    package_name: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Remove an app from the user's blocklist."""
    user_id = str(current_user["_id"])
    result = await db["blocked_apps"].delete_one({
        "user_id": user_id,
        "package_name": package_name
    })
    if result.deleted_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="App not found in blocklist."
        )
    return {"message": "App removed from blocklist."}


# ─────────────────────────────────────────────────────────────────────────────
# SESSION CONTROL
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/session/start")
async def start_blocking_session(
    payload: dict,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Mark focus blocking as active for the current user session.
    payload: { "duration_minutes": int }
    """
    user_id = str(current_user["_id"])
    duration_minutes = payload.get("duration_minutes", 0)
    end_time = None
    if duration_minutes > 0:
        from datetime import timedelta
        end_time = (datetime.now(timezone.utc) + timedelta(minutes=duration_minutes)).isoformat()

    await db["focus_sessions"].update_one(
        {"user_id": user_id},
        {"$set": {
            "session_active": True,
            "started_at": datetime.now(timezone.utc).isoformat(),
            "ends_at": end_time,
            "switch_count": 0,
            "focus_locked": False
        }},
        upsert=True
    )
    return {
        "message": "Focus blocking session started.",
        "ends_at": end_time
    }


@router.post("/session/toggle")
async def toggle_blocking_session(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Register a mode switch (pause/resume). Used for 5.3 Mode Switching limits."""
    user_id = str(current_user["_id"])
    session = await db["focus_sessions"].find_one({"user_id": user_id})
    if not session:
        return {"message": "No active session to toggle."}

    new_count = session.get("switch_count", 0) + 1
    locked = new_count >= 3
    is_active = not session.get("session_active", False)

    # If locked, force active
    if locked:
        is_active = True

    await db["focus_sessions"].update_one(
        {"user_id": user_id},
        {"$set": {
            "session_active": is_active,
            "switch_count": new_count,
            "focus_locked": locked
        }}
    )

    return {
        "switch_count": new_count,
        "focus_locked": locked,
        "session_active": is_active
    }


@router.post("/session/stop")
async def stop_blocking_session(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Mark focus blocking as inactive."""
    user_id = str(current_user["_id"])
    await db["focus_sessions"].update_one(
        {"user_id": user_id},
        {"$set": {
            "session_active": False,
            "ended_at": datetime.now(timezone.utc).isoformat()
        }},
        upsert=True
    )
    return {"message": "Focus blocking session ended."}


@router.get("/session/status")
async def get_session_status(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get current focus session status for the user."""
    user_id = str(current_user["_id"])
    session = await db["focus_sessions"].find_one(
        {"user_id": user_id},
        {"_id": 0}
    )
    if not session:
        return {"session_active": False}
    return session

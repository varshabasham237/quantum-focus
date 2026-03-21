from fastapi import APIRouter, Depends
from utils.dependencies import get_current_user
from models.notifications import NotificationResponse
from services.notification_service import get_unread_notifications, mark_notification_read

router = APIRouter(prefix="/notifications", tags=["Notification Engine (Module 9)"])

@router.get("/", response_model=NotificationResponse)
async def fetch_notifications(current_user: dict = Depends(get_current_user)):
    """
    Module 9: Retrieves unread notifications for the user.
    Automatically generates new pending notifications based on deadlines and behavior metrics before returning.
    """
    user_id = str(current_user["_id"])
    notifs = await get_unread_notifications(user_id)
    return NotificationResponse(notifications=notifs)

@router.patch("/{notif_id}/read")
async def read_notification(notif_id: str, current_user: dict = Depends(get_current_user)):
    """Marks a single notification as read, dismissing it."""
    user_id = str(current_user["_id"])
    return await mark_notification_read(notif_id, user_id)

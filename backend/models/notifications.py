from pydantic import BaseModel, Field
from datetime import datetime, timezone

class Notification(BaseModel):
    """
    Schema for a generic Notification.
    Types: SOFT_REMINDER, WARNING, RESTRICTION_ALERT, MOTIVATION
    """
    id: str = Field(alias="_id", default=None)
    user_id: str
    type: str = Field(..., description="SOFT_REMINDER, WARNING, RESTRICTION_ALERT, MOTIVATION")
    title: str
    message: str
    is_read: bool = False
    created_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

class NotificationResponse(BaseModel):
    notifications: list[Notification]

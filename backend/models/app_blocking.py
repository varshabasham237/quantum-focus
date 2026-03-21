from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class BlockedApp(BaseModel):
    package_name: str
    app_name: str

class BlockedAppRecord(BlockedApp):
    id: Optional[str] = None
    user_id: str
    added_at: Optional[datetime] = None

    class Config:
        from_attributes = True

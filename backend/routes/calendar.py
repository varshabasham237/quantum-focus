"""
Calendar routes — CRUD endpoints for calendar events (Module 3.4).
All routes require a valid JWT (via get_current_user dependency).
"""

import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from bson import ObjectId

from database import get_db
from models.calendar import (
    CreateEventRequest,
    UpdateEventRequest,
    CalendarEvent,
    EventListResponse,
)
from services.calendar_service import (
    get_upcoming_reminders,
    sort_events_by_date,
    build_event_dict,
)
from utils.dependencies import get_current_user

router = APIRouter(prefix="/calendar", tags=["Calendar & Deadlines"])


# ─────────────────────────────────────────────────────────────
# POST /calendar/events  — create a new event
# ─────────────────────────────────────────────────────────────
@router.post("/events", response_model=CalendarEvent, status_code=status.HTTP_201_CREATED)
async def create_event(
    data: CreateEventRequest,
    current_user: dict = Depends(get_current_user),
):
    """Add a new exam, assignment, task, or holiday to the user's calendar."""
    event_id = str(uuid.uuid4())
    event_dict = build_event_dict(event_id, data.model_dump())

    db = get_db()
    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$push": {"calendar_events": event_dict}},
    )

    return CalendarEvent(**event_dict)


# ─────────────────────────────────────────────────────────────
# GET /calendar/events  — list all events (sorted by date)
# ─────────────────────────────────────────────────────────────
@router.get("/events", response_model=EventListResponse)
async def list_events(current_user: dict = Depends(get_current_user)):
    """Return all calendar events for the authenticated user, sorted by date."""
    events = current_user.get("calendar_events", [])
    sorted_events = sort_events_by_date(events)
    return EventListResponse(
        events=[CalendarEvent(**e) for e in sorted_events],
        total=len(sorted_events),
    )


# ─────────────────────────────────────────────────────────────
# PATCH /calendar/events/{event_id}  — update an event
# ─────────────────────────────────────────────────────────────
@router.patch("/events/{event_id}", response_model=CalendarEvent)
async def update_event(
    event_id: str,
    data: UpdateEventRequest,
    current_user: dict = Depends(get_current_user),
):
    """Edit the title, type, date, or note of an existing event."""
    events: list = current_user.get("calendar_events", [])
    event = next((e for e in events if e.get("id") == event_id), None)

    if event is None:
        raise HTTPException(status_code=404, detail="Event not found.")

    # Apply only the fields that were provided
    updates = data.model_dump(exclude_none=True)
    if "date" in updates:
        updates["date"] = str(updates["date"])   # convert date → ISO string

    event.update(updates)

    db = get_db()
    await db.users.update_one(
        {"_id": ObjectId(current_user["id"]), "calendar_events.id": event_id},
        {"$set": {"calendar_events.$": event}},
    )

    return CalendarEvent(**event)


# ─────────────────────────────────────────────────────────────
# DELETE /calendar/events/{event_id}  — remove an event
# ─────────────────────────────────────────────────────────────
@router.delete("/events/{event_id}", status_code=status.HTTP_200_OK)
async def delete_event(
    event_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Remove a calendar event by its ID."""
    events: list = current_user.get("calendar_events", [])
    if not any(e.get("id") == event_id for e in events):
        raise HTTPException(status_code=404, detail="Event not found.")

    db = get_db()
    await db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$pull": {"calendar_events": {"id": event_id}}},
    )

    return {"message": "Event deleted successfully", "id": event_id}


# ─────────────────────────────────────────────────────────────
# GET /calendar/reminders  — events due within 2 days
# ─────────────────────────────────────────────────────────────
@router.get("/reminders", response_model=EventListResponse)
async def get_reminders(current_user: dict = Depends(get_current_user)):
    """
    Return events that fall within the next 2 days (and haven't been reminded yet).
    The Flutter app uses this to show the reminder banner.
    """
    events = current_user.get("calendar_events", [])
    due = get_upcoming_reminders(events)
    return EventListResponse(events=[CalendarEvent(**e) for e in due], total=len(due))

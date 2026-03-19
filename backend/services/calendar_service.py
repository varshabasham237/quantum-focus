"""
Calendar Service — pure helpers for reminder logic and event sorting.

No database I/O here; all functions operate on plain dicts
(as returned from MongoDB).
"""

from datetime import date, timedelta
from typing import List


def get_upcoming_reminders(events: List[dict]) -> List[dict]:
    """
    Return events whose date is exactly 2 days from today
    (or already overdue but not yet reminded — within 0..2 days).

    Args:
        events: raw event dicts from MongoDB (each must have a 'date' str
                in ISO format YYYY-MM-DD and 'reminder_sent' bool).

    Returns:
        Subset of events that qualify for a 2-day-before reminder.
    """
    today = date.today()
    reminder_window_end = today + timedelta(days=2)
    due = []

    for ev in events:
        if ev.get("reminder_sent"):
            continue
        try:
            event_date = date.fromisoformat(ev["date"])
        except (KeyError, ValueError):
            continue

        # Remind if event is today, tomorrow, or 2 days away
        if today <= event_date <= reminder_window_end:
            due.append(ev)

    return due


def sort_events_by_date(events: List[dict]) -> List[dict]:
    """
    Sort events chronologically (ascending).
    Events with unparseable dates are pushed to the end.
    """
    def _key(ev: dict):
        try:
            return date.fromisoformat(ev["date"])
        except (KeyError, ValueError):
            return date.max

    return sorted(events, key=_key)


def build_event_dict(event_id: str, data: dict) -> dict:
    """
    Construct a clean event dict ready for MongoDB insertion.

    Args:
        event_id: UUID string for this event.
        data: validated fields from CreateEventRequest.

    Returns:
        dict suitable for $push into users.calendar_events.
    """
    return {
        "id": event_id,
        "title": data["title"],
        "type": data["type"],
        "date": str(data["date"]),          # stored as ISO string
        "note": data.get("note"),
        "reminder_sent": False,
        "completed": False,
    }

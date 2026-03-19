"""
Reports Service — logic for calculating and aggregating analytics data.
"""

from datetime import date, timedelta
from typing import List, Dict, Any


def get_date_range(days: int, end_date: date = None) -> List[str]:
    """Get a list of ISO date strings for the past `days` days, ending on `end_date`."""
    if end_date is None:
        end_date = date.today()
    return [(end_date - timedelta(days=i)).isoformat() for i in range(days - 1, -1, -1)]


def aggregate_focus_time(focus_logs: List[dict], date_range: List[str]) -> List[int]:
    """Aggregate focus duration by date."""
    daily_focus = {d: 0 for d in date_range}
    for log in focus_logs:
        log_date = log.get("date")
        if log_date in daily_focus:
            daily_focus[log_date] += log.get("duration", 0)
    return [daily_focus[d] for d in date_range]


def aggregate_distraction_time(usage_logs: List[dict], date_range: List[str], distracting_apps: List[str]) -> List[int]:
    """Aggregate time spent on distracting apps."""
    daily_distraction = {d: 0 for d in date_range}
    for log in usage_logs:
        log_date = log.get("date")
        if log_date in daily_distraction:
            apps = log.get("apps", {})
            for app, minutes in apps.items():
                if app in distracting_apps:
                    daily_distraction[log_date] += minutes
    return [daily_distraction[d] for d in date_range]


def generate_weekly_report(user: dict) -> dict:
    """Generate the weekly report for the user."""
    # Data sources
    reports_data = user.get("reports", {})
    focus_logs = reports_data.get("focus_sessions", [])
    usage_logs = reports_data.get("app_usage", [])
    
    # User's distracting apps from profile
    profile = user.get("student_profile", {}).get("lifestyle", {})
    distracting_apps = profile.get("distracting_apps", [])

    # Date range (last 7 days including today)
    date_range = get_date_range(7)
    labels = [date.fromisoformat(d).strftime("%a") for d in date_range] # Mon, Tue, etc.

    focus_time = aggregate_focus_time(focus_logs, date_range)
    distraction_time = aggregate_distraction_time(usage_logs, date_range, distracting_apps)

    return {
        "labels": labels,
        "focus_time": focus_time,
        "distraction_time": distraction_time,
    }


def generate_monthly_report(user: dict) -> dict:
    """Generate the monthly report (last 4 weeks grouped by week)."""
    reports_data = user.get("reports", {})
    focus_logs = reports_data.get("focus_sessions", [])
    usage_logs = reports_data.get("app_usage", [])
    profile = user.get("student_profile", {}).get("lifestyle", {})
    distracting_apps = profile.get("distracting_apps", [])

    labels = ["Week 1", "Week 2", "Week 3", "Week 4"]
    focus_time = [0, 0, 0, 0]
    distraction_time = [0, 0, 0, 0]

    today = date.today()
    for w in range(4):
        # Week 4 is the most recent 7 days, Week 1 is 21-28 days ago
        week_end = today - timedelta(days=(3 - w) * 7)
        week_dates = get_date_range(7, week_end)
        
        focus_time[w] = sum(aggregate_focus_time(focus_logs, week_dates))
        distraction_time[w] = sum(aggregate_distraction_time(usage_logs, week_dates, distracting_apps))

    return {
        "labels": labels,
        "focus_time": focus_time,
        "distraction_time": distraction_time,
    }


def generate_performance_summary(user: dict) -> dict:
    """Generate overall performance summary."""
    reports_data = user.get("reports", {})
    focus_logs = reports_data.get("focus_sessions", [])
    usage_logs = reports_data.get("app_usage", [])
    profile = user.get("student_profile", {}).get("lifestyle", {})
    distracting_apps = profile.get("distracting_apps", [])
    events = user.get("calendar_events", [])

    # Totals
    focus_time_total = sum(log.get("duration", 0) for log in focus_logs)
    
    # Top distracted apps
    app_totals = {}
    distraction_time_total = 0
    for log in usage_logs:
        for app, minutes in log.get("apps", {}).items():
            if app in distracting_apps:
                app_totals[app] = app_totals.get(app, 0) + minutes
                distraction_time_total += minutes
                
    # Sort apps by usage
    sorted_apps = sorted([{"name": k, "minutes": v} for k, v in app_totals.items()], key=lambda x: x["minutes"], reverse=True)
    top_apps = sorted_apps[:5]

    # Task completion
    tasks = [e for e in events if e.get("type") == "task"]
    completed_tasks = [e for e in tasks if e.get("completed", False)]
    task_completion_rate = int((len(completed_tasks) / len(tasks) * 100)) if tasks else 0

    # Productivity score (Focus time vs Distraction Time ratio, simplified)
    total_time = focus_time_total + distraction_time_total
    if total_time == 0:
        productivity_score = 0
    else:
        productivity_score = int((focus_time_total / total_time) * 100)
        
    # Scale it to be 50 if they are equal, lower if distractions are higher
    # Include task completion in score
    if productivity_score > 0:
        productivity_score = int(productivity_score * 0.7 + task_completion_rate * 0.3)

    return {
        "focus_time_total": focus_time_total,
        "distraction_time_total": distraction_time_total,
        "productivity_score": productivity_score,
        "task_completion_rate": task_completion_rate,
        "top_distracted_apps": top_apps,
    }

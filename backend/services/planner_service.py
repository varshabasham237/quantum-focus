"""
Planner Service — generates Heavy / Medium / Light study plans
from the student's profile data.

Algorithm overview:
  - Heavy  : 80% of daily_study_hours → study, 15% → breaks, 5% → free
  - Medium : 60% → study, 20% → breaks, 20% → free
  - Light  : 40% → study, 20% → breaks, 40% → free

Study blocks are distributed across subjects using subject_ranking
(index 0 = strongest, last = weakest). Weaker subjects get slightly
more study time.
"""

from typing import List, Optional
from models.planner import DayPlan, PlanBlock, BlockType, PlanMode


# Minimum + maximum durations (minutes)
MIN_STUDY_BLOCK = 20
MAX_STUDY_BLOCK = 60
BREAK_DURATION = 10      # fixed short break
LONG_BREAK_DURATION = 20 # after every 2 study blocks


def _distribute_study_time(
    subjects: List[str],
    total_study_min: int,
) -> List[int]:
    """
    Distribute total study minutes across subjects.
    Weaker subjects (later in ranking) get a 20% bonus each step.
    Returns a list of durations matching len(subjects).
    """
    n = len(subjects)
    if n == 0:
        return []

    # Weight: last subject (weakest) gets highest weight
    weights = [1.0 + 0.2 * i for i in range(n)]
    total_weight = sum(weights)
    durations = [
        max(MIN_STUDY_BLOCK, round((w / total_weight) * total_study_min / 5) * 5)
        for w in weights
    ]

    # Scale to fit total budget
    current_total = sum(durations)
    if current_total > 0:
        scale = total_study_min / current_total
        durations = [max(MIN_STUDY_BLOCK, round(d * scale / 5) * 5) for d in durations]

    return durations


def _build_blocks(
    subjects: List[str],
    study_durations: List[int],
    total_free_min: int,
) -> List[PlanBlock]:
    """
    Interleave study blocks with breaks and append free time at the end.
    Pattern: study → break → study → long_break → study → break → ...
    """
    blocks: List[PlanBlock] = []

    for i, (subject, duration) in enumerate(zip(subjects, study_durations)):
        # Study block (editable)
        blocks.append(PlanBlock(
            type=BlockType.study,
            subject=subject,
            duration_min=duration,
            editable=True,
        ))

        # After every 2nd study block → long break, else short break
        # (but not after the last block)
        if i < len(subjects) - 1:
            is_long = (i % 2 == 1)
            blocks.append(PlanBlock(
                type=BlockType.break_,
                duration_min=LONG_BREAK_DURATION if is_long else BREAK_DURATION,
                editable=False,
            ))

    # Free time block at the end (locked)
    if total_free_min > 0:
        blocks.append(PlanBlock(
            type=BlockType.free,
            duration_min=total_free_min,
            editable=False,
        ))

    return blocks


def generate_plans(
    daily_study_hours: float,
    subjects: List[str],
    subject_ranking: Optional[List[str]] = None,
) -> dict:
    """
    Generate Heavy, Medium, and Light study plans.

    Args:
        daily_study_hours: Total available study time per day (hours)
        subjects: List of subject names
        subject_ranking: Ordered list of subjects (strong → weak).
                         Falls back to `subjects` order if not provided.

    Returns:
        dict with keys 'heavy', 'medium', 'light' each being a DayPlan.
    """
    if not subjects:
        subjects = ["General Study"]

    # Use subject_ranking order if available, otherwise as-is
    ordered_subjects = subject_ranking if subject_ranking else subjects

    total_min = int(daily_study_hours * 60)

    # Mode ratios: (study%, break%, free%)
    modes = {
        PlanMode.heavy:  (0.80, 0.15, 0.05),
        PlanMode.medium: (0.60, 0.20, 0.20),
        PlanMode.light:  (0.40, 0.20, 0.40),
    }

    plans = {}
    for mode, (study_r, break_r, free_r) in modes.items():
        total_study = max(MIN_STUDY_BLOCK, round(total_min * study_r / 5) * 5)
        total_break = max(BREAK_DURATION, round(total_min * break_r / 5) * 5)
        total_free  = max(0, round(total_min * free_r / 5) * 5)

        study_durations = _distribute_study_time(ordered_subjects, total_study)
        blocks = _build_blocks(ordered_subjects, study_durations, total_free)

        plans[mode] = DayPlan(
            mode=mode,
            total_study_min=total_study,
            total_break_min=total_break,
            total_free_min=total_free,
            blocks=blocks,
        )

    return plans

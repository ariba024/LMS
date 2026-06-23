"""
modules/gamification/question_generator.py

Generate a daily quiz question from course content using Claude.
One question is generated per course per calendar date and cached in the DB.
"""

from __future__ import annotations

import json
import re
from datetime import date

import anthropic

from api.config import settings


_SYSTEM = (
    "You are an expert safety-training instructional designer. "
    "Generate ONE high-quality multiple-choice question that tests genuine, "
    "practical understanding of the course material — not trivial recall. "
    "Return ONLY valid JSON with no markdown fences, no explanation."
)

_SCHEMA = """{
  "question": "Question text here?",
  "options": ["Option A text", "Option B text", "Option C text", "Option D text"],
  "correct_index": 0,
  "explanation": "One sentence explaining why this is correct."
}"""


def generate_daily_question(
    course_title: str,
    course_content: str,
    date_str: str | None = None,
) -> dict:
    """
    Generate a daily question for the given course.

    Returns a dict with keys: question, options (list[str] of 4),
    correct_index (0-3), explanation.
    Raises RuntimeError if ANTHROPIC_API_KEY is not set.
    """
    if not settings.anthropic_api_key:
        raise RuntimeError("ANTHROPIC_API_KEY not set — daily question generation unavailable.")

    date_label = date_str or date.today().isoformat()

    prompt = (
        f"Course title: {course_title}\n"
        f"Date: {date_label}\n\n"
        f"Course content (excerpt):\n{course_content[:6000]}\n\n"
        f"Task: Generate ONE daily quiz question that a safety professional would find challenging "
        f"but fair. Focus on practical application, not definitions.\n\n"
        f"Return ONLY this JSON structure (no markdown, no extra text):\n{_SCHEMA}"
    )

    client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
    resp = client.messages.create(
        model=settings.llm_model,
        max_tokens=600,
        system=_SYSTEM,
        messages=[{"role": "user", "content": prompt}],
    )

    raw = resp.content[0].text.strip()
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)

    data = json.loads(raw)

    if len(data.get("options", [])) != 4:
        raise ValueError("Question generator returned wrong number of options.")

    return {
        "question": data["question"],
        "options": data["options"],
        "correct_index": int(data["correct_index"]),
        "explanation": data.get("explanation", ""),
    }

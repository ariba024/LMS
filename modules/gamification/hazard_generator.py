"""
modules/gamification/hazard_generator.py

Generate Spot-the-Hazard game sessions for a course:
  1. Claude creates 3 hazard scenario descriptions with tap-zone coordinates + quiz questions.
  2. HeyGen generates a photorealistic image for each scenario (no avatar).
     Falls back to None (drawn-mode in Flutter) if HeyGen call fails or key is absent.
"""

from __future__ import annotations

import json
import logging
import re
import time

import anthropic
import httpx

from api.config import settings

logger = logging.getLogger("arresto.gamification.hazard")


# ── Claude prompt ─────────────────────────────────────────────────────────────

_SYSTEM = (
    "You are a safety-training content designer. "
    "Your job is to create Spot-the-Hazard game scenarios that are educational, "
    "realistic, and directly related to the course topic. "
    "Return ONLY valid JSON — no markdown, no extra text."
)

_SCENARIO_SCHEMA = """{
  "scenarios": [
    {
      "title": "Short descriptive title (5-7 words)",
      "scene_description": "Detailed photorealistic scene description for image generation (2-3 sentences). Include explicit positions: 'in the bottom-left corner', 'on the right side', 'upper-center area', etc.",
      "image_prompt": "Optimised prompt for AI image generation: photorealistic, 16:9, eye-level view, industrial/workplace setting relevant to the course. List ALL visible hazards with their EXACT screen positions (bottom-left, upper-right, center, etc). No people with faces, no avatars. Safety hazards must be clearly visible.",
      "hazard_regions": [
        {
          "label": "Hazard name",
          "note": "Why this is a hazard and what to do (1-2 sentences).",
          "cx": 0.25,
          "cy": 0.75,
          "r": 0.12
        }
      ],
      "quiz_questions": [
        {
          "question": "Question text?",
          "options": ["A", "B", "C", "D"],
          "correct_index": 0,
          "explanation": "Why the answer is correct."
        }
      ]
    }
  ]
}"""


def generate_hazard_scenarios(
    course_title: str,
    course_content: str,
) -> list[dict]:
    """
    Generate 3 hazard scenarios for a course using Claude.

    Each scenario dict contains:
      title, scene_description, image_prompt, hazard_regions (list), quiz_questions (list[3])

    Coordinate conventions: cx/cy are 0..1 fractions of scene width/height.
    r is the tap-zone radius as a fraction of scene width.
    """
    if not settings.anthropic_api_key:
        raise RuntimeError("ANTHROPIC_API_KEY not set.")

    prompt = (
        f"Course title: {course_title}\n\n"
        f"Course content (excerpt):\n{course_content[:5000]}\n\n"
        f"Task: Generate exactly 3 Spot-the-Hazard game scenarios directly related to this course. "
        f"Each scenario must have:\n"
        f"- 4-6 hazards with precise cx/cy/r tap-zone coordinates (0.0-1.0 scale)\n"
        f"- 3 quiz questions per scenario (testing understanding of the hazards)\n"
        f"- A strong image_prompt for AI image generation that lists EXACT positions of each hazard\n\n"
        f"Important rules for tap-zone coordinates:\n"
        f"- cx/cy represent the CENTER of the hazard as fractions of the scene (0=left/top, 1=right/bottom)\n"
        f"- r = tap radius as fraction of scene width (use 0.10-0.14 for visible objects)\n"
        f"- Place hazards spread across the image — don't cluster them all in one area\n\n"
        f"Return ONLY this JSON structure:\n{_SCENARIO_SCHEMA}"
    )

    client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
    resp = client.messages.create(
        model=settings.llm_model,
        max_tokens=4000,
        system=_SYSTEM,
        messages=[{"role": "user", "content": prompt}],
    )

    raw = resp.content[0].text.strip()
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)

    data = json.loads(raw)
    return data.get("scenarios", [])


# ── HeyGen image generation ───────────────────────────────────────────────────

def _generate_image_heygen(prompt: str) -> str | None:
    """
    Try to generate a hazard scene image using HeyGen's image generation API.
    Returns the image URL on success, or None if the call fails or key is absent.

    HeyGen generates photorealistic scenes via their photo/image API.
    No avatar/talking-head — pure scene image.
    """
    api_key = settings.heygen_api_key
    if not api_key:
        return None

    headers = {
        "X-Api-Key": api_key,
        "Content-Type": "application/json",
    }

    # HeyGen photo generation endpoint
    try:
        with httpx.Client(timeout=60.0) as c:
            r = c.post(
                f"{settings.heygen_base_url}/v2/photo_avatar/photo/generate",
                headers=headers,
                json={
                    "prompt": prompt,
                    "resolution": "1280x720",
                    "num_images": 1,
                },
            )

        if r.status_code == 200:
            data = r.json().get("data", {})
            # Response may have url, image_url, or images list
            url = (
                data.get("url")
                or data.get("image_url")
                or (data.get("images") or [{}])[0].get("url")
            )
            if url:
                logger.info("HeyGen image generated: %s", url[:80])
                return url
            logger.warning("HeyGen 200 but no URL in response: %s", r.text[:200])
        else:
            logger.warning("HeyGen image generation failed [%d]: %s", r.status_code, r.text[:200])

    except Exception as exc:
        logger.warning("HeyGen image generation error: %s", exc)

    return None


def generate_session_with_image(scenario: dict) -> dict:
    """
    Take a Claude-generated scenario dict and add an image_url via HeyGen.
    Returns the scenario with image_url set (may be None if HeyGen unavailable).
    """
    image_prompt = scenario.get("image_prompt", scenario.get("scene_description", ""))
    image_url = _generate_image_heygen(image_prompt)
    return {**scenario, "image_url": image_url}

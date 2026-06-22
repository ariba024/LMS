"""
Test HeyGen animated (no-avatar) video generation — Work at Height course.

Usage:
    python test_heygen_wah.py
    python test_heygen_wah.py --voice female
    python test_heygen_wah.py --item 1

Generates item[0] (Welcome slide) of the WAH course as a HeyGen
voice-over video WITHOUT an avatar/talking head.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

parser = argparse.ArgumentParser(description="Test HeyGen animated video for WAH course")
parser.add_argument("--voice", default="male", choices=["male", "female"])
parser.add_argument("--item", type=int, default=0, help="Item index to render (default: 0)")
args = parser.parse_args()

SCRIPT_ID = "ed9e89ca-d6b2-43c8-95a5-a81d5b0fe78c"
LANG      = "en"
VOICE     = args.voice
ITEM_IDX  = args.item

# ── Imports (after arg parse so --help is instant) ───────────────────────────
from api.db import SessionLocal
from api.models.courses import CourseScriptRow
from modules.video import schemas
from modules.video.generators.heygen_render import (
    generate_heygen_animated_video,
    is_configured,
    remaining_credits,
)


def _load_item(idx: int) -> dict:
    with SessionLocal() as db:
        row = db.get(CourseScriptRow, SCRIPT_ID)
        if row is None:
            print(f"ERROR: Script '{SCRIPT_ID}' not found in the database.")
            sys.exit(1)
        script = json.loads(row.course_script_json)
    items = script.get("items", [])
    if idx >= len(items):
        print(f"ERROR: Item index {idx} out of range (course has {len(items)} items).")
        sys.exit(1)
    return items[idx]


def main() -> None:
    # ── Preflight ─────────────────────────────────────────────────────────────
    if not is_configured():
        print("ERROR: HEYGEN_API_KEY not set in .env")
        sys.exit(1)

    bal = remaining_credits()
    print(f"HeyGen credits remaining: {bal}")
    if bal is not None and bal < 1:
        print("WARNING: Credits may be too low. Proceeding anyway…")

    # ── Load course item ──────────────────────────────────────────────────────
    item = _load_item(ITEM_IDX)
    title    = item.get("title", f"Item {ITEM_IDX}")
    narration = item.get("narration", "")
    bullets  = item.get("bullets", [])
    takeaway = item.get("takeaway", "")
    wc       = len(narration.split())

    print()
    print("=" * 62)
    print(f"  Course : Work at Height Safety")
    print(f"  Item   : {ITEM_IDX} — {title}")
    print(f"  Words  : {wc}  (~{wc/130:.1f} min at 130 wpm)")
    print(f"  Voice  : {VOICE} | Lang: {LANG}")
    print(f"  Style  : HeyGen animated (no avatar)")
    print("=" * 62)

    # ── Build LessonContent ───────────────────────────────────────────────────
    lc = schemas.LessonContent(
        narration_script=narration,
        key_takeaways=bullets[:5],
        simplified_explanation="",
        real_world_examples=[],
        safety_scenarios=[],
        summary=takeaway or title,
    )

    lesson_id = f"wah_item{ITEM_IDX}_animated_test"
    out_path  = Path("media") / "heygen" / lesson_id / f"{LANG}.mp4"

    print(f"\nSubmitting to HeyGen… (this may take 2-5 min)")
    t0 = time.time()

    try:
        mp4 = generate_heygen_animated_video(
            lesson_id=lesson_id,
            lesson_title=title,
            lc=lc,
            style="animated_scene",
            lang=LANG,
            out_path=out_path,
            voice_preference=VOICE,
        )
        elapsed = time.time() - t0
        size_mb = mp4.stat().st_size / 1_048_576
        print(f"\nSUCCESS in {elapsed:.0f}s")
        print(f"  File : {mp4}")
        print(f"  Size : {size_mb:.1f} MB")
        print()
        print("What was generated:")
        print(f"  Course : Work at Height Safety")
        print(f"  Slide  : item[{ITEM_IDX}] — '{title}'")
        print(f"  Style  : HeyGen voice-over (no avatar), dark blue background")
        print(f"  Length : ~{wc/130:.1f} min of narration")
        print()
        print("To view in the frontend, go to:")
        print(f"  Courses → Work at Height Safety → Videos")
    except Exception as exc:
        elapsed = time.time() - t0
        print(f"\nFAILED in {elapsed:.0f}s")
        print(f"  Error: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()

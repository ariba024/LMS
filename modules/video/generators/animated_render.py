"""Record the self-playing animated HTML to a real video synced with narration.

Pipeline (all FREE):
  1. animated.py → decide how many visual scenes exist
  2. tts_router  → synthesise TTS per scene segment (one MP3 per visual scene)
  3. ffprobe     → measure each segment's actual audio duration
  4. ffmpeg      → concatenate segment audio files → single narration MP3
  5. animated.py → build HTML using *actual* per-scene TTS durations (no proportional scaling)
  6. Playwright  → record the page playing live → WebM (captures CSS animations)
  7. ffmpeg      → mux WebM + narration → final MP4

Splitting the narration into one segment per visual scene and using each
segment's real TTS duration guarantees the slide showing "Key Points" is
visible for exactly as long as the voice reads the key-points text.

The narration_script must already be in the target language. No auto-translation
is performed here so Hindi scripts go straight to Sarvam TTS as-is.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright

from modules.video import schemas
from modules.video.generators.animated import build_scenes, render_animated_html
from modules.video.generators.tts_router import synthesise, synthesise_with_timings
from modules.video.generators.video import _ffmpeg, _ffprobe


def _audio_len(path: Path) -> float:
    r = subprocess.run(
        [_ffprobe(), "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, text=True, check=True,
    )
    return float(r.stdout.strip() or "20")


def _split_narration_for_scenes(narration: str, n: int) -> list[str]:
    """Split narration text into n segments, one per visual scene.

    Tries paragraph boundaries (double newline) first so natural paragraph
    structure is preserved; falls back to equal-word-count splitting when
    there are fewer paragraphs than scenes.
    """
    if n <= 1:
        return [narration.strip() or ""]

    paras = [p.strip() for p in narration.strip().split("\n\n") if p.strip()]
    if len(paras) >= n:
        # First n-1 paragraphs map 1:1; merge any extra into the last segment
        result = list(paras[: n - 1])
        result.append("\n\n".join(paras[n - 1 :]))
        return result

    # Fewer paragraphs than scenes — split by word count into equal chunks
    words = narration.split()
    total = len(words)
    base, extra = divmod(total, n)
    result, start = [], 0
    for i in range(n):
        size = base + (1 if i < extra else 0)
        result.append(" ".join(words[start : start + size]))
        start += size
    return result


def _concat_audios(parts: list[Path], out: Path) -> None:
    """Concatenate audio files into one using ffmpeg concat demuxer (no re-encode)."""
    if len(parts) == 1:
        shutil.copy(parts[0], out)
        return
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".txt", delete=False, encoding="utf-8"
    ) as f:
        for p in parts:
            f.write(f"file '{p.resolve().as_posix()}'\n")
        list_path = f.name
    try:
        subprocess.run(
            [_ffmpeg(), "-y", "-f", "concat", "-safe", "0",
             "-i", list_path, "-c", "copy", str(out)],
            check=True, capture_output=True,
        )
    finally:
        Path(list_path).unlink(missing_ok=True)


def generate_animated_video(
    lesson_id: str,
    lesson_title: str,
    lesson_content: schemas.LessonContent,
    slides: list[schemas.SlideSpec],
    narration_script: str,
    lang: str = "en",
    style: str = "modern",
    voice: str | None = None,
) -> Path:
    """Render an animated teaching video for one lesson/slide.

    Parameters
    ----------
    lesson_id        : unique string used as the output subdirectory name
    lesson_title     : shown as the title card text
    lesson_content   : LessonContent (key_takeaways, summary, etc.)
    slides           : list of SlideSpec for scene building
    narration_script : already in the correct target language — passed directly to TTS
    lang             : BCP-47 language code ("en", "hi", "ta", …)
    style            : "modern" | "flatcolor" | "whiteboard"
    voice            : Sarvam speaker name override (e.g. "ritu", "rahul") — None uses lang default
    """
    work = Path("media") / "animated" / str(lesson_id)
    work.mkdir(parents=True, exist_ok=True)

    # 1. Decide visual scene structure first (needed to know how many segments)
    scenes = build_scenes(lesson_title, lesson_content, slides)
    n_scenes = len(scenes)

    # 2. Split narration into one segment per visual scene; synthesise each
    #    separately so we get the *actual* TTS duration for that segment.
    segments = _split_narration_for_scenes(narration_script, n_scenes)
    seg_audios: list[Path] = []
    scene_durations: list[float] = []
    for i, seg in enumerate(segments):
        seg_audio = work / f"seg_{i:02d}.mp3"
        synthesise(seg, lang, seg_audio, voice=voice)
        scene_durations.append(_audio_len(seg_audio))
        seg_audios.append(seg_audio)

    # 3. Concatenate all segment audio into the final narration MP3
    audio = work / f"{lang}.mp3"
    _concat_audios(seg_audios, audio)
    dur = sum(scene_durations)

    # 4. Build HTML with exact per-scene durations — slide N shows for precisely
    #    as long as the TTS reads the narration text assigned to scene N.
    html_doc = render_animated_html(
        lesson_title, scenes, dur, style=style, scene_durations=scene_durations
    )
    html_file = work / "scene.html"
    html_file.write_text(html_doc, encoding="utf-8")

    # 5. Record + mux
    _record_and_mux(html_file, audio, dur, work)
    return work / f"{lang}.mp4"


def generate_whiteboard_video(
    lesson_id: str,
    lesson_title: str,
    lesson_content,
    narration_script: str,
    lang: str = "en",
    voice: str | None = None,
) -> Path:
    """Free Playwright-based whiteboard video.

    Pipeline:
      1. TTS → narration MP3 + per-word timings (karaoke captions)
      2. Claude → cinematic scene plan (whiteboard_plan.py)
      3. Claude → MCQ/True-False questions (written to sidecar .quiz.json)
      4. whiteboard.py → animated 1280×720 HTML
      5. Playwright records HTML → WebM
      6. FFmpeg muxes narration → MP4
    """
    from modules.video.generators.whiteboard import render_whiteboard_html
    from modules.video.generators.whiteboard_plan import (
        generate_whiteboard_plan, generate_questions,
    )
    from modules.video.generators.llm_provider import get_llm
    import json as _json

    work = Path("media") / "whiteboard" / str(lesson_id)
    work.mkdir(parents=True, exist_ok=True)

    # 1. Narration audio + per-word timings
    audio = work / f"{lang}.mp3"
    words = synthesise_with_timings(narration_script, lang, audio, voice=voice)
    dur = _audio_len(audio)

    # 2. LLM scene plan (never raises — falls back deterministically)
    llm = get_llm()
    plan = generate_whiteboard_plan(llm, narration_script, lesson_title)

    # 3. Knowledge-check questions (failure never blocks the render)
    questions = generate_questions(llm, narration_script, len(plan.scenes))

    # 3b. Persist quiz sidecar JSON so the frontend can fetch it
    try:
        _total = sum(len(s.script_segment) for s in plan.scenes) or 1
        _cur = 0.0
        scene_ends = []
        for s in plan.scenes:
            _cur += (len(s.script_segment) / _total) * dur
            scene_ends.append(_cur)
        quiz_out = []
        for q in questions:
            si = min(q.after_scene, len(scene_ends) - 1) if scene_ends else 0
            opts = list(q.options or [])
            if q.kind == "true_false" and not opts:
                opts = ["True", "False"]
            quiz_out.append({
                "kind": q.kind,
                "timestamp": round(scene_ends[si] if scene_ends else dur, 2),
                "question": q.question,
                "options": opts,
                "correct_index": q.correct_index,
                "explanation": q.explanation,
            })
        (work / f"{lang}.quiz.json").write_text(
            _json.dumps(quiz_out, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    except Exception:
        pass

    # 4. Build animated HTML
    html_doc = render_whiteboard_html(lesson_title, plan, words, dur, questions=questions)
    html_file = work / "scene.html"
    html_file.write_text(html_doc, encoding="utf-8")

    # 5+6. Record with Playwright + mux narration → MP4
    _record_and_mux(html_file, audio, dur, work)
    return work / f"{lang}.mp4"


def _record_and_mux(html_file: Path, audio: Path, dur: float, work: Path) -> Path:
    """Record the playing HTML with Playwright, then mux narration → MP4."""
    out = work / f"{audio.stem}.mp4"
    video_tmp_dir = work / "_rec"
    video_tmp_dir.mkdir(exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=["--autoplay-policy=no-user-gesture-required"],
        )
        context = browser.new_context(
            viewport={"width": 1280, "height": 720},
            record_video_dir=str(video_tmp_dir),
            record_video_size={"width": 1280, "height": 720},
        )
        page = context.new_page()
        # wait_until='load' ensures show(0) has already fired before we start
        # counting the animation duration — the recording captures the page from
        # the very first frame, so a tiny blank pre-load period remains but is
        # offset by TTS leading silence (~100–200 ms from edge-tts / Sarvam).
        page.goto(html_file.resolve().as_uri(), wait_until="load")
        # Wait for the full animation to play through + 1 s buffer
        page.wait_for_timeout(int((dur + 1.0) * 1000))
        context.close()
        browser.close()

    webms = list(video_tmp_dir.glob("*.webm"))
    if not webms:
        raise RuntimeError("Playwright did not produce a video recording")

    subprocess.run([
        _ffmpeg(), "-y",
        "-i", str(webms[0]),
        "-i", str(audio),
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "160k",
        "-shortest",
        "-vf", "scale=1280:720,fps=30",
        str(out),
    ], check=True, capture_output=True)
    return out

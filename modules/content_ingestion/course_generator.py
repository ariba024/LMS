"""
Course script generator — transforms document content into structured
educational scripts ready for PPT / audio / video generation pipelines.

Three-step generation (all via Claude)
---------------------------------------
1. ANALYSE   — read document chunks, identify topics + key concepts
2. OUTLINE   — design module/lesson structure with hard duration constraints
3. SCRIPT    — write each lesson: narration, bullets, visuals, objectives

All user-selected settings (language, duration, difficulty, topic focus,
learning objectives, depth, tone) are injected as EXPLICIT named constraints
into every Claude prompt, not buried in a generic "additional instructions" block.
"""

from __future__ import annotations

import concurrent.futures
import json
import os
import re
import logging
import threading

logger = logging.getLogger("arresto.course_generator")

from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Callable

if TYPE_CHECKING:
    from modules.content_ingestion.embedder import Embedder
    from modules.content_ingestion.vector_store import VectorStore


# ── Output data models ─────────────────────────────────────────────────────────

@dataclass
class SlideContent:
    title:         str
    bullets:       list[str]
    speaker_notes: str = ""


@dataclass
class LessonScript:
    lesson_number:           int
    lesson_title:            str
    duration_minutes:        int
    learning_objectives:     list[str]
    narration_script:        str
    slide_content:           SlideContent
    visual_description:      str
    key_terms:               list[str]
    summary:                 str       = ""
    simplified_explanation:  str       = ""
    key_takeaways:           list[str] = field(default_factory=list)
    real_world_examples:     list[dict] = field(default_factory=list)
    safety_scenarios:        list[dict] = field(default_factory=list)
    assessment_questions:    list[dict] = field(default_factory=list)


@dataclass
class ModuleScript:
    module_number:      int
    module_title:       str
    module_description: str
    lessons:            list[LessonScript] = field(default_factory=list)


@dataclass
class CourseScript:
    course_title:                 str
    course_description:           str
    target_audience:              str
    estimated_total_duration_min: int
    source_documents:             list[str]
    modules:                      list[ModuleScript] = field(default_factory=list)
    items:                        list[dict]         = field(default_factory=list)

    def to_dict(self) -> dict:
        def lesson_d(l: LessonScript) -> dict:
            return {
                "lesson_number":          l.lesson_number,
                "lesson_title":           l.lesson_title,
                "duration_minutes":       l.duration_minutes,
                "learning_objectives":    l.learning_objectives,
                "narration_script":       l.narration_script,
                "slide_content": {
                    "title":         l.slide_content.title,
                    "bullets":       l.slide_content.bullets,
                    "speaker_notes": l.slide_content.speaker_notes,
                },
                "visual_description":     l.visual_description,
                "key_terms":              l.key_terms,
                "summary":                l.summary,
                "simplified_explanation": l.simplified_explanation,
                "key_takeaways":          l.key_takeaways,
                "real_world_examples":    l.real_world_examples,
                "safety_scenarios":       l.safety_scenarios,
                "assessment_questions":   l.assessment_questions,
            }

        def module_d(m: ModuleScript) -> dict:
            return {
                "module_number":      m.module_number,
                "module_title":       m.module_title,
                "module_description": m.module_description,
                "lessons":            [lesson_d(l) for l in m.lessons],
            }

        seen: set[str] = set()
        top_objectives: list[str] = []
        for m in self.modules:
            for l in m.lessons:
                for obj in l.learning_objectives:
                    if obj not in seen:
                        top_objectives.append(obj)
                        seen.add(obj)

        result = {
            "course_title":                 self.course_title,
            "description":                  self.course_description,
            "course_description":           self.course_description,
            "learning_objectives":          top_objectives[:6],
            "target_audience":              self.target_audience,
            "estimated_total_duration_min": self.estimated_total_duration_min,
            "source_documents":             self.source_documents,
            "modules":                      [module_d(m) for m in self.modules],
        }
        if self.items:
            result["items"] = self.items
        return result

    def save(self, path: str) -> None:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.to_dict(), f, indent=2, ensure_ascii=False)
        logger.info("Course script saved -> %s", path)


# ── Helpers ────────────────────────────────────────────────────────────────────

def _wc(text: str) -> int:
    return len(text.split())


def _diverse_sample(content: str, max_chars: int = 6000) -> str:
    """
    Sample start, middle, and end of content so the analyse step sees a
    representative cross-section of a long document rather than just the
    first N characters (which may be a table of contents or introduction).
    """
    if len(content) <= max_chars:
        return content
    third = max_chars // 3
    mid   = len(content) // 2
    return (
        content[:third]
        + "\n\n[... middle of document ...]\n\n"
        + content[mid - third // 2 : mid + third // 2]
        + "\n\n[... end of document ...]\n\n"
        + content[-third:]
    )


# ── Tool schemas for structured generation (Fix 4) ────────────────────────────
# Using Claude's tool_use with forced tool_choice eliminates all JSON parsing.
# The Anthropic API validates the schema — no markdown fences, no repair needed.

_ANALYSE_TOOL: dict = {
    "name": "analyse_document",
    "description": "Extract structured course metadata from document content",
    "input_schema": {
        "type": "object",
        "properties": {
            "suggested_title":  {"type": "string", "description": "Short course title derived from content"},
            "document_type":    {"type": "string", "description": "E.g. safety manual, technical guide, process document"},
            "main_topics":      {"type": "array",  "items": {"type": "string"}, "description": "Main topics covered"},
            "key_concepts":     {"type": "array",  "items": {"type": "string"}, "description": "Key concepts and terminology"},
            "difficulty_level": {"type": "string", "description": "beginner, intermediate, or advanced"},
            "content_summary":  {"type": "string", "description": "2-3 sentence summary of the document"},
        },
        "required": ["suggested_title", "document_type", "main_topics", "key_concepts",
                     "difficulty_level", "content_summary"],
    },
}

_OUTLINE_TOOL: dict = {
    "name": "design_course_outline",
    "description": "Design a structured course outline with modules and lessons",
    "input_schema": {
        "type": "object",
        "properties": {
            "course_title":       {"type": "string"},
            "course_description": {"type": "string", "description": "2-sentence course description"},
            "modules": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "module_number":      {"type": "integer"},
                        "module_title":       {"type": "string"},
                        "module_description": {"type": "string", "description": "One sentence"},
                        "lessons": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "lesson_number":    {"type": "integer"},
                                    "lesson_title":     {"type": "string"},
                                    "topic_focus":      {"type": "string"},
                                    "duration_minutes": {"type": "integer"},
                                },
                                "required": ["lesson_number", "lesson_title", "topic_focus", "duration_minutes"],
                            },
                        },
                    },
                    "required": ["module_number", "module_title", "module_description", "lessons"],
                },
            },
        },
        "required": ["course_title", "course_description", "modules"],
    },
}

_EXAMPLE_SCHEMA: dict = {
    "type": "object",
    "properties": {
        "situation":      {"type": "string"},
        "correct_action": {"type": "string"},
    },
    "required": ["situation", "correct_action"],
}

_MCQ_SCHEMA: dict = {
    "type": "object",
    "properties": {
        "question":    {"type": "string"},
        "options": {
            "type": "object",
            "properties": {
                "A": {"type": "string"}, "B": {"type": "string"},
                "C": {"type": "string"}, "D": {"type": "string"},
            },
            "required": ["A", "B", "C", "D"],
        },
        "correct":     {"type": "string", "enum": ["A", "B", "C", "D"]},
        "explanation": {"type": "string"},
    },
    "required": ["question", "options", "correct", "explanation"],
}

_LESSON_TOOL: dict = {
    "name": "script_lesson",
    "description": "Script a complete educational lesson with narration, slides, and assessment",
    "input_schema": {
        "type": "object",
        "properties": {
            "learning_objectives":    {"type": "array", "items": {"type": "string"}, "description": "2-3 learning objectives"},
            "narration_script":       {"type": "string", "description": "Full spoken teacher narration"},
            "slide_content": {
                "type": "object",
                "properties": {
                    "title":         {"type": "string"},
                    "bullets":       {"type": "array", "items": {"type": "string"}, "description": "3-5 concise bullet points"},
                    "speaker_notes": {"type": "string"},
                },
                "required": ["title", "bullets", "speaker_notes"],
            },
            "visual_description":     {"type": "string", "description": "What appears in the video scene"},
            "key_terms":              {"type": "array", "items": {"type": "string"}, "description": "3-5 vocabulary words"},
            "summary":                {"type": "string", "description": "1-2 sentence overview"},
            "simplified_explanation": {"type": "string", "description": "Core concept in plain language, 2-3 sentences"},
            "key_takeaways":          {"type": "array", "items": {"type": "string"}, "description": "3-4 actionable points"},
            "real_world_examples":    {"type": "array", "items": _EXAMPLE_SCHEMA, "description": "2-3 examples drawn from source content"},
            "safety_scenarios":       {"type": "array", "items": _EXAMPLE_SCHEMA, "description": "2-3 safety scenarios from source content"},
            "assessment_questions":   {"type": "array", "items": _MCQ_SCHEMA,     "description": "3 MCQs testing this lesson's key concepts"},
        },
        "required": [
            "learning_objectives", "narration_script", "slide_content",
            "visual_description", "key_terms", "summary", "simplified_explanation",
            "key_takeaways", "real_world_examples", "safety_scenarios", "assessment_questions",
        ],
    },
}


_SECTION_SUMMARY_TOOL: dict = {
    "name": "summarise_section",
    "description": "Extract topics, key concepts, and procedures from one document section",
    "input_schema": {
        "type": "object",
        "properties": {
            "topics":       {"type": "array", "items": {"type": "string"}, "description": "Main topics covered"},
            "key_concepts": {"type": "array", "items": {"type": "string"}, "description": "Key terminology and concepts"},
            "procedures":   {"type": "array", "items": {"type": "string"}, "description": "Notable procedures or safety rules"},
        },
        "required": ["topics", "key_concepts", "procedures"],
    },
}

_COHERENCE_TOOL: dict = {
    "name": "report_coherence_issues",
    "description": "Report quality issues found in a course script",
    "input_schema": {
        "type": "object",
        "properties": {
            "issues": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Quality issues found; empty list if the script is coherent",
            },
        },
        "required": ["issues"],
    },
}

_MICRO_COURSE_TOOL: dict = {
    "name": "generate_micro_course_items",
    "description": "Return a structured micro-course with slides and quizzes",
    "input_schema": {
        "type": "object",
        "properties": {
            "course_title":                {"type": "string"},
            "course_description":          {"type": "string"},
            "estimated_total_duration_min": {"type": "integer"},
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "description": "type: 'slide' | 'quiz' | 'closing_slide'",
                    "properties": {
                        "type":         {"type": "string"},
                        "slide_number": {"type": "integer"},
                        "quiz_number":  {"type": "integer"},
                        "title":        {"type": "string"},
                        "narration":    {"type": "string"},
                        "bullets":      {"type": "array", "items": {"type": "string"}},
                        "takeaway":     {"type": "string"},
                        "questions": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type":        {"type": "string"},
                                    "question":    {"type": "string"},
                                    "statement":   {"type": "string"},
                                    "front":       {"type": "string"},
                                    "back":        {"type": "string"},
                                    "options": {
                                        "type": "object",
                                        "properties": {
                                            "A": {"type": "string"}, "B": {"type": "string"},
                                            "C": {"type": "string"}, "D": {"type": "string"},
                                        },
                                    },
                                    "correct":     {"type": "string"},
                                    "answer":      {"type": "boolean"},
                                    "explanation": {"type": "string"},
                                },
                                "required": ["type"],
                            },
                        },
                    },
                    "required": ["type", "title"],
                },
            },
        },
        "required": ["course_title", "course_description", "estimated_total_duration_min", "items"],
    },
}


# ── Generator ──────────────────────────────────────────────────────────────────

class CourseGenerator:
    _MODEL = "claude-sonnet-4-6"

    def __init__(
        self,
        vector_store:        "VectorStore",
        api_key:             str | None = None,
        model:               str | None = None,
        embedder:            "Embedder | None" = None,
        enable_thinking:     bool  = False,
        thinking_budget:     int   = 8_000,
        temperature:         float = 0.0,
        reranker:            "Reranker | None" = None,
        min_retrieval_score: float = 0.55,
    ) -> None:
        self._store           = vector_store
        self._model           = model or self._MODEL
        self._embedder        = embedder
        self._enable_thinking = enable_thinking
        self._thinking_budget = thinking_budget
        self._temperature     = temperature
        self._reranker        = reranker
        self._min_score       = min_retrieval_score
        self._inline_text: str | None = None
        # Keyed by query string — avoids re-encoding the same topic_focus twice when
        # multiple lessons share a closely-named focus within one generation run.
        self._query_cache: dict[str, list[float]] = {}

        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError(
                "CourseGenerator requires an Anthropic API key. "
                "Set ANTHROPIC_API_KEY or pass api_key=."
            )
        import anthropic
        self._client = anthropic.Anthropic(api_key=key, timeout=120.0)

    # ── Duration helpers ────────────────────────────────────────────────────────

    @staticmethod
    def _duration_limits(duration_range: str) -> tuple[int, int, int, int, int]:
        """
        Returns (max_total_min, max_modules, max_lessons_per_module,
                 min_lesson_min, max_lesson_min) for the selected duration band.
        These are HARD limits — enforced programmatically after outline generation.
        """
        d = duration_range.lower()
        if "15" in d or ("20" in d and "hour" not in d):
            # 15-20 min total → 1 module, 2 lessons, 5-8 min/lesson
            return 20, 1, 2, 5, 8
        elif "30" in d or "45" in d:
            # 30-45 min total → 2 modules, 3 lessons each, 5-8 min/lesson
            return 45, 2, 3, 5, 8
        elif "2" in d and "hour" in d:
            # 2-3 hours — checked BEFORE 3+ hours (both contain "3" and "hour")
            return 180, 4, 5, 10, 15
        elif "3" in d and ("hour" in d or "+" in d):
            # 3+ hours → 5 modules, 6 lessons each, 12-18 min/lesson
            return 240, 5, 6, 12, 18
        else:
            # 60-90 min (default) → 3 modules, 4 lessons each, 7-10 min/lesson
            return 90, 3, 4, 7, 10

    @staticmethod
    def _duration_floor(duration_range: str) -> tuple[int, int, int, int]:
        """
        Returns (min_total_min, min_modules, min_lessons_per_module, target_lesson_min).
        Used by _enforce_duration to inflate under-spec outlines up to the minimum.
        """
        d = duration_range.lower()
        if "15" in d or ("20" in d and "hour" not in d):
            return 15, 1, 2, 5
        elif "30" in d or "45" in d:
            return 30, 2, 2, 5
        elif "2" in d and "hour" in d:
            return 120, 3, 4, 10
        elif "3" in d and ("hour" in d or "+" in d):
            return 180, 4, 4, 12
        else:
            return 60, 2, 3, 7

    @staticmethod
    def _duration_prompt_rules(duration_range: str) -> str:
        """Returns the duration constraints as a formatted string for Claude prompts."""
        d = duration_range.lower()
        if "15" in d or ("20" in d and "hour" not in d):
            return (
                "TOTAL DURATION: 15 to 20 minutes (MINIMUM 15 minutes — do not go below)\n"
                "  - 1 module only\n"
                "  - Exactly 2 lessons\n"
                "  - 5 to 8 minutes per lesson (duration_minutes between 5 and 8)\n"
                "  - Sum of all lesson duration_minutes MUST be at least 15"
            )
        elif "30" in d or "45" in d:
            return (
                "TOTAL DURATION: 30 to 45 minutes (MINIMUM 30 minutes — do not go below)\n"
                "  - Exactly 2 modules (no fewer)\n"
                "  - 2 to 3 lessons per module (minimum 2 per module)\n"
                "  - 5 to 8 minutes per lesson (duration_minutes between 5 and 8)\n"
                "  - Sum of all lesson duration_minutes MUST be at least 30"
            )
        elif "2" in d and "hour" in d:
            # checked BEFORE 3+ hours (both "2-3 hours" and "3+ hours" contain "3" and "hour")
            return (
                "TOTAL DURATION: 2 to 3 hours (MINIMUM 2 hours — do not go below)\n"
                "  - 3 to 4 modules (minimum 3)\n"
                "  - 4 to 5 lessons per module (minimum 4)\n"
                "  - 10 to 15 minutes per lesson (duration_minutes between 10 and 15)\n"
                "  - Sum of all lesson duration_minutes MUST be at least 120"
            )
        elif "3" in d and ("hour" in d or "+" in d):
            return (
                "TOTAL DURATION: 3 or more hours (MINIMUM 3 hours — do not go below)\n"
                "  - 4 to 5 modules (minimum 4)\n"
                "  - 4 to 6 lessons per module (minimum 4)\n"
                "  - 12 to 18 minutes per lesson (duration_minutes between 12 and 18)\n"
                "  - Sum of all lesson duration_minutes MUST be at least 180"
            )
        else:
            return (
                "TOTAL DURATION: 60 to 90 minutes (MINIMUM 60 minutes — do not go below)\n"
                "  - 2 to 3 modules (minimum 2)\n"
                "  - 3 to 4 lessons per module (minimum 3)\n"
                "  - 7 to 10 minutes per lesson (duration_minutes between 7 and 10)\n"
                "  - Sum of all lesson duration_minutes MUST be at least 60"
            )

    @staticmethod
    def _parse_structure_overrides(user_instructions: str | None) -> tuple[int | None, int | None]:
        """
        Extract explicit module / lesson counts from free-form user instructions.
        Returns (module_count, lessons_per_module) — either may be None if not found.
        Examples matched: "5 modules", "3 lessons per module", "generate 4 modules with 5 lessons"
        """
        if not user_instructions:
            return None, None
        mod_m = re.search(r'\b(\d+)\s+module', user_instructions, re.IGNORECASE)
        les_m = re.search(r'\b(\d+)\s+lesson', user_instructions, re.IGNORECASE)
        mod_count = int(mod_m.group(1)) if mod_m else None
        les_count = int(les_m.group(1)) if les_m else None
        return mod_count, les_count

    @staticmethod
    def _parse_duration_override(user_instructions: str | None) -> int | None:
        """
        Extract a total-course duration from free-form instructions.
        Returns total_minutes or None if not found.
        Matches: "20 minutes", "30 min", "1 hour", "1.5 hours"
        Ignores per-lesson qualifiers like "5 min per lesson".
        """
        if not user_instructions:
            return None
        # Strip per-lesson duration hints so they don't fool the parser
        text = re.sub(r'\d+\s*min(?:utes?)?\s*(?:per\s+lesson|/lesson)', '', user_instructions, flags=re.IGNORECASE)
        m = re.search(r'\b(\d+)\s*(?:minute|min)\b', text, re.IGNORECASE)
        if m:
            return int(m.group(1))
        m = re.search(r'\b(\d+(?:\.\d+)?)\s*hour', text, re.IGNORECASE)
        if m:
            return int(float(m.group(1)) * 60)
        return None

    def _enforce_duration(
        self,
        outline: dict,
        duration_range: str,
        user_instructions: str | None = None,
    ) -> dict:
        """
        Clamps the outline to the selected duration band (ceiling) and enforces a
        minimum floor so under-generated outlines are scaled up to spec.

        Inflating duration_minutes is meaningful: _script_lesson computes
        min_words = duration_minutes * tts_wpm, so a higher value → longer narration.
        """
        max_total, max_mods, max_les, min_les_min, max_les_min = self._duration_limits(duration_range)

        # Tighten constraints if user typed a duration in free-text instructions
        user_duration_override = False
        parsed_mins = self._parse_duration_override(user_instructions)
        if parsed_mins is not None and parsed_mins < max_total:
            logger.info(
                "User instructions specify %d min — tightening band ceiling from %d min.",
                parsed_mins, max_total,
            )
            _, tight_mods, tight_les, tight_min_les, tight_max_les = self._duration_limits(
                f"{parsed_mins} minutes"
            )
            max_total   = parsed_mins
            max_mods    = min(max_mods,   tight_mods)
            max_les     = min(max_les,    tight_les)
            min_les_min = max(min_les_min, tight_min_les)
            max_les_min = min(max_les_min, tight_max_les)
            user_duration_override = True

        # Admin-specified module/lesson counts — user intent overrides band defaults.
        user_mod_count, user_les_count = self._parse_structure_overrides(user_instructions)
        user_structure_override = user_mod_count is not None or user_les_count is not None
        if user_mod_count is not None:
            logger.info("User specified %d modules — overriding band default of %d.", user_mod_count, max_mods)
            max_mods = user_mod_count
            # Do NOT recompute max_les here — that formula (max_total // (mods × min_les))
            # collapses to 1 lesson/module when mods is large, destroying course structure.
        if user_les_count is not None:
            logger.info("User specified %d lessons/module — overriding band default of %d.", user_les_count, max_les)
            max_les = user_les_count

        # ── Ceiling clamp ─────────────────────────────────────────────────────────
        outline["modules"] = outline["modules"][:max_mods]

        for mod in outline["modules"]:
            mod["lessons"] = mod["lessons"][:max_les]
            for les in mod["lessons"]:
                raw = int(les.get("duration_minutes", max_les_min))
                les["duration_minutes"] = max(min_les_min, min(raw, max_les_min))

        total = sum(
            les["duration_minutes"]
            for mod in outline["modules"]
            for les in mod["lessons"]
        )
        # Skip total scale-down when user explicitly set structure — they intentionally
        # asked for more content than the band ceiling allows, so honour that.
        if total > max_total and not user_structure_override:
            scale = max_total / total
            for mod in outline["modules"]:
                for les in mod["lessons"]:
                    # Use a lower floor during scale-down to avoid blocking the ceiling
                    les["duration_minutes"] = max(1, int(les["duration_minutes"] * scale))

        # ── Floor enforcement ─────────────────────────────────────────────────────
        # Skip when the user explicitly requested a shorter course duration.
        if not user_duration_override:
            min_total, _min_mods, _min_les, target_les_min = self._duration_floor(duration_range)
            current_total = sum(
                les["duration_minutes"]
                for mod in outline["modules"]
                for les in mod["lessons"]
            )
            total_lessons = sum(len(mod["lessons"]) for mod in outline["modules"])

            if current_total < min_total and total_lessons > 0:
                # Inflate duration_minutes so _script_lesson generates longer narration.
                # Allow up to 15 min per lesson when the lesson count is too low to
                # reach min_total within the band's per-lesson ceiling.
                per_lesson_cap = max(max_les_min, 15)
                target_per_lesson = min(
                    per_lesson_cap,
                    max(target_les_min, -(-min_total // total_lessons)),  # ceiling division
                )
                for mod in outline["modules"]:
                    for les in mod["lessons"]:
                        les["duration_minutes"] = max(les["duration_minutes"], target_per_lesson)
                new_total = sum(
                    les["duration_minutes"]
                    for mod in outline["modules"]
                    for les in mod["lessons"]
                )
                logger.warning(
                    "Floor enforcement: outline was only %d min (%d lessons) for band '%s'. "
                    "Inflated to %d min/lesson → %d min total.",
                    current_total, total_lessons, duration_range, target_per_lesson, new_total,
                )

        final_total = sum(les["duration_minutes"] for mod in outline["modules"] for les in mod["lessons"])
        final_lessons = sum(len(mod["lessons"]) for mod in outline["modules"])
        logger.info(
            "Duration enforced for '%s': %d modules, %d lessons, %d min total",
            duration_range, len(outline["modules"]), final_lessons, final_total,
        )
        return outline

    # ── Instructions parser ─────────────────────────────────────────────────────

    @staticmethod
    def _parse_instructions(instructions: str | None) -> dict:
        """
        Extracts structured fields from the instructions string built by the
        Flutter wizard. The wizard concatenates fields as:
          'Topic focus: X. Course description: Y. Difficulty level: Z.
           Learning objectives: W. Depth: V. Tone: U.'

        Returns a dict with keys: topic, description, difficulty,
        objectives, depth, tone. Any field absent in the string is omitted.
        """
        if not instructions:
            return {}

        result: dict[str, str] = {}

        # Use lookahead for known field labels as stop markers so a multi-sentence
        # description (or one that ends with a period) doesn't bleed into the next field.
        _NEXT = r"(?=\s*(?:Topic focus:|Course description:|Difficulty level:|Learning objectives:|Depth:|Tone:)|$)"

        patterns = {
            "topic":       rf"Topic focus:\s*(.*?){_NEXT}",
            "description": rf"Course description:\s*(.*?){_NEXT}",
            "difficulty":  r"Difficulty level:\s*(\w[\w\s]*?)(?=[.\s]*(?:Learning objectives:|Depth:|Tone:|Topic focus:|Course description:|$))",
            "objectives":  rf"Learning objectives:\s*(.*?){_NEXT}",
            "depth":       r"Depth:\s*(\w[\w\s]*?)(?:\.|$)",
            "tone":        r"Tone:\s*(\w[\w\s]*?)(?:\.|$)",
        }

        for key, pattern in patterns.items():
            m = re.search(pattern, instructions, re.IGNORECASE | re.DOTALL)
            if m:
                val = m.group(1).strip().rstrip(".")
                if val:
                    result[key] = val

        return result

    # ── Sanitization ────────────────────────────────────────────────────────────

    _CTRL_CHAR_RE     = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
    _MAX_INSTRUCTIONS = 5_000

    @classmethod
    def _sanitize_instructions(cls, text: str | None) -> str | None:
        if not text:
            return text
        text = cls._CTRL_CHAR_RE.sub("", text)
        if len(text) > cls._MAX_INSTRUCTIONS:
            logger.warning("instructions truncated from %d to %d chars.", len(text), cls._MAX_INSTRUCTIONS)
            text = text[: cls._MAX_INSTRUCTIONS]
        return text.strip() or None

    # ── Claude call helpers ─────────────────────────────────────────────────────

    _MAX_INPUT_CHARS = 600_000

    def _call(self, prompt: str, system: str = "", max_tokens: int = 4096) -> str:
        system_text = system or (
            "You are an expert instructional designer who transforms raw "
            "document content into engaging, clear educational material. "
            "You always return valid JSON when asked. "
            "You follow all constraints EXACTLY — language, duration, difficulty, tone."
        )
        total_chars = len(prompt) + len(system_text)
        if total_chars > self._MAX_INPUT_CHARS:
            raise ValueError(
                f"Prompt too large: {total_chars:,} chars. Reduce source document size."
            )
        call_kw: dict = dict(
            model=self._model,
            max_tokens=max_tokens,
            system=system_text,
            messages=[{"role": "user", "content": prompt}],
        )
        if self._temperature != 0.0:
            call_kw["temperature"] = self._temperature
        resp = self._client.messages.create(**call_kw)
        return resp.content[0].text

    def _parse_json(self, text: str) -> dict:
        """
        Extract and parse JSON from a response that may have markdown fences.
        Falls back to json-repair for common Claude quirks (trailing commas,
        truncated responses, unescaped newlines in strings).
        """
        text = text.strip()

        # 1. Direct parse (fastest path — no fences, clean JSON)
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass

        # 2. Strip markdown fences then try again
        candidate = text
        if "```" in text:
            for fence in ("```json", "```"):
                if fence in text:
                    after = text[text.index(fence) + len(fence):]
                    end_fence = after.find("```")
                    candidate = after[:end_fence].strip() if end_fence != -1 else after.strip()
                    try:
                        return json.loads(candidate)
                    except json.JSONDecodeError:
                        break  # try repair on this candidate below

        # 3. Isolate the outermost {...} block
        start = candidate.find("{")
        end   = candidate.rfind("}") + 1
        if start != -1 and end > start:
            candidate = candidate[start:end]

        # 4. json-repair — handles trailing commas, truncated JSON, bad escapes
        try:
            from json_repair import repair_json
            repaired = repair_json(candidate, return_objects=True)
            if isinstance(repaired, dict):
                return repaired
        except Exception:
            pass

        # 5. Last resort: strict parse with descriptive error
        try:
            return json.loads(candidate)
        except json.JSONDecodeError as exc:
            raise ValueError(
                f"Could not parse JSON from model response. "
                f"Error: {exc}. Response (first 300 chars): {text[:300]!r}"
            ) from exc

    def _call_structured(
        self,
        prompt:           str,
        tool:             dict,
        system:           str        = "",
        max_tokens:       int        = 4096,
        use_thinking:     bool       = False,
        cacheable_prefix: str | None = None,
    ) -> dict:
        """
        Call Claude with forced tool_use and return the validated input dict directly.

        The Anthropic API enforces the JSON schema — no parsing or repair needed.

        Caching (Fix 9): the system prompt is always sent as a cached block.
        If cacheable_prefix is given it becomes a second cached block before the
        main prompt — use for document content that is stable across many calls
        (e.g. the retrieved source chunks for each lesson in a generation run).

        Extended thinking (Fix 8): when use_thinking=True the model reasons before
        filling in the tool. Thinking blocks in the response are silently skipped;
        only the tool_use block is returned. max_tokens is auto-raised to accommodate
        the thinking budget.
        """
        system_text = system or (
            "You are an expert instructional designer who transforms raw "
            "document content into engaging, clear educational material. "
            "You follow all constraints EXACTLY — language, duration, difficulty, tone."
        )
        total_chars = len(prompt) + len(system_text) + len(cacheable_prefix or "")
        if total_chars > self._MAX_INPUT_CHARS:
            raise ValueError(
                f"Prompt too large: {total_chars:,} chars. Reduce source document size."
            )

        # System prompt cached — identical across all calls in this session
        system_block = [
            {"type": "text", "text": system_text, "cache_control": {"type": "ephemeral"}},
        ]

        # User message: optional cached document prefix + instruction prompt
        if cacheable_prefix:
            user_content: list | str = [
                {"type": "text", "text": cacheable_prefix, "cache_control": {"type": "ephemeral"}},
                {"type": "text", "text": prompt},
            ]
        else:
            user_content = prompt

        call_kwargs: dict = {
            "model":       self._model,
            "max_tokens":  max_tokens,
            "system":      system_block,
            "tools":       [tool],
            "tool_choice": {"type": "tool", "name": tool["name"]},
            "messages":    [{"role": "user", "content": user_content}],
        }
        if use_thinking:
            # thinking budget must be < max_tokens; pad with headroom for output
            call_kwargs["thinking"]   = {"type": "enabled", "budget_tokens": self._thinking_budget}
            call_kwargs["max_tokens"] = max(max_tokens, self._thinking_budget + 2_048)
            # extended thinking requires temperature=1; don't override it
        elif self._temperature != 0.0:
            call_kwargs["temperature"] = self._temperature  # 8B

        resp = self._client.messages.create(**call_kwargs)
        for block in resp.content:
            if block.type == "tool_use" and block.name == tool["name"]:
                return block.input
        # Guard: forced tool_choice should never reach here
        logger.warning(
            "Structured call '%s' returned no tool_use block — falling back to text parse",
            tool["name"],
        )
        text = next((b.text for b in resp.content if hasattr(b, "text")), "")
        return self._parse_json(text)

    # ── Relevant chunk retrieval ────────────────────────────────────────────────

    def _get_lesson_context(
        self,
        topic_focus:        str,
        source_file:        str,
        fallback_content:   str,
        n_chunks:           int   = 8,
        use_knowledge_base: bool  = False,
        language:           str   = "English",
    ) -> str:
        if self._inline_text is not None:
            return self._inline_text[:5000]
        if self._embedder is None:
            return fallback_content[:5000]
        if topic_focus in self._query_cache:
            q_vec = self._query_cache[topic_focus]
        else:
            q_vec = self._embedder.embed_query(topic_focus)
            self._query_cache[topic_focus] = q_vec
        filter_file = None if use_knowledge_base else source_file

        # First pass: MMR retrieval with quality floor — diverse, relevant chunks.
        hits = self._store.mmr_query(
            q_vec, n_results=n_chunks, fetch_k=n_chunks * 3,
            source_file=filter_file, min_score=self._min_score,
        )

        # Fallback: if fewer than 3 chunks cleared the threshold (topic is sparsely
        # covered in the document), relax the filter and use top-n MMR unfiltered.
        if len(hits) < 3:
            raw_hits = self._store.mmr_query(
                q_vec, n_results=n_chunks, fetch_k=n_chunks * 3,
                source_file=filter_file,
            )
            if raw_hits:
                logger.debug(
                    "Only %d chunk(s) scored >= %.2f for '%s' — using top-%d unfiltered",
                    len(hits), self._min_score, topic_focus, len(raw_hits),
                )
                hits = raw_hits

        if not hits:
            return fallback_content[:5000]

        # 4B: cross-encoder rerank when available — improves precision after MMR diversity pass.
        # A3: ms-marco reranker is English-trained; skip for Indian and other non-European languages
        # where the cross-encoder produces meaningless scores and would scramble chunk order.
        _european = {
            "english", "en", "french", "german", "spanish", "italian",
            "portuguese", "dutch", "polish", "romanian", "czech",
        }
        if self._reranker is not None and language.lower() in _european:
            hits = self._reranker.rerank(topic_focus, hits, top_k=n_chunks)

        return "\n\n".join(
            f"[{h['metadata'].get('section_heading', '')}]\n{h['text']}"
            for h in hits
        )

    # ── Two-pass document analysis (Fix 5) ──────────────────────────────────────

    def _summarise_section(
        self, text: str, idx: int, total: int, language: str
    ) -> dict:
        """
        Quick topic/concept extraction from one document section.
        Used by _build_analysis_context to map a large document before full analysis.
        """
        prompt = (
            f"Document section {idx} of {total}. "
            f"Extract the main topics, key concepts, and notable procedures or safety rules. "
            f"All text fields must be in {language}.\n\n"
            f"TEXT:\n{text}"
        )
        try:
            return self._call_structured(prompt, _SECTION_SUMMARY_TOOL, max_tokens=512)
        except Exception as exc:
            logger.warning("Section %d/%d summary failed (skipped): %s", idx, total, exc)
            return {"topics": [], "key_concepts": [], "procedures": []}

    def _build_analysis_context(self, content: str, language: str) -> str:
        """
        Return the document text that the analyse step will see.

        Strategy by document size:
          < 8 k chars  — full content (small doc, nothing to lose)
          8k–30k chars — diverse 8k sample (start + middle + end)
          > 30k chars  — progressive section summarisation:
                          split into ≤5 sections of ~5k chars, summarise each
                          in parallel, merge all topics/concepts/procedures,
                          and prepend the merged overview to the document opening.
                          This gives the analyse step a view of the whole document
                          rather than the first 7.5 % of it.
        """
        SMALL   =  8_000
        LARGE   = 30_000
        SEC_SZ  =  5_000
        MAX_SEC = 5

        if len(content) <= SMALL:
            return content

        if len(content) <= LARGE:
            return _diverse_sample(content, 8_000)

        # Large document: map each section, then merge
        step     = max(SEC_SZ, len(content) // MAX_SEC)
        sections = [content[i : i + SEC_SZ] for i in range(0, len(content), step)][:MAX_SEC]
        total    = len(sections)
        logger.info(
            "Large document (%d chars): summarising %d sections for analysis ...",
            len(content), total,
        )

        with concurrent.futures.ThreadPoolExecutor(max_workers=min(4, total)) as pool:
            futs      = [pool.submit(self._summarise_section, s, i + 1, total, language)
                         for i, s in enumerate(sections)]
            summaries = [f.result() for f in futs]

        # Deduplicate while preserving first-seen order
        all_topics     = list(dict.fromkeys(t for s in summaries for t in s.get("topics",      [])))[:25]
        all_concepts   = list(dict.fromkeys(c for s in summaries for c in s.get("key_concepts", [])))[:25]
        all_procedures = list(dict.fromkeys(p for s in summaries for p in s.get("procedures",   [])))[:15]

        return (
            f"DOCUMENT OVERVIEW (synthesised from {total} sections, "
            f"{len(content):,} total characters):\n\n"
            f"Topics: {', '.join(all_topics) or 'none identified'}\n"
            f"Key concepts: {', '.join(all_concepts) or 'none identified'}\n"
            f"Procedures / rules: {', '.join(all_procedures) or 'none identified'}\n\n"
            "--- DOCUMENT OPENING (first 2,000 chars) ---\n"
            + content[:2_000]
        )

    # ── Narration word-count top-up ─────────────────────────────────────────────

    def _extend_narration(
        self,
        lesson_title: str,
        current: str,
        min_words: int,
        language: str,
    ) -> str:
        """Extend a narration that fell below the word-count floor."""
        current_wc = _wc(current)
        needed = min_words - current_wc
        logger.info(
            "  Narration too short (%d words, need %d) — extending by ~%d words ...",
            current_wc, min_words, needed,
        )
        prompt = (
            f'The narration for "{lesson_title}" is {current_wc} words '
            f"but requires at least {min_words}.\n"
            f"You must add approximately {needed} more words.\n\n"
            f"EXISTING NARRATION:\n{current}\n\n"
            f"Continue from where it left off — write in {language}, "
            f"teacher-voice, first-person plural. "
            f"Add deeper explanations, transitions, relatable examples, and a recap. "
            f"Output ONLY the extension text (do NOT repeat the existing narration)."
        )
        extension = self._call(prompt, max_tokens=8000)
        return current.rstrip() + "\n\n" + extension.strip()

    # ── Language heuristic check ─────────────────────────────────────────────────

    @staticmethod
    def _tts_wpm(language: str) -> int:
        """
        Estimated words-per-minute for the TTS engine used for `language`.

        Indian language scripts (Devanagari, Dravidian) have longer phonetics
        per word — Sarvam Bulbul-v3 produces ~100 wpm for those.
        English and European edge-tts voices run at ~165 wpm.
        """
        indian = {
            "hindi", "tamil", "telugu", "bengali", "gujarati",
            "kannada", "malayalam", "marathi", "punjabi", "odia",
        }
        return 100 if language.lower() in indian else 165

    @staticmethod
    def _check_language(text: str, language: str) -> bool:
        """
        For non-English targets: flag if >30 % of words are purely ASCII
        (a reliable signal of language slippage in multilingual generation).
        Returns True when the text looks correct, False when suspect.
        """
        if language.lower() in ("english", "en"):
            return True
        words = text.split()
        if not words:
            return True
        ascii_count = sum(1 for w in words if all(ord(c) < 128 for c in w))
        return (ascii_count / len(words)) < 0.30

    # ── Topic coverage check ─────────────────────────────────────────────────────

    def _topic_coverage_check(self, main_topics: list[str], outline: dict) -> None:
        """
        Compare main_topics from the analyse step against lesson topic_focus fields.
        Logs a warning for any topic not represented in any lesson.
        Pure Python — no Claude call.
        """
        lesson_corpus = " ".join(
            (les.get("topic_focus", "") + " " + les.get("lesson_title", "")).lower()
            for mod in outline.get("modules", [])
            for les in mod.get("lessons", [])
        )
        dropped = [
            t for t in main_topics
            if not re.search(r'\b' + re.escape(t.lower()) + r'\b', lesson_corpus)
        ]
        if dropped:
            logger.warning(
                "Topic coverage gap — %d topic(s) from analysis have no lesson: %s",
                len(dropped), dropped,
            )
        else:
            logger.info(
                "Topic coverage OK — all %d main topics are represented.", len(main_topics)
            )

    # ── Coherence review ─────────────────────────────────────────────────────────

    @staticmethod
    def _jaccard(a: str, b: str) -> float:
        """Word-level Jaccard similarity between two strings."""
        sa = set(a.lower().split())
        sb = set(b.lower().split())
        if not sa or not sb:
            return 0.0
        return len(sa & sb) / len(sa | sb)

    def _flag_duplicate_questions(self, modules: list) -> None:
        """
        After all lessons are scripted, scan every assessment question across every
        lesson for near-duplicates (Jaccard word overlap > 60 %).
        Duplicates are logged as warnings — generation is never blocked.
        """
        records: list[tuple[str, str, str]] = []  # (module_title, lesson_title, question_text)
        for mod in modules:
            for les in mod.lessons:
                for q in (les.assessment_questions or []):
                    text = q if isinstance(q, str) else q.get("question", "")
                    if text:
                        records.append((mod.module_title, les.lesson_title, text))

        duplicates_found = 0
        for i in range(len(records)):
            for j in range(i + 1, len(records)):
                sim = self._jaccard(records[i][2], records[j][2])
                if sim > 0.60:
                    duplicates_found += 1
                    logger.warning(
                        "Duplicate question detected (Jaccard=%.2f):\n"
                        "  [%s > %s] %s\n"
                        "  [%s > %s] %s",
                        sim,
                        records[i][0], records[i][1], records[i][2],
                        records[j][0], records[j][1], records[j][2],
                    )
        if duplicates_found == 0:
            logger.info("Duplicate question check passed — no overlapping questions found.")

    def _coherence_review(self, modules: list, language: str) -> list[str]:
        """
        Lightweight post-generation review: asks Claude to spot duplicate key terms,
        contradictory objectives, or missing progressions across the full script.
        Returns a list of issue strings; empty list means all good.
        Non-blocking — exceptions are caught and logged.
        """
        def _narration_bookends(narration: str) -> str:
            paras = [p.strip() for p in narration.split("\n\n") if p.strip()]
            if not paras:
                return ""
            first = paras[0]
            last  = paras[-1] if len(paras) > 1 else ""
            parts = [f"Opening: {first}"]
            if last:
                parts.append(f"Closing: {last}")
            return "\n".join(parts)

        entries = []
        for mod in modules:
            for les in mod.lessons:
                bookends = _narration_bookends(les.narration_script or "")
                entry = (
                    f"Lesson: {les.lesson_title}\n"
                    f"Objectives: {les.learning_objectives}\n"
                    f"Key terms: {les.key_terms}\n"
                    f"Summary: {les.summary}"
                )
                if bookends:
                    entry += f"\n{bookends}"
                entries.append(entry)
        if not entries:
            return []
        prompt = (
            "Review the following course script outline for quality issues.\n\n"
            + "\n\n---\n\n".join(entries)
            + "\n\nLook for: duplicate key terms across lessons, contradictory objectives, "
            "lessons that don't logically progress, objectives that don't match the lesson title. "
            "Return an empty list if the script looks coherent."
        )
        try:
            data   = self._call_structured(prompt, _COHERENCE_TOOL, max_tokens=1024)
            issues = data.get("issues", [])
            if issues:
                logger.warning(
                    "Coherence review found %d issue(s): %s", len(issues), issues
                )
            else:
                logger.info("Coherence review passed — no issues found.")
            return issues
        except Exception as exc:
            logger.warning("Coherence review failed (non-blocking): %s", exc)
            return []

    # ── Public API ──────────────────────────────────────────────────────────────

    @staticmethod
    def _user_req_block(user_instructions: str | None) -> str:
        """Format admin's free-form instructions as a strict constraint block."""
        if not user_instructions or not user_instructions.strip():
            return ""
        return (
            "\nCRITICAL USER REQUIREMENTS — FOLLOW EXACTLY:\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"{user_instructions.strip()}\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "These are NON-NEGOTIABLE requirements from the course designer.\n"
            "They override all defaults above. Implement them literally.\n"
        )

    def generate(
        self,
        source_file:        str,
        course_title:       str | None = None,
        target_audience:    str = "learners",
        progress_callback:  "Callable[[int, int], None] | None" = None,
        instructions:       str | None = None,
        user_instructions:  str | None = None,
        use_knowledge_base: bool = False,
        language:           str = "English",
        duration_range:     str = "60-90 minutes",
    ) -> CourseScript:
        """
        Generate a complete course from a document in the vector store.

        Parameters
        ----------
        source_file      : filename as stored (e.g. "Safety Manual.pdf")
        course_title     : override title; Claude auto-generates if None
        target_audience  : who the course is for
        instructions     : composite string from the Flutter wizard containing
                           topic focus, description, difficulty level, learning
                           objectives, depth, and tone
        use_knowledge_base: search across all docs (not just source_file)
        language         : ALL content output language (e.g. "Hindi", "Spanish")
        duration_range   : "30-45 minutes" | "60-90 minutes" | "2-3 hours" | "3+ hours"
        """
        instructions = self._sanitize_instructions(instructions)
        parsed = self._parse_instructions(instructions)

        logger.info(
            "generate() called: source='%s', language='%s', duration='%s', "
            "difficulty='%s', topic='%s'",
            source_file, language, duration_range,
            parsed.get("difficulty", "not set"), parsed.get("topic", "not set"),
        )

        chunks = self._store.get_all_by_source(source_file)
        if not chunks:
            raise ValueError(
                f"No chunks found for '{source_file}'. "
                "Run the ingestion pipeline on this file first."
            )

        full_content = "\n\n".join(
            f"[{c['metadata'].get('section_heading', '')}]\n{c['text']}"
            for c in chunks
        )
        logger.info("%d chunks loaded (%d chars).", len(chunks), len(full_content))

        user_req = self._user_req_block(user_instructions)

        # Step 1 — analyse
        logger.info("Step 1/3: Analysing content ...")
        analysis = self._analyse(full_content, source_file, target_audience, parsed, language, user_req)

        # 7A — enrich analysis with per-topic paragraph coverage so _outline can
        # weight lesson durations toward topics with more source material.
        # Skip when language != English: _analyse returns topic names in the
        # target language (e.g. Hindi) but full_content is the English source
        # text, so keyword matching would always score 0 and add no information.
        main_topics = analysis.get("main_topics", [])
        if main_topics and language.lower() in ("english", "en"):
            analysis["topic_chunk_coverage"] = self._estimate_topic_coverage(
                main_topics, full_content
            )

        # Step 2 — outline (with duration constraints baked into the prompt)
        logger.info("Step 2/3: Building course outline ...")
        # 1E: prefer the PDF/DOCX document title over source filename when available
        stored_doc_title = chunks[0]["metadata"].get("doc_title", "") if chunks else ""
        title = course_title or stored_doc_title or analysis.get("suggested_title", source_file)
        outline = self._outline(analysis, title, target_audience, parsed, language, duration_range, user_req, user_instructions)

        # Clamp outline — user_instructions can override module/lesson counts
        outline = self._enforce_duration(outline, duration_range, user_instructions)

        # Warn if any main topic from analysis is absent from the outline
        self._topic_coverage_check(analysis.get("main_topics", []), outline)

        total_lessons = sum(len(m["lessons"]) for m in outline["modules"])
        logger.info("Step 3/3: Scripting %d lessons ...", total_lessons)

        # Step 3 — script each lesson (modules parallelised, lessons sequential within module)
        modules = self._script_all(
            outline, full_content, target_audience, source_file,
            progress_callback, parsed, use_knowledge_base, language, user_req,
        )

        # Post-generation checks (non-blocking — log only, never fail generation)
        self._flag_duplicate_questions(modules)
        self._coherence_review(modules, language)

        total_mins = sum(l.duration_minutes for m in modules for l in m.lessons)
        return CourseScript(
            course_title=outline["course_title"],
            course_description=outline["course_description"],
            target_audience=target_audience,
            estimated_total_duration_min=total_mins,
            source_documents=[source_file],
            modules=modules,
        )

    @staticmethod
    def _fk_grade_level(text: str) -> float:
        """
        9C — Compute Flesch-Kincaid Grade Level for a narration script.
        FKGL = 0.39 × (words/sentences) + 11.8 × (syllables/words) - 15.59
        Syllable count uses a vowel-group heuristic with silent-e adjustment.
        Returns 0.0 if the text has no sentences.
        """
        words = text.split()
        if not words:
            return 0.0
        # Sentence count: split on .  !  ?
        sentence_ends = re.findall(r'[.!?]+', text)
        n_sentences = max(1, len(sentence_ends))
        # Syllable count
        total_syllables = 0
        for w in words:
            w = re.sub(r'[^a-zA-Z]', '', w).lower()
            if not w:
                continue
            vowel_groups = len(re.findall(r'[aeiou]+', w))
            if w.endswith('e') and vowel_groups > 1:
                vowel_groups -= 1
            total_syllables += max(1, vowel_groups)
        asl = len(words) / n_sentences
        asw = total_syllables / len(words)
        return round(0.39 * asl + 11.8 * asw - 15.59, 1)

    @staticmethod
    def _estimate_topic_coverage(topics: list[str], content: str) -> dict[str, int]:
        """
        Count how many paragraphs in `content` mention keywords from each topic.
        Used as a zero-cost proxy for how much source material backs each topic
        so `_outline()` can weight lesson durations proportionally (7A).
        """
        paras = [p.strip().lower() for p in content.split("\n\n") if p.strip()]
        coverage: dict[str, int] = {}
        for topic in topics:
            keywords = [w for w in topic.lower().split() if len(w) > 3]
            if not keywords:
                coverage[topic] = 0
                continue
            coverage[topic] = sum(
                1 for p in paras if any(kw in p for kw in keywords)
            )
        return coverage

    # ── Step 1: Analyse ─────────────────────────────────────────────────────────

    def _analyse(
        self,
        content:    str,
        source_file: str,
        audience:   str,
        parsed:     dict,
        language:   str,
        user_req:   str = "",
    ) -> dict:
        topic_line       = f"TOPIC FOCUS: {parsed['topic']}" if parsed.get("topic") else ""
        description_line = f"COURSE DESCRIPTION: {parsed['description']}" if parsed.get("description") else ""
        difficulty_line  = f"DIFFICULTY LEVEL: {parsed['difficulty']}" if parsed.get("difficulty") else ""

        prompt = f"""Analyse the following document content extracted from "{source_file}".

═══ FIXED CONSTRAINTS ═══════════════════════════════════════════
OUTPUT LANGUAGE: {language}
  → Write ALL fields (titles, summaries, topics, concepts) in {language}.
TARGET AUDIENCE: {audience}
{topic_line}
{description_line}
{difficulty_line}
{user_req}═════════════════════════════════════════════════════════════════

DOCUMENT CONTENT:
{self._build_analysis_context(content, language)}

Fill in the analyse_document tool — ALL text in {language}.
"""
        return self._call_structured(
            prompt, _ANALYSE_TOOL, max_tokens=1024,
            use_thinking=self._enable_thinking,
        )

    # ── Step 2: Outline ─────────────────────────────────────────────────────────

    def _outline(
        self,
        analysis:       dict,
        course_title:   str,
        audience:       str,
        parsed:            dict,
        language:          str  = "English",
        duration_range:    str  = "60-90 minutes",
        user_req:          str  = "",
        user_instructions: str | None = None,
    ) -> dict:
        _, _, max_les_band, min_les_min, max_les_min = self._duration_limits(duration_range)
        example_dur = (min_les_min + max_les_min) // 2

        # When user specifies module/lesson counts, build a single unified description
        # so the prompt never contains two contradictory module-count statements.
        user_mod_count, user_les_count = self._parse_structure_overrides(user_instructions)
        if user_mod_count is not None or user_les_count is not None:
            n_mods = user_mod_count if user_mod_count is not None else 2
            n_les  = user_les_count if user_les_count is not None else max_les_band
            duration_rules = (
                f"STRUCTURE (admin-specified — follow exactly, do not alter counts):\n"
                f"  - Exactly {n_mods} modules\n"
                f"  - Exactly {n_les} lessons per module\n"
                f"  - {min_les_min} to {max_les_min} minutes per lesson "
                f"(duration_minutes between {min_les_min} and {max_les_min})"
            )
        else:
            duration_rules = self._duration_prompt_rules(duration_range)

        objectives_line = f"LEARNING OBJECTIVES TO COVER: {parsed['objectives']}" if parsed.get("objectives") else ""
        difficulty_line = f"DIFFICULTY LEVEL: {parsed.get('difficulty', analysis.get('difficulty_level', 'intermediate'))}"
        depth_line      = f"DEPTH: {parsed['depth']}" if parsed.get("depth") else ""
        tone_line       = f"TONE: {parsed['tone']}" if parsed.get("tone") else ""

        prompt = f"""Design a structured course outline based on the content analysis below.

═══ FIXED CONSTRAINTS — FOLLOW EXACTLY ═════════════════════════
OUTPUT LANGUAGE: {language}
  → Write ALL text fields (titles, descriptions) in {language}.

{duration_rules}
  → These are HARD limits. Do NOT exceed them.
  → The sum of all duration_minutes MUST NOT exceed the total duration above.

{difficulty_line}
{objectives_line}
{depth_line}
{tone_line}
{user_req}═════════════════════════════════════════════════════════════════

CONTENT ANALYSIS:
{json.dumps(analysis, indent=2, ensure_ascii=False)}

COURSE TITLE: {course_title}
TARGET AUDIENCE: {audience}

Design the outline. Progress logically: fundamentals → application → advanced.
Each lesson must build on the previous — no repeated content.

If topic_chunk_coverage is present in the analysis above, use it to weight
lesson durations: topics with higher paragraph coverage have more source material
and typically deserve proportionally more lesson time; topics with very low
coverage should be shorter lessons or folded into adjacent lessons.

Fill in the design_course_outline tool — ALL titles and descriptions in {language}.
"""
        return self._call_structured(
            prompt, _OUTLINE_TOOL,
            use_thinking=self._enable_thinking,
        )

    # ── Step 3: Script each lesson ──────────────────────────────────────────────

    def _script_all(
        self,
        outline:            dict,
        content:            str,
        audience:           str,
        source_file:        str,
        progress_callback:  "Callable[[int, int], None] | None" = None,
        parsed:             dict | None = None,
        use_knowledge_base: bool = False,
        language:           str = "English",
        user_req:           str = "",
    ) -> list[ModuleScript]:
        parsed = parsed or {}
        total        = sum(len(m["lessons"]) for m in outline["modules"])
        lock         = threading.Lock()
        done_counter = [0]

        def _process_module(mod: dict) -> ModuleScript:
            lessons_out: list[LessonScript] = []
            prev_summary: str | None = None
            total_in_module = len(mod["lessons"])

            for lesson_idx, les in enumerate(mod["lessons"]):
                min_words = les["duration_minutes"] * self._tts_wpm(language)
                last_exc: Exception | None = None

                for attempt in range(2):
                    try:
                        ls = self._script_lesson(
                            les, mod, content, audience, source_file,
                            parsed, use_knowledge_base, language, user_req,
                            previous_lesson_summary=prev_summary,
                            lesson_index=lesson_idx,
                            total_lessons=total_in_module,
                        )
                        last_exc = None
                        break
                    except Exception as exc:
                        last_exc = exc
                        logger.warning(
                            "  [retry %d/2] lesson '%s' failed: %s",
                            attempt + 1, les["lesson_title"], exc,
                        )
                if last_exc is not None:
                    raise last_exc

                # Word-count floor: extend narration if it fell short
                if _wc(ls.narration_script) < min_words:
                    ls.narration_script = self._extend_narration(
                        ls.lesson_title, ls.narration_script, min_words, language,
                    )

                # Language heuristic: warn if >30 % ASCII words in a non-English lesson
                if not self._check_language(ls.narration_script, language):
                    logger.warning(
                        "  Language suspect in '%s' (expected %s, >30%% ASCII words detected)",
                        ls.lesson_title, language,
                    )

                # 9C: Flesch-Kincaid readability — flag lessons outside expected grade band.
                # Safety/corporate training targets grade 8-12 for adult learners.
                if language.lower() in ("english", "en"):
                    fk = self._fk_grade_level(ls.narration_script)
                    if fk > 14:
                        logger.warning(
                            "  Readability high in '%s': FKGL=%.1f (target ≤ 12). "
                            "Consider simpler sentence structure.",
                            ls.lesson_title, fk,
                        )
                    elif fk < 6:
                        logger.warning(
                            "  Readability low in '%s': FKGL=%.1f (target ≥ 8). "
                            "May be too simple for adult learners.",
                            ls.lesson_title, fk,
                        )
                    else:
                        logger.debug("  Readability '%s': FKGL=%.1f ✓", ls.lesson_title, fk)

                # Pass this lesson's summary to the next lesson for continuity
                prev_summary = ls.summary or ls.lesson_title

                lessons_out.append(ls)
                with lock:
                    done_counter[0] += 1
                    current = done_counter[0]
                    if progress_callback:
                        progress_callback(current, total)
                logger.info(
                    "  [ok] (%d/%d) %s > %s",
                    done_counter[0], total, mod["module_title"], les["lesson_title"],
                )

            return ModuleScript(
                module_number=mod["module_number"],
                module_title=mod["module_title"],
                module_description=mod["module_description"],
                lessons=lessons_out,
            )

        modules = outline["modules"]
        # Modules are independent — run them in parallel.
        # Lessons within each module stay sequential to preserve prev_summary continuity.
        max_workers = min(4, len(modules))
        if max_workers <= 1:
            return [_process_module(m) for m in modules]

        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as pool:
            futures = {pool.submit(_process_module, m): m["module_number"] for m in modules}
            results: dict[int, ModuleScript] = {}
            for fut in concurrent.futures.as_completed(futures):
                results[futures[fut]] = fut.result()

        return [results[m["module_number"]] for m in modules]

    def _script_lesson(
        self,
        lesson:                  dict,
        module:                  dict,
        content:                 str,
        audience:                str,
        source_file:             str,
        parsed:                  dict | None = None,
        use_knowledge_base:      bool = False,
        language:                str = "English",
        user_req:                str = "",
        previous_lesson_summary: str | None = None,
        lesson_index:            int = 0,
        total_lessons:           int = 1,
    ) -> LessonScript:
        parsed = parsed or {}
        # Longer lessons need more source context to fill their narration.
        # Scale: 1 chunk per minute of lesson duration, minimum 8, maximum 20.
        n_chunks = min(20, max(8, lesson["duration_minutes"]))
        context = self._get_lesson_context(
            lesson["topic_focus"], source_file, content,
            n_chunks=n_chunks,
            use_knowledge_base=use_knowledge_base,
            language=language,
        )

        difficulty_line = f"DIFFICULTY: {parsed['difficulty']}" if parsed.get("difficulty") else ""
        objectives_line = f"LEARNING OBJECTIVES TO HIT: {parsed['objectives']}" if parsed.get("objectives") else ""
        depth_line      = f"DEPTH: {parsed['depth']}" if parsed.get("depth") else ""
        tone_line       = (
            f"TONE: {parsed['tone']} — maintain this tone throughout the narration."
            if parsed.get("tone") else ""
        )
        prev_lesson_line = (
            f"PREVIOUS LESSON SUMMARY: {previous_lesson_summary}\n"
            "  → Open with a brief transition from the previous lesson. "
            "Do NOT repeat its content."
            if previous_lesson_summary else ""
        )
        # Floor = exact TTS speed so even the shortest acceptable narration
        # produces a video that matches the planned duration.
        # Target = 15 % above TTS speed to push the LLM past the floor.
        tts_wpm      = self._tts_wpm(language)
        min_words    = lesson["duration_minutes"] * tts_wpm
        target_words = lesson["duration_minutes"] * int(tts_wpm * 1.15)

        prompt = f"""Script ONE lesson for an educational course.

═══ FIXED CONSTRAINTS — FOLLOW EXACTLY ═════════════════════════
OUTPUT LANGUAGE: {language}
  → Write ALL content (narration, bullets, objectives, terms,
    examples, takeaways, questions) in {language}.
    NO English unless language IS English.

{difficulty_line}
{objectives_line}
{depth_line}
{tone_line}
{prev_lesson_line}
{user_req}═════════════════════════════════════════════════════════════════

MODULE:      {module['module_title']}
LESSON:      {lesson['lesson_title']}
TOPIC FOCUS: {lesson['topic_focus']}
DURATION:    {lesson['duration_minutes']} minutes  →  narration MUST be at least {min_words} words
AUDIENCE:    {audience}

WRITING RULES:
1. narration_script — Write as a teacher SPEAKING to the class in {language}.
   Natural, engaging, first-person plural ("Let's explore...", "Think of it...").
   Do NOT just read the document — explain, give examples, make it memorable.
   *** HARD MINIMUM: {min_words} words. TARGET: {target_words} words. ***
   The narration is read aloud by TTS at ~{tts_wpm} wpm; {lesson['duration_minutes']} minutes
   of audio requires at least {min_words} words. Write fully — do not stop early.
   Expand every concept: add transitions, real examples, numbered steps, recap
   sentences. Keep writing until you reach the word target.
2. slide_bullets — 3-5 concise bullet points. Short phrases, not full sentences.
3. speaker_notes — 1-2 sentences the presenter says while showing the slide.
4. visual_description — What appears in the video scene?
5. learning_objectives — 2-3 objectives using Bloom's taxonomy action verbs.
   Use MEASURABLE verbs only:
     Knowledge/recall    → Identify, List, Define, Name, State
     Comprehension       → Explain, Describe, Summarise, Classify
     Application         → Apply, Demonstrate, Calculate, Use, Solve
     Analysis            → Analyse, Compare, Differentiate, Examine
   NEVER use "understand", "know", "learn", or "be aware of" — these are not measurable.
   Example: "By the end of this lesson, learners will be able to identify the 5 steps
   of LOTO and apply them to an electrical isolation scenario."
6. key_terms — 3-5 important vocabulary words from this lesson.
7. summary — 1-2 sentence overview.
8. simplified_explanation — Core concept in plain language (2-3 sentences).
9. key_takeaways — 3-4 actionable points the learner should remember.
10. real_world_examples — 2-3 examples GROUNDED IN THE DOCUMENT KNOWLEDGE BASE.
    Each must cite a specific situation described in the document, not an invented one.
    Use exact terminology from the source content.
11. safety_scenarios — 2-3 safety-relevant scenarios drawn from source content
    (empty list [] if not applicable).
12. assessment_questions — 3 multiple-choice questions testing this lesson's key concepts.
    Each question must have 4 options (A-D) with exactly one correct answer and a brief explanation.
    This is lesson {lesson_index + 1} of {total_lessons}.
    {"Use knowledge/recall verbs (Identify, List, Define, Name) — foundational lesson." if lesson_index < total_lessons // 3 else "Use application verbs (Apply, Demonstrate, Solve, Calculate) — mid-course lesson." if lesson_index < (total_lessons * 2) // 3 else "Use analysis verbs (Analyse, Compare, Differentiate, Evaluate) — advanced lesson."}

Fill in the script_lesson tool — ALL content in {language}.
"""
        # The document context is sent as a cached prefix so repeated calls within
        # the same generation run get token-cost discounts on the source content.
        cached_context = f"DOCUMENT KNOWLEDGE BASE (factual source for this lesson):\n{context}"
        # Scale max_tokens with lesson duration so long lessons are never truncated.
        lesson_max_tokens = max(8000, lesson["duration_minutes"] * 1200)
        data = self._call_structured(
            prompt, _LESSON_TOOL,
            max_tokens=lesson_max_tokens,
            cacheable_prefix=cached_context,
        )

        slide = SlideContent(
            title=data.get("slide_content", {}).get("title", lesson["lesson_title"]),
            bullets=data.get("slide_content", {}).get("bullets", []),
            speaker_notes=data.get("slide_content", {}).get("speaker_notes", ""),
        )
        return LessonScript(
            lesson_number=lesson["lesson_number"],
            lesson_title=lesson["lesson_title"],
            duration_minutes=lesson["duration_minutes"],
            learning_objectives=data.get("learning_objectives", []),
            narration_script=data.get("narration_script", ""),
            slide_content=slide,
            visual_description=data.get("visual_description", ""),
            key_terms=data.get("key_terms", []),
            summary=data.get("summary", ""),
            simplified_explanation=data.get("simplified_explanation", ""),
            key_takeaways=data.get("key_takeaways", []),
            real_world_examples=data.get("real_world_examples", []),
            safety_scenarios=data.get("safety_scenarios", []),
            assessment_questions=data.get("assessment_questions", []),
        )

    # ── Micro-course (single-pass custom blueprint) ─────────────────────────────

    def generate_micro_course(
        self,
        source_file:     str,
        instructions:    str,
        course_title:    str | None = None,
        target_audience: str = "learners",
        language:        str = "English",
    ) -> CourseScript:
        """
        Single-pass generation that treats `instructions` as an exact course blueprint.
        Use when instructions specify a precise structure: exact slide count,
        interleaved quizzes, or specific language requirements.
        """
        instructions = self._sanitize_instructions(instructions)
        logger.info("[custom] Fetching chunks for '%s' ...", source_file)
        chunks = self._store.get_all_by_source(source_file)
        if not chunks:
            raise ValueError(f"No chunks found for '{source_file}'.")

        full_content = "\n\n".join(
            f"[{c['metadata'].get('section_heading', '')}]\n{c['text']}"
            for c in chunks
        )
        # B1: use MMR retrieval instead of a hard-truncated slice so the model sees
        # topically relevant content spread across the whole document.
        context = self._get_lesson_context(
            instructions[:400], source_file, full_content, n_chunks=20, language=language,
        )
        logger.info("[custom] %d chunks loaded. Generating from blueprint ...", len(chunks))

        prompt = f"""You are an expert instructional designer.
Generate a complete educational course by following the COURSE BLUEPRINT below EXACTLY.

═══ FIXED CONSTRAINTS ═══════════════════════════════════════════
OUTPUT LANGUAGE: {language}
  → Write ALL text fields in {language}. NO exceptions.
TARGET AUDIENCE: {target_audience}
═════════════════════════════════════════════════════════════════

COURSE BLUEPRINT:
{instructions}

SOURCE DOCUMENT (factual knowledge base — draw all facts from this):
{context}

Rules:
- Follow the blueprint's slide order and quiz placement precisely.
- Use the exact quiz questions from the blueprint where given.
- Write ALL content in {language}.
"""
        data = self._call_structured(prompt, _MICRO_COURSE_TOOL, max_tokens=8192)

        return CourseScript(
            course_title=data.get("course_title", course_title or source_file),
            course_description=data.get("course_description", ""),
            target_audience=target_audience,
            estimated_total_duration_min=int(data.get("estimated_total_duration_min", 12)),
            source_documents=[source_file],
            items=data.get("items", []),
        )

    def generate_micro_course_from_text(
        self,
        content_text:    str,
        course_title:    str | None = None,
        target_audience: str = "learners",
        language:        str = "English",
    ) -> CourseScript:
        """Generate a custom item-based course from pasted text."""
        logger.info("[text->micro] Single-call micro-course (%d chars) ...", len(content_text))
        _content = _diverse_sample(content_text, 9_000)

        prompt = f"""You are an expert instructional designer.
Create a structured educational course from the SOURCE CONTENT below.
The content defines lesson sections and quiz questions — extract them faithfully.

═══ FIXED CONSTRAINTS ═══════════════════════════════════════════
OUTPUT LANGUAGE: {language}
  → Write ALL text fields in {language}. NO exceptions.
TARGET AUDIENCE: {target_audience}
═════════════════════════════════════════════════════════════════

SOURCE CONTENT:
{_content}
"""
        data = self._call_structured(prompt, _MICRO_COURSE_TOOL, max_tokens=8192)

        return CourseScript(
            course_title=data.get("course_title", course_title or "Course"),
            course_description=data.get("course_description", ""),
            target_audience=target_audience,
            estimated_total_duration_min=int(data.get("estimated_total_duration_min", 15)),
            source_documents=["inline_content"],
            items=data.get("items", []),
        )

    def generate_from_text(
        self,
        content_text:      str,
        course_title:      str | None = None,
        target_audience:   str = "learners",
        mode:              str = "detailed",
        language:          str = "English",
        duration_range:    str = "60-90 minutes",
        progress_callback: "Callable[[int, int], None] | None" = None,
    ) -> CourseScript:
        """Generate a course from raw pasted text without requiring ChromaDB."""
        source_name = "inline_content"
        logger.info("[text] Generating from pasted text (%d chars, mode=%s) ...", len(content_text), mode)

        analysis = self._analyse(content_text, source_name, target_audience, {}, language)
        outline  = self._outline(
            analysis,
            course_title or analysis.get("suggested_title", "Course"),
            target_audience, {}, language,
        )

        if mode == "quick":
            outline["modules"] = outline["modules"][:1]
            for m in outline["modules"]:
                m["lessons"] = m["lessons"][:2]

        total_lessons = sum(len(m["lessons"]) for m in outline["modules"])
        logger.info("[text] Step 3/3: Scripting %d lessons ...", total_lessons)

        self._inline_text = content_text
        try:
            modules = self._script_all(
                outline, content_text, target_audience, source_name,
                progress_callback, {}, False, language,
            )
        finally:
            self._inline_text = None

        total_mins = sum(l.duration_minutes for m in modules for l in m.lessons)
        return CourseScript(
            course_title=outline["course_title"],
            course_description=outline["course_description"],
            target_audience=target_audience,
            estimated_total_duration_min=total_mins,
            source_documents=[source_name],
            modules=modules,
        )

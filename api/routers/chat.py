"""
api/routers/chat.py

POST  /api/v1/chat    Ask a question, get a grounded answer with source citations.
                      When called from the in-lesson AI companion, pass lesson_id,
                      course_id, timestamp_secs, and transcript_snippet for
                      context-aware answers about the current lesson.
"""

import asyncio
import re

from fastapi import APIRouter, Depends, HTTPException

from api.config import settings
from api.dependencies import get_retrieval_pipeline, get_embedder, get_vector_store
from api.schemas import ChatRequest, ChatResponse, SourceInfo

router = APIRouter(prefix="/api/v1/chat", tags=["Chat / RAG"])

# ── Intent patterns ────────────────────────────────────────────────────────────
_RE_SUMMARIZE = re.compile(
    r'\b(summarize|summary|sum up|recap|overview|what.*(cover|about))\b', re.I
)
_RE_QUIZ = re.compile(
    r'\b(quiz|test me|generate question|practice question|knowledge check)\b', re.I
)
_RE_EXPLAIN_SECTION = re.compile(
    r'\b(explain.*(current|this) section|what.*(just|happening|said)|current (part|section|segment))\b', re.I
)

# ── Prompts ────────────────────────────────────────────────────────────────────
_SYSTEM_BASE = (
    "You are Arresto AI, a helpful safety training assistant for Arresto LMS. "
    "Answer clearly and concisely. Use markdown formatting: **bold** for key terms, "
    "bullet lists for multi-part answers, numbered lists for steps or procedures. "
    "Keep answers focused and practical."
)

_SYSTEM_WITH_DOCS = _SYSTEM_BASE + (
    " You answer questions based on the document context provided. "
    "Always mention which source document your answer comes from. "
    "If the context is insufficient, say so clearly instead of guessing."
)

_SYSTEM_LESSON = _SYSTEM_BASE + (
    " The learner is currently watching a lesson. Use the lesson transcript provided "
    "as your primary source. Refer to it directly and be specific."
)


def _lesson_context_block(transcript: str, lesson_title: str, timestamp_secs: int | None) -> str:
    lines = [f"LESSON TRANSCRIPT — {lesson_title}:", transcript[:10000]]
    if timestamp_secs is not None:
        m, s = divmod(timestamp_secs, 60)
        lines.append(f"\n(Learner is currently at {m}:{s:02d} in this lesson)")
    return "\n".join(lines)


def _build_doc_context(chunks: list[dict]) -> str:
    parts = []
    for i, c in enumerate(chunks, 1):
        meta  = c.get("metadata", {})
        page  = meta.get("page_number",  -1)
        slide = meta.get("slide_number", -1)
        loc = (
            f"page {page}"   if page  > 0 else
            f"slide {slide}" if slide > 0 else
            "document body"
        )
        heading = f" > {meta['section_heading']}" if meta.get("section_heading") else ""
        parts.append(
            f"[{i}] {meta.get('source_file', 'unknown')} ({loc}{heading})  "
            f"score: {c.get('score', 0):.2f}\n{c['text']}"
        )
    return "\n\n" + "-" * 60 + "\n\n".join(parts)


def _chunks_to_sources(chunks: list[dict]) -> list[SourceInfo]:
    sources = []
    for c in chunks:
        meta  = c.get("metadata", {})
        page  = meta.get("page_number",  -1)
        slide = meta.get("slide_number", -1)
        sources.append(SourceInfo(
            chunk_id=c["chunk_id"],
            source_file=meta.get("source_file", ""),
            score=round(c.get("score", 0), 4),
            section_heading=meta.get("section_heading") or None,
            page_number=page  if page  > 0 else None,
            slide_number=slide if slide > 0 else None,
            text_preview=c["text"][:300],
        ))
    return sources


def _call_llm(system: str, user_content: str, api_key: str, max_tokens: int = 1024) -> str:
    import anthropic
    client = anthropic.Anthropic(api_key=api_key)
    response = client.messages.create(
        model=settings.llm_model,
        max_tokens=max_tokens,
        system=system,
        messages=[{"role": "user", "content": user_content}],
    )
    return response.content[0].text


def _lookup_lesson_transcript(course_id: str, lesson_id: str) -> tuple[str, str] | None:
    """
    Look up lesson narration script from the DB.
    Returns (lesson_title, narration_script) or None if not found.
    lesson_id format: 'm{moduleNum}l{lessonNum}'
    """
    try:
        import json as _json
        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow

        m = re.match(r'm(\d+)l(\d+)', lesson_id)
        if not m:
            return None
        module_num = int(m.group(1))
        lesson_num = int(m.group(2))

        db = SessionLocal()
        try:
            row = db.query(CourseScriptRow).filter(
                CourseScriptRow.script_id == course_id
            ).first()
            if not row:
                return None
            script = _json.loads(row.course_script_json)
            for mod in script.get("modules", []):
                if mod.get("module_number") == module_num:
                    for les in mod.get("lessons", []):
                        if les.get("lesson_number") == lesson_num:
                            title     = les.get("lesson_title", "")
                            narration = les.get("narration_script", "")
                            return (title, narration) if narration else None
        finally:
            db.close()
    except Exception:
        pass
    return None


def _looks_like_uuid(s: str) -> bool:
    return bool(re.match(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', s, re.I
    ))


@router.post("", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    retrieval_pipeline=Depends(get_retrieval_pipeline),
    embedder=Depends(get_embedder),
    vector_store=Depends(get_vector_store),
):
    """
    Ask a question about any document in the knowledge base.

    When called from the in-lesson AI companion, pass lesson_id, course_id,
    timestamp_secs, and transcript_snippet for context-aware answers.

    Intent-based shortcuts (no RAG needed when transcript is available):
    - "Summarize this lesson" → summarize the full lesson transcript
    - "Generate quiz questions" → produce MCQ questions from the transcript
    - "Explain current section" → explain the transcript near the given timestamp
    """
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty.")

    # ── Resolve lesson transcript ───────────────────────────────────────────────
    transcript   = request.transcript_snippet or ""
    lesson_title = ""

    # If frontend sent lesson IDs but no transcript, try a DB lookup as fallback
    if not transcript and request.course_id and request.lesson_id:
        result = await asyncio.to_thread(
            _lookup_lesson_transcript, request.course_id, request.lesson_id
        )
        if result:
            lesson_title, transcript = result

    has_lesson_ctx = bool(transcript)

    # ── Intent detection (only when transcript is available) ───────────────────
    if has_lesson_ctx and settings.anthropic_api_key:
        q = request.question

        if _RE_SUMMARIZE.search(q):
            user_msg = (
                f"{_lesson_context_block(transcript, lesson_title, request.timestamp_secs)}\n\n"
                "Please provide a clear, structured summary of this lesson. "
                "Use bullet points for the key points."
            )
            answer = await asyncio.to_thread(
                _call_llm, _SYSTEM_LESSON, user_msg, settings.anthropic_api_key, 1024
            )
            return ChatResponse(
                question=request.question, answer=answer,
                sources=[], model_used=settings.llm_model,
            )

        if _RE_QUIZ.search(q):
            user_msg = (
                f"{_lesson_context_block(transcript, lesson_title, request.timestamp_secs)}\n\n"
                "Generate 3 multiple-choice questions to test understanding of this lesson. "
                "For each question provide:\n"
                "- The question\n"
                "- Four options (A, B, C, D)\n"
                "- The correct answer\n\n"
                "Format each question clearly, separated by a blank line."
            )
            answer = await asyncio.to_thread(
                _call_llm, _SYSTEM_LESSON, user_msg, settings.anthropic_api_key, 1500
            )
            return ChatResponse(
                question=request.question, answer=answer,
                sources=[], model_used=settings.llm_model,
            )

        if _RE_EXPLAIN_SECTION.search(q) and request.timestamp_secs is not None:
            user_msg = (
                f"{_lesson_context_block(transcript, lesson_title, request.timestamp_secs)}\n\n"
                f'The learner asks: "{q}"\n\n'
                "Explain what is being covered at this point in the lesson. "
                "Be specific and refer to the transcript."
            )
            answer = await asyncio.to_thread(
                _call_llm, _SYSTEM_LESSON, user_msg, settings.anthropic_api_key, 1024
            )
            return ChatResponse(
                question=request.question, answer=answer,
                sources=[], model_used=settings.llm_model,
            )

    # ── Standard RAG path ──────────────────────────────────────────────────────
    source_file = request.source_file
    if not source_file and request.course_id and not _looks_like_uuid(request.course_id):
        source_file = request.course_id

    try:
        if retrieval_pipeline is not None:
            result = await asyncio.to_thread(
                retrieval_pipeline.retrieve,
                request.question,
                source_file,
                [],
            )
            chunks = result.chunks
        else:
            q_vec = await asyncio.to_thread(embedder.embed_query, request.question)
            chunks = await asyncio.to_thread(
                vector_store.query, q_vec, request.n_chunks, source_file, request.asset_type,
            )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Retrieval failed: {exc}")

    sources = _chunks_to_sources(chunks)

    if not settings.anthropic_api_key:
        return ChatResponse(
            question=request.question,
            answer=(
                "[No LLM] Set ANTHROPIC_API_KEY to enable answer generation. "
                "Retrieved chunks are shown in sources."
            ),
            sources=sources,
            model_used=None,
        )

    # Build the user message — inject lesson context on top of RAG chunks when available
    if has_lesson_ctx:
        user_content = (
            f"{_lesson_context_block(transcript, lesson_title, request.timestamp_secs)}\n\n"
            f"Additional document context:\n{_build_doc_context(chunks)}\n\n"
            f"Question: {request.question}\n\n"
            "Answer using the lesson transcript and document context above."
        )
        system = _SYSTEM_LESSON
    else:
        user_content = (
            f"Document context:\n{_build_doc_context(chunks)}\n\n"
            f"Question: {request.question}\n\n"
            "Answer based on the context above. "
            "Cite the source document by name in your answer."
        )
        system = _SYSTEM_WITH_DOCS

    try:
        answer = await asyncio.to_thread(
            _call_llm, system, user_content, settings.anthropic_api_key
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Answer generation failed: {exc}")

    return ChatResponse(
        question=request.question,
        answer=answer,
        sources=sources,
        model_used=settings.llm_model,
    )

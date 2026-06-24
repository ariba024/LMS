"""
api/routers/documents.py

POST   /api/v1/documents/upload                  Upload & ingest a new file
POST   /api/v1/documents/batch-upload            Upload & ingest multiple files
POST   /api/v1/documents/ingest/{filename}       Ingest a file already in uploads/
GET    /api/v1/documents/available               List files in uploads/ with ingestion status
GET    /api/v1/documents                         List all ingested documents
GET    /api/v1/documents/jobs/{id}               Get job status
GET    /api/v1/documents/{filename}/content      Read extracted chunks for a document
DELETE /api/v1/documents/{filename}              Remove a document from both vector stores
"""

import logging
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, UploadFile, File

from api.config import settings

logger = logging.getLogger("arresto.documents")
from api.dependencies import (
    get_pipeline, get_retrieval_pipeline, get_vector_store,
    _sync_ingest,
    job_store,
    require_admin,
)
from api.schemas import (
    BatchFileResult, BatchUploadResponse,
    ChunkDetail, DeleteResponse, DocumentContentResponse,
    DocumentInfo, DocumentListResponse,
    ErrorDetail, JobStatus, UploadResponse,
)

router = APIRouter(prefix="/api/v1/documents", tags=["Documents"])

_SUPPORTED = {".pdf", ".docx", ".pptx", ".txt", ".csv"}


def _build_content(filename: str, vector_store) -> DocumentContentResponse:
    """Read all chunks for a filename from the store and build the response."""
    chunks = vector_store.get_all_by_source(filename)
    asset_type = chunks[0]["metadata"].get("asset_type", "unknown") if chunks else "unknown"
    details = [
        ChunkDetail(
            chunk_id=c["chunk_id"],
            chunk_index=c["metadata"].get("chunk_index", i),
            section_heading=c["metadata"].get("section_heading") or None,
            page_number=(
                c["metadata"]["page_number"]
                if c["metadata"].get("page_number", -1) > 0 else None
            ),
            slide_number=(
                c["metadata"]["slide_number"]
                if c["metadata"].get("slide_number", -1) > 0 else None
            ),
            token_count=c["metadata"].get("token_count", 0),
            text=c["text"],
        )
        for i, c in enumerate(chunks)
    ]
    return DocumentContentResponse(
        source_file=filename,
        asset_type=asset_type,
        total_chunks=len(details),
        full_text="\n\n".join(d.text for d in details),
        chunks=details,
    )


@router.post("/upload", status_code=202,
             responses={400: {"model": ErrorDetail}})
async def upload_document(
    background_tasks:   BackgroundTasks,
    file:               UploadFile = File(...),
    pipeline=Depends(get_pipeline),
    vector_store=Depends(get_vector_store),
    retrieval_pipeline=Depends(get_retrieval_pipeline),
    _=Depends(require_admin),
):
    """
    Upload a PDF, DOCX, or PPTX file.

    Returns 202 immediately with a job_id. Ingestion (chunking, embedding,
    BM25 index) runs in the background. Poll GET /jobs/{job_id} for status.
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="File must have a name.")

    ext = Path(file.filename).suffix.lower()
    if ext not in _SUPPORTED:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{ext}'. Supported: {sorted(_SUPPORTED)}",
        )

    safe_name = Path(file.filename).name
    dest = settings.upload_dir / safe_name
    raw  = await file.read()
    if len(raw) > settings.max_upload_mb * 1024 * 1024:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum allowed size is {settings.max_upload_mb} MB.",
        )
    dest.write_bytes(raw)

    job = job_store.create_upload(safe_name)
    background_tasks.add_task(_sync_ingest, job, dest, pipeline, retrieval_pipeline)
    return {"job_id": job.job_id, "filename": safe_name, "status": "processing"}


@router.post("/batch-upload", status_code=202)
async def batch_upload_documents(
    background_tasks: BackgroundTasks,
    files:    Annotated[list[UploadFile], File(description="Select multiple PDF / DOCX / PPTX files")],
    pipeline=Depends(get_pipeline),
    vector_store=Depends(get_vector_store),
    retrieval_pipeline=Depends(get_retrieval_pipeline),
    _=Depends(require_admin),
):
    """
    Upload multiple files (PDF, DOCX, PPTX) in one request.

    Returns 202 immediately with a list of job_ids. Each file is ingested in
    the background. Poll GET /jobs/{job_id} for per-file status.
    """
    submitted: list[dict] = []
    rejected:  list[dict] = []

    for file in files:
        if not file.filename:
            rejected.append({"filename": "<unknown>", "error": "File must have a name."})
            continue

        safe_name = Path(file.filename).name
        ext = Path(safe_name).suffix.lower()
        if ext not in _SUPPORTED:
            rejected.append({
                "filename": safe_name,
                "error": f"Unsupported type '{ext}'. Supported: {sorted(_SUPPORTED)}",
            })
            continue

        raw = await file.read()
        if len(raw) > settings.max_upload_mb * 1024 * 1024:
            rejected.append({
                "filename": safe_name,
                "error": f"File too large. Maximum is {settings.max_upload_mb} MB.",
            })
            continue

        dest = settings.upload_dir / safe_name
        dest.write_bytes(raw)
        job = job_store.create_upload(safe_name)
        background_tasks.add_task(_sync_ingest, job, dest, pipeline, retrieval_pipeline)
        submitted.append({"job_id": job.job_id, "filename": safe_name})

    return {"submitted": submitted, "rejected": rejected}


@router.get("/jobs/{job_id}", response_model=JobStatus,
            responses={404: {"model": ErrorDetail}})
def get_upload_job(job_id: str, _=Depends(require_admin)):
    """Poll the status of an upload/ingestion job."""
    job = job_store.get_upload(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job '{job_id}' not found.")
    return job.to_schema()


@router.get("", response_model=DocumentListResponse)
def list_documents(vector_store=Depends(get_vector_store), _=Depends(require_admin)):
    """Return all documents currently stored in the vector database."""
    sources = vector_store.list_sources()
    docs: list[DocumentInfo] = []
    for sf in sources:
        chunks = vector_store.get_all_by_source(sf)
        asset_type = chunks[0]["metadata"].get("asset_type", "unknown") if chunks else "unknown"
        docs.append(DocumentInfo(
            source_file=sf,
            chunk_count=len(chunks),
            asset_type=asset_type,
        ))
    return DocumentListResponse(documents=docs, total=len(docs))


@router.get("/{filename}/content", response_model=DocumentContentResponse,
            responses={404: {"model": ErrorDetail}})
def get_document_content(filename: str, vector_store=Depends(get_vector_store), _=Depends(require_admin)):
    """
    Return the full extracted text for a document, split into chunks.

    This is what was actually stored in the knowledge base after
    extraction -> cleaning -> chunking.  Use it to verify that the right
    content was captured before running chat or course generation.

    Each chunk shows:
    - **chunk_index** -- position in the document
    - **section_heading** -- nearest heading above this chunk
    - **page_number / slide_number** -- provenance
    - **text** -- the exact text that will be used for RAG retrieval
    """
    chunks = vector_store.get_all_by_source(filename)
    if not chunks:
        raise HTTPException(
            status_code=404,
            detail=f"No document named '{filename}' found. Upload it first.",
        )

    asset_type = chunks[0]["metadata"].get("asset_type", "unknown")
    chunk_details = [
        ChunkDetail(
            chunk_id=c["chunk_id"],
            chunk_index=c["metadata"].get("chunk_index", i),
            section_heading=c["metadata"].get("section_heading") or None,
            page_number=(
                c["metadata"]["page_number"]
                if c["metadata"].get("page_number", -1) > 0 else None
            ),
            slide_number=(
                c["metadata"]["slide_number"]
                if c["metadata"].get("slide_number", -1) > 0 else None
            ),
            token_count=c["metadata"].get("token_count", 0),
            text=c["text"],
        )
        for i, c in enumerate(chunks)
    ]
    full_text = "\n\n".join(cd.text for cd in chunk_details)

    return DocumentContentResponse(
        source_file=filename,
        asset_type=asset_type,
        total_chunks=len(chunk_details),
        full_text=full_text,
        chunks=chunk_details,
    )


@router.get("/available")
def list_available_files(vector_store=Depends(get_vector_store), _=Depends(require_admin)):
    """
    List every supported file in the uploads/ directory with its ingestion status.

    Use this to discover files that are already on disk and can be ingested
    without re-uploading — then call **POST /api/v1/documents/ingest/{filename}**
    to ingest any file whose `ingested` field is false.
    """
    ingested = set(vector_store.list_sources())
    files = []
    for f in sorted(settings.upload_dir.iterdir()):
        if f.is_file() and f.suffix.lower() in _SUPPORTED:
            files.append({
                "filename":   f.name,
                "size_bytes": f.stat().st_size,
                "ingested":   f.name in ingested,
            })
    return {"files": files, "total": len(files)}


@router.post("/ingest/{filename}", status_code=202,
             responses={404: {"model": ErrorDetail}, 400: {"model": ErrorDetail}})
async def ingest_existing_file(
    filename:           str,
    background_tasks:   BackgroundTasks,
    pipeline=Depends(get_pipeline),
    retrieval_pipeline=Depends(get_retrieval_pipeline),
    _=Depends(require_admin),
):
    """
    Ingest a file that already exists in the uploads/ directory.

    Use **GET /api/v1/documents/available** first to see which files are on disk.
    Returns 202 immediately with a job_id. Poll GET /jobs/{job_id} for status.

    Safe to re-run: existing chunks are overwritten (upsert), not duplicated.
    """
    file_path = settings.upload_dir / filename
    if not file_path.exists():
        raise HTTPException(
            status_code=404,
            detail=(
                f"'{filename}' not found in uploads/. "
                "Upload it first via POST /api/v1/documents/upload."
            ),
        )

    ext = file_path.suffix.lower()
    if ext not in _SUPPORTED:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{ext}'. Supported: {sorted(_SUPPORTED)}",
        )

    job = job_store.create_upload(filename)
    background_tasks.add_task(_sync_ingest, job, file_path, pipeline, retrieval_pipeline)
    return {"job_id": job.job_id, "filename": filename, "status": "processing"}


@router.delete("/{filename}", response_model=DeleteResponse,
               responses={404: {"model": ErrorDetail}})
def delete_document(
    filename:           str,
    vector_store=Depends(get_vector_store),
    retrieval_pipeline=Depends(get_retrieval_pipeline),
    _=Depends(require_admin),
):
    """Remove all chunks for a document from both vector stores (MiniLM + bge-m3)."""
    chunks = vector_store.get_all_by_source(filename)
    if not chunks:
        raise HTTPException(
            status_code=404,
            detail=f"No document named '{filename}' found in the store.",
        )
    vector_store.delete_by_source(filename)

    if retrieval_pipeline is not None:
        try:
            retrieval_pipeline.delete_source(filename)
        except Exception as exc:
            logger.warning("BGE index delete failed for '%s': %s", filename, exc)

    upload_path = settings.upload_dir / filename
    if upload_path.exists():
        upload_path.unlink()

    return DeleteResponse(message=f"'{filename}' removed ({len(chunks)} chunks deleted).")

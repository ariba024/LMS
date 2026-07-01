"""
Vector store wrapper around ChromaDB (bge-m3, 1024-dim).

Chunks are stored with their bge-m3 embedding vectors and metadata so
the RAG layer can:
  1. Run semantic similarity search (query_embedding -> top-K chunks)
  2. Filter by source_file, asset_type, page_number, slide_number, etc.
  3. Return chunk text + provenance for answer generation

ChromaDB persists to disk automatically under `persist_dir`.
The collection uses cosine similarity (hnsw:space = "cosine").
Collection name: lms_chunks_bge_m3 (1024-dim; previously lms_chunks at 384-dim).
"""

from __future__ import annotations
import logging
import re

logger = logging.getLogger("arresto.vector_store")

from pathlib import Path
from typing import TYPE_CHECKING


def _heading_slug(heading: str | None) -> str:
    """5D — stable lowercase slug for section_id filtering."""
    if not heading:
        return ""
    return re.sub(r"[^a-z0-9]+", "_", heading.lower())[:60].strip("_")

if TYPE_CHECKING:
    from modules.content_ingestion.models import Chunk

_COLLECTION = "lms_chunks_bge_m3"


class VectorStore:

    def __init__(self, persist_dir: str = "./chroma_db") -> None:
        try:
            import chromadb
        except ImportError as exc:
            raise RuntimeError(
                "VectorStore requires 'chromadb'.\n"
                "Install with:  pip install chromadb"
            ) from exc

        Path(persist_dir).mkdir(parents=True, exist_ok=True)
        self._client = chromadb.PersistentClient(path=persist_dir)
        self._col = self._client.get_or_create_collection(
            name=_COLLECTION,
            metadata={"hnsw:space": "cosine"},
        )
        logger.info("Collection '%s' ready -- %d chunks already stored.", _COLLECTION, self._col.count())

    def _reconnect(self) -> None:
        """Re-fetch the collection handle when it becomes stale.

        This happens if the collection is deleted and recreated externally
        (e.g. by a migration script) while the server is running. ChromaDB
        collection objects hold an internal UUID that becomes invalid after
        deletion — re-fetching gives us the new UUID.
        """
        self._col = self._client.get_or_create_collection(
            name=_COLLECTION,
            metadata={"hnsw:space": "cosine"},
        )
        logger.info("Reconnected to '%s' (%d chunks).", _COLLECTION, self._col.count())

    def _col_op(self, fn):
        """Call fn(col), retrying once after reconnect on NotFoundError."""
        try:
            return fn(self._col)
        except Exception as exc:
            if "does not exist" in str(exc).lower() or "notfound" in type(exc).__name__.lower():
                self._reconnect()
                return fn(self._col)
            raise

    # -- Write ------------------------------------------------------------------

    def upsert(self, chunks: list["Chunk"]) -> None:
        """Insert or update chunks.  Existing chunk_ids are overwritten."""
        if not chunks:
            return
        metadatas = [
            {
                "source_file":     c.source_file,
                "asset_type":      c.asset_type,
                "chunk_index":     c.chunk_index,
                "page_number":     c.page_number  if c.page_number  is not None else -1,
                "slide_number":    c.slide_number if c.slide_number is not None else -1,
                "section_heading": c.section_heading or "",
                # 5D: slug of the heading for exact filter queries
                "section_id":      _heading_slug(c.section_heading),
                "token_count":     c.token_count,
                "is_ocr":          c.is_ocr,
                "is_table":        c.is_table,
                "is_procedure":    c.is_procedure,   # 3F
                "doc_title":       c.doc_title,       # 1E
                "doc_author":      c.doc_author,      # 1E
            }
            for c in chunks
        ]
        self._col_op(lambda col: col.upsert(
            ids=[c.chunk_id for c in chunks],
            embeddings=[c.embedding for c in chunks],
            documents=[c.text for c in chunks],
            metadatas=metadatas,
        ))
        logger.info("Upserted %d chunks. Total in DB: %d", len(chunks), self.count())

    def delete_by_source(self, source_file: str) -> None:
        """Remove all chunks belonging to a given source file."""
        self._col_op(lambda col: col.delete(where={"source_file": source_file}))

    # -- Read -------------------------------------------------------------------

    def query(
        self,
        query_embedding: list[float],
        n_results: int = 5,
        source_file: str | None = None,
        asset_type: str | None = None,
        min_score: float = 0.0,
    ) -> list[dict]:
        """
        Return the top-n_results most similar chunks.

        Optional filters:
          source_file  - restrict to one document
          asset_type   - restrict to "pdf", "docx", or "pptx"
          min_score    - discard chunks with cosine similarity below this value
                         (0.0 = no filter; 0.55 = reasonable quality floor)
        """
        where: dict | None = None
        if source_file and asset_type:
            where = {"$and": [{"source_file": source_file},
                               {"asset_type": asset_type}]}
        elif source_file:
            where = {"source_file": source_file}
        elif asset_type:
            where = {"asset_type": asset_type}

        n = min(n_results, self.count())
        if n == 0:
            return []

        results = self._col_op(lambda col: col.query(
            query_embeddings=[query_embedding],
            n_results=n,
            where=where,
            include=["documents", "metadatas", "distances"],
        ))

        hits = [
            {
                "chunk_id":  results["ids"][0][i],
                "text":      results["documents"][0][i],
                "metadata":  results["metadatas"][0][i],
                "score":     round(1 - results["distances"][0][i], 4),
            }
            for i in range(len(results["ids"][0]))
        ]

        if min_score > 0.0:
            hits = [h for h in hits if h["score"] >= min_score]

        return hits

    def mmr_query(
        self,
        query_embedding: list[float],
        n_results: int = 5,
        fetch_k: int = 20,
        lambda_mult: float = 0.6,
        source_file: str | None = None,
        asset_type: str | None = None,
        min_score: float = 0.0,
    ) -> list[dict]:
        """
        Maximal Marginal Relevance retrieval — returns diverse, relevant chunks.

        Fetches `fetch_k` candidates then greedily selects `n_results` that
        maximise:  λ·sim(query, doc) − (1−λ)·max(sim(doc, selected_doc))
        lambda_mult=1.0 → pure similarity; lambda_mult=0.0 → pure diversity.
        Falls back to plain query() when numpy is unavailable.
        """
        try:
            import numpy as np
        except ImportError:
            return self.query(query_embedding, n_results, source_file, asset_type, min_score)

        where: dict | None = None
        if source_file and asset_type:
            where = {"$and": [{"source_file": source_file}, {"asset_type": asset_type}]}
        elif source_file:
            where = {"source_file": source_file}
        elif asset_type:
            where = {"asset_type": asset_type}

        n = min(max(n_results, fetch_k), self.count())
        if n == 0:
            return []

        results = self._col_op(lambda col: col.query(
            query_embeddings=[query_embedding],
            n_results=n,
            where=where,
            include=["documents", "metadatas", "distances", "embeddings"],
        ))

        hits = [
            {
                "chunk_id":  results["ids"][0][i],
                "text":      results["documents"][0][i],
                "metadata":  results["metadatas"][0][i],
                "score":     round(1 - results["distances"][0][i], 4),
                "_vec":      np.array(results["embeddings"][0][i], dtype=np.float32),
            }
            for i in range(len(results["ids"][0]))
        ]

        if min_score > 0.0:
            hits = [h for h in hits if h["score"] >= min_score]

        if len(hits) <= n_results:
            for h in hits:
                del h["_vec"]
            return hits

        # Greedy MMR selection
        selected: list[int] = []
        remaining = list(range(len(hits)))

        # Seed: highest-relevance chunk
        best = max(remaining, key=lambda i: hits[i]["score"])
        selected.append(best)
        remaining.remove(best)

        while len(selected) < n_results and remaining:
            best_idx, best_mmr = None, float("-inf")
            for i in remaining:
                relevance   = hits[i]["score"]
                v_i         = hits[i]["_vec"]
                norm_i      = float(np.linalg.norm(v_i)) + 1e-8
                redundancy  = max(
                    float(np.dot(v_i, hits[j]["_vec"]) /
                          (norm_i * (float(np.linalg.norm(hits[j]["_vec"])) + 1e-8)))
                    for j in selected
                )
                mmr = lambda_mult * relevance - (1 - lambda_mult) * redundancy
                if mmr > best_mmr:
                    best_mmr, best_idx = mmr, i
            selected.append(best_idx)
            remaining.remove(best_idx)

        result = []
        for i in selected:
            h = {k: v for k, v in hits[i].items() if k != "_vec"}
            result.append(h)
        return result

    def get_all_by_source(self, source_file: str) -> list[dict]:
        """Return every chunk stored for a given source file, ordered by chunk_index."""
        results = self._col_op(lambda col: col.get(
            where={"source_file": source_file},
            include=["documents", "metadatas"],
        ))
        rows = [
            {
                "chunk_id": results["ids"][i],
                "text":     results["documents"][i],
                "metadata": results["metadatas"][i],
            }
            for i in range(len(results["ids"]))
        ]
        rows.sort(key=lambda r: r["metadata"].get("chunk_index", 0))
        return rows

    def list_sources(self) -> list[str]:
        """Return unique source_file values across all stored chunks."""
        if self.count() == 0:
            return []
        results = self._col_op(lambda col: col.get(include=["metadatas"]))
        seen: set[str] = set()
        sources: list[str] = []
        for m in results["metadatas"]:
            sf = m.get("source_file", "")
            if sf and sf not in seen:
                seen.add(sf)
                sources.append(sf)
        return sorted(sources)

    def count(self) -> int:
        return self._col_op(lambda col: col.count())

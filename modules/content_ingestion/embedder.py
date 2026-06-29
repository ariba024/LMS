"""
Text embedder using sentence-transformers (BAAI/bge-m3).

bge-m3 produces 1024-dimensional vectors and supports 100+ languages,
making it suitable for multilingual safety training content.
The model (~570 MB) is downloaded once and cached by sentence-transformers.

Previously used all-MiniLM-L6-v2 (384-dim, English-only).
Switching to bge-m3 aligns the ingestion embeddings with the retrieval
pipeline so both RAG chat and the AI tutor operate in the same vector space.

NOTE: existing ChromaDB data embedded with MiniLM must be re-ingested —
the vector dimension changed from 384 to 1024.
"""

from __future__ import annotations
import logging

logger = logging.getLogger("arresto.embedder")

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from modules.content_ingestion.models import Chunk

_DEFAULT_MODEL = "BAAI/bge-m3"


class Embedder:
    """Lazy-loading sentence-transformer embedder."""

    def __init__(self, model_name: str = _DEFAULT_MODEL, batch_size: int = 32) -> None:
        self.model_name  = model_name
        self._batch_size = batch_size
        self._model      = None

    def _load(self) -> None:
        if self._model is not None:
            return
        try:
            from sentence_transformers import SentenceTransformer
        except ImportError as exc:
            raise RuntimeError(
                "Embedding requires 'sentence-transformers'.\n"
                "Install with:  pip install sentence-transformers"
            ) from exc
        logger.info("Loading '%s' ...", self.model_name)
        self._model = SentenceTransformer(self.model_name)
        dim = self._model.get_sentence_embedding_dimension()
        logger.info("Ready -- embedding dimension: %d", dim)

    @property
    def dimension(self) -> int:
        self._load()
        return self._model.get_sentence_embedding_dimension()

    def embed_texts(self, texts: list[str]) -> list[list[float]]:
        """Embed a list of strings; returns a parallel list of float vectors."""
        self._load()
        vectors = self._model.encode(
            texts,
            show_progress_bar=True,
            convert_to_numpy=True,
            batch_size=self._batch_size,
        )
        return vectors.tolist()

    def embed_query(self, text: str) -> list[float]:
        """Embed a single query string (no progress bar)."""
        self._load()
        # bge-m3 is asymmetric: queries need this instruction prefix for best
        # retrieval quality; documents are encoded without any prefix.
        prefixed = f"Represent this sentence for searching relevant passages: {text}"
        return self._model.encode(prefixed, convert_to_numpy=True).tolist()

    def embed_chunks(self, chunks: list["Chunk"]) -> list["Chunk"]:
        """Embed every chunk in place; returns the same list with .embedding set."""
        if not chunks:
            return chunks
        logger.info("Embedding %d chunks ...", len(chunks))
        vectors = self.embed_texts([c.text for c in chunks])
        for chunk, vec in zip(chunks, vectors):
            chunk.embedding = vec
        logger.info("Done.")
        return chunks


_DEFAULT_RERANKER = "cross-encoder/ms-marco-MiniLM-L-6-v2"


class Reranker:
    """
    4B — Optional cross-encoder reranker for post-MMR precision improvement.

    After MMR retrieval returns a diverse candidate set, the cross-encoder
    scores each (query, chunk) pair jointly — much more accurate than
    bi-encoder cosine similarity because the query and document attend to
    each other. The model (~90 MB) is downloaded once on first use.

    Graceful fallback: if sentence-transformers is not installed or the model
    fails to load, rerank() returns the input list unchanged so generation
    is never blocked.
    """

    def __init__(self, model_name: str = _DEFAULT_RERANKER) -> None:
        self.model_name = model_name
        self._model     = None

    def _load(self) -> None:
        if self._model is not None:
            return
        try:
            from sentence_transformers import CrossEncoder
        except ImportError as exc:
            raise RuntimeError(
                "Reranker requires 'sentence-transformers'.\n"
                "Install with:  pip install sentence-transformers"
            ) from exc
        logger.info("Loading reranker '%s' ...", self.model_name)
        self._model = CrossEncoder(self.model_name)
        logger.info("Reranker ready.")

    def rerank(
        self,
        query: str,
        hits:  list[dict],
        top_k: int | None = None,
    ) -> list[dict]:
        """
        Rerank `hits` (each with a "text" key) by cross-encoder score.
        Returns the same dicts sorted best-first; adds a "rerank_score" key.
        Falls back silently to the original order if the model cannot load.
        """
        if not hits:
            return hits
        try:
            self._load()
        except RuntimeError as exc:
            logger.debug("Reranker unavailable, skipping: %s", exc)
            return hits
        pairs  = [(query, h["text"]) for h in hits]
        scores = self._model.predict(pairs)
        ranked = sorted(
            zip(hits, scores), key=lambda x: float(x[1]), reverse=True
        )
        result = []
        for h, score in ranked:
            h = dict(h)
            h["rerank_score"] = round(float(score), 4)
            result.append(h)
        if top_k:
            result = result[:top_k]
        return result

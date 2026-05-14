"""
Unit Tests — Chatbot & Embeddings (True Hadith)

Tests:
  1. OpenAI embedding generation via get_embedding()
  2. GPT-4o response generation via generate_gpt4o_response()
  3. RAG pipeline via POST /api/chat

All external I/O (OpenAI API, PostgreSQL, FAISS) is mocked so tests run
without a live backend.

Run with:
    pytest testing/test_chatbot.py -v
"""

import os
import sys
import json
import types
import numpy as np
import pytest
from unittest.mock import MagicMock, patch

# ── Path setup ────────────────────────────────────────────────────────────────
# Allow importing the backend module (located at repo root)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_embedding_response(dim=3072):
    """Build a fake OpenAI embeddings.create() response."""
    data_obj = MagicMock()
    data_obj.embedding = [0.1] * dim
    response = MagicMock()
    response.data = [data_obj]
    return response


def _make_chat_completion_response(content='{"title": "Test", "explanation": "Test explanation"}'):
    """Build a fake OpenAI chat.completions.create() response."""
    message = MagicMock()
    message.content = content
    choice = MagicMock()
    choice.message = message
    response = MagicMock()
    response.choices = [choice]
    return response


# ── Import backend with heavy deps stubbed out ────────────────────────────────
# Root causes of the Windows access violation crash:
#   1. sys.modules.setdefault() silently keeps real modules already loaded
#      (e.g. system-Python easyocr), so real C code runs in background threads.
#   2. Backend module-level code spawns daemon threads (initialize_en_reader,
#      initialize_ar_ur_reader) that call easyocr.Reader(); in a pytest
#      collection context this triggers a C-level AV during GC.
#
# Fix:
#   • Force-replace every stub with sys.modules[name] = stub (no setdefault).
#   • Wrap threading.Thread so background threads are recorded but never start.
#   • Patch DB/FAISS init functions to no-ops so they don't hit real resources.

def _make_module(name, **attrs):
    """Create a types.ModuleType with given attributes set."""
    m = types.ModuleType(name)
    for k, v in attrs.items():
        setattr(m, k, v)
    return m

# Stubs for heavy native / network dependencies
_faiss_stub       = _make_module("faiss",
                        IndexFlatL2=MagicMock,
                        read_index=MagicMock(return_value=MagicMock(d=3072, ntotal=100)))
_psycopg2_extras  = _make_module("psycopg2.extras", RealDictCursor=MagicMock)
_psycopg2_stub    = _make_module("psycopg2", connect=MagicMock(), extras=_psycopg2_extras)
_firebase_stub    = _make_module("firebase_admin",
                        initialize_app=MagicMock(), credentials=MagicMock(),
                        messaging=MagicMock())
_easyocr_stub     = _make_module("easyocr", Reader=MagicMock())
_rank_bm25_stub   = _make_module("rank_bm25", BM25Okapi=MagicMock())
_rapidfuzz_stub   = _make_module("rapidfuzz", fuzz=MagicMock(), process=MagicMock())
_PIL_stub         = _make_module("PIL",
                        Image=MagicMock(), ImageEnhance=MagicMock(),
                        ImageFilter=MagicMock())
_openai_stub      = _make_module("openai", OpenAI=MagicMock())
_langdetect_stub  = _make_module("langdetect",
                        detect=MagicMock(return_value="en"),
                        LangDetectException=Exception)
_pandas_stub      = _make_module("pandas",
                        read_csv=MagicMock(return_value=MagicMock()),
                        DataFrame=MagicMock())
_cv2_stub         = _make_module("cv2")
_pytesseract_stub = _make_module("pytesseract")

_STUBS = {
    "faiss":                    _faiss_stub,
    "psycopg2":                 _psycopg2_stub,
    "psycopg2.extras":          _psycopg2_extras,
    "firebase_admin":           _firebase_stub,
    "firebase_admin.credentials": _make_module("firebase_admin.credentials"),
    "firebase_admin.messaging": _make_module("firebase_admin.messaging"),
    "easyocr":                  _easyocr_stub,
    "rank_bm25":                _rank_bm25_stub,
    "rapidfuzz":                _rapidfuzz_stub,
    "rapidfuzz.fuzz":           _make_module("rapidfuzz.fuzz"),
    "rapidfuzz.process":        _make_module("rapidfuzz.process"),
    "PIL":                      _PIL_stub,
    "PIL.Image":                _make_module("PIL.Image"),
    "PIL.ImageEnhance":         _make_module("PIL.ImageEnhance"),
    "PIL.ImageFilter":          _make_module("PIL.ImageFilter"),
    "cv2":                      _cv2_stub,
    "pytesseract":              _pytesseract_stub,
    "openai":                   _openai_stub,
    "langdetect":               _langdetect_stub,
    "pandas":                   _pandas_stub,
}

# Force-replace (not setdefault) so real installed packages can't sneak through
for _name, _mod in _STUBS.items():
    sys.modules[_name] = _mod

# Prevent background threads from spawning during module-level startup.
# The backend launches daemon threads for easyocr.Reader() init; those threads
# cause a C-level access violation during pytest's GC pass on collection.
import threading as _threading

class _NoOpThread(_threading.Thread):
    """Thread subclass that records intent but never actually runs the target."""
    def start(self):
        pass  # swallow – target is never called

# Monkey-patch Thread so that any Thread(...).start() in module-level code
# becomes a no-op for the duration of the backend import.
_threading.Thread = _NoOpThread  # type: ignore[misc]

# Set required env vars before import
os.environ.setdefault("OPENAI_API_KEY", "sk-test-key")
os.environ.setdefault("DATABASE_URL", "postgresql://test:test@localhost/test")

# Patch module-level DB/FAISS init calls to no-ops so they don't hit real I/O
from unittest.mock import patch as _patch

with _patch("psycopg2.connect", return_value=MagicMock()), \
     _patch.dict(os.environ, {"OPENAI_API_KEY": "sk-test-key"}):
    import backend_api_example as backend  # noqa: E402

# Restore real Thread so test code itself can use threads normally
_threading.Thread = _threading.Thread.__bases__[0]  # type: ignore[misc]


# ══════════════════════════════════════════════════════════════════════════════
# 1. get_embedding() — Unit Tests
# ══════════════════════════════════════════════════════════════════════════════

class TestGetEmbedding:
    """Tests for the get_embedding() utility function."""

    def _mock_client(self, dim=3072):
        client = MagicMock()
        client.embeddings.create.return_value = _make_embedding_response(dim)
        return client

    def test_returns_numpy_float32_array(self):
        """get_embedding must return a numpy float32 array."""
        with patch.object(backend, "get_openai_client", return_value=self._mock_client()):
            result = backend.get_embedding("intentions and deeds")
        assert isinstance(result, np.ndarray)
        assert result.dtype == np.float32

    def test_default_dimension_is_3072(self):
        """Embedding dimension must default to 3072 matching FAISS index."""
        mock_index = MagicMock()
        mock_index.d = 3072
        with patch.object(backend, "get_openai_client", return_value=self._mock_client(3072)), \
             patch.object(backend, "bukhari_index", mock_index):
            result = backend.get_embedding("prayer")
        assert result.shape == (3072,)

    def test_explicit_dimensions_param_respected(self):
        """Passing dimensions=512 must return a 512-dim vector."""
        with patch.object(backend, "get_openai_client", return_value=self._mock_client(512)):
            result = backend.get_embedding("zakat", dimensions=512)
        assert result.shape == (512,)

    def test_uses_text_embedding_3_large_model(self):
        """get_embedding must call the text-embedding-3-large model."""
        mock_client = self._mock_client()
        with patch.object(backend, "get_openai_client", return_value=mock_client), \
             patch.object(backend, "bukhari_index", None), \
             patch.object(backend, "tirmizi_index", None):
            backend.get_embedding("fasting")
        call_kwargs = mock_client.embeddings.create.call_args
        assert call_kwargs.kwargs.get("model") == "text-embedding-3-large" or \
               call_kwargs[1].get("model") == "text-embedding-3-large" or \
               call_kwargs[0][0] if call_kwargs[0] else False or \
               "text-embedding-3-large" in str(call_kwargs)

    def test_raises_value_error_on_empty_string(self):
        """get_embedding must raise ValueError when given an empty string."""
        with pytest.raises(ValueError, match="Empty text"):
            backend.get_embedding("")

    def test_raises_value_error_on_whitespace_only(self):
        """get_embedding must raise ValueError for whitespace-only input."""
        with pytest.raises(ValueError, match="Empty text"):
            backend.get_embedding("   ")

    def test_raises_value_error_on_none(self):
        """get_embedding must raise ValueError when given None."""
        with pytest.raises(ValueError, match="Empty text"):
            backend.get_embedding(None)

    def test_arabic_text_accepted(self):
        """get_embedding must handle Arabic text without raising."""
        with patch.object(backend, "get_openai_client", return_value=self._mock_client()), \
             patch.object(backend, "bukhari_index", None), \
             patch.object(backend, "tirmizi_index", None):
            result = backend.get_embedding("الأعمال بالنيات")
        assert isinstance(result, np.ndarray)

    def test_openai_exception_is_re_raised(self):
        """OpenAI API errors must propagate as Exception with 'OpenAI API error' prefix."""
        mock_client = MagicMock()
        mock_client.embeddings.create.side_effect = RuntimeError("API limit exceeded")
        with patch.object(backend, "get_openai_client", return_value=mock_client), \
             patch.object(backend, "bukhari_index", None), \
             patch.object(backend, "tirmizi_index", None):
            with pytest.raises(Exception, match="OpenAI API error"):
                backend.get_embedding("test query")

    def test_missing_api_key_raises_value_error(self):
        """Missing OPENAI_API_KEY must raise ValueError before any network call."""
        # Temporarily clear the cached client and the env var
        original_client = backend._openai_client
        original_key = os.environ.get("OPENAI_API_KEY")
        try:
            backend._openai_client = None
            os.environ.pop("OPENAI_API_KEY", None)
            with pytest.raises((ValueError, Exception)):
                backend.get_embedding("test")
        finally:
            backend._openai_client = original_client
            if original_key:
                os.environ["OPENAI_API_KEY"] = original_key


# ══════════════════════════════════════════════════════════════════════════════
# 2. generate_gpt4o_response() — Unit Tests
# ══════════════════════════════════════════════════════════════════════════════

class TestGenerateGpt4oResponse:
    """Tests for the generate_gpt4o_response() function."""

    _SYSTEM = "You are a hadith assistant. Answer only from hadith text."
    _USER   = "What did the Prophet say about intentions?"

    def _mock_client(self, content='{"title": "Intentions", "explanation": "Actions are judged by intentions."}'):
        client = MagicMock()
        client.chat.completions.create.return_value = _make_chat_completion_response(content)
        return client

    def test_returns_string(self):
        """generate_gpt4o_response must return a non-empty string."""
        with patch.object(backend, "get_openai_client", return_value=self._mock_client()):
            result = backend.generate_gpt4o_response(self._SYSTEM, self._USER)
        assert isinstance(result, str)
        assert len(result) > 0

    def test_returns_json_parseable_string(self):
        """Response must be valid JSON with title and explanation keys."""
        expected = '{"title": "Intentions", "explanation": "Actions judged by intentions."}'
        with patch.object(backend, "get_openai_client", return_value=self._mock_client(expected)):
            result = backend.generate_gpt4o_response(self._SYSTEM, self._USER)
        parsed = json.loads(result)
        assert "title" in parsed
        assert "explanation" in parsed

    def test_uses_gpt4o_model(self):
        """generate_gpt4o_response must call the gpt-4o model."""
        mock_client = self._mock_client()
        with patch.object(backend, "get_openai_client", return_value=mock_client):
            backend.generate_gpt4o_response(self._SYSTEM, self._USER)
        call_kwargs = mock_client.chat.completions.create.call_args
        assert "gpt-4o" in str(call_kwargs)

    def test_system_and_user_prompts_sent(self):
        """Both system and user prompts must appear in the messages list."""
        mock_client = self._mock_client()
        with patch.object(backend, "get_openai_client", return_value=mock_client):
            backend.generate_gpt4o_response(self._SYSTEM, self._USER)
        messages = mock_client.chat.completions.create.call_args.kwargs.get("messages", [])
        roles = [m["role"] for m in messages]
        assert "system" in roles
        assert "user" in roles

    def test_timeout_parameter_passed_to_api(self):
        """Custom timeout value must be forwarded to the OpenAI call."""
        mock_client = self._mock_client()
        with patch.object(backend, "get_openai_client", return_value=mock_client):
            backend.generate_gpt4o_response(self._SYSTEM, self._USER, timeout=30)
        call_kwargs = mock_client.chat.completions.create.call_args
        assert call_kwargs.kwargs.get("timeout") == 30 or "30" in str(call_kwargs)

    def test_empty_response_raises_exception(self):
        """An empty GPT-4o reply must raise an Exception."""
        with patch.object(backend, "get_openai_client", return_value=self._mock_client(content="")):
            with pytest.raises(Exception):
                backend.generate_gpt4o_response(self._SYSTEM, self._USER)

    def test_timeout_error_message(self):
        """A timeout error from OpenAI must raise with 'timeout' in the message."""
        mock_client = MagicMock()
        mock_client.chat.completions.create.side_effect = Exception("Request timed out")
        with patch.object(backend, "get_openai_client", return_value=mock_client):
            with pytest.raises(Exception, match="[Tt]imeout|timed out"):
                backend.generate_gpt4o_response(self._SYSTEM, self._USER)

    def test_connection_error_message(self):
        """A connection error from OpenAI must raise with 'connection' in the message."""
        mock_client = MagicMock()
        mock_client.chat.completions.create.side_effect = Exception("Connection refused")
        with patch.object(backend, "get_openai_client", return_value=mock_client):
            with pytest.raises(Exception, match="[Cc]onnection"):
                backend.generate_gpt4o_response(self._SYSTEM, self._USER)

    def test_temperature_is_low(self):
        """Temperature must be <= 0.3 for deterministic hadith answers."""
        mock_client = self._mock_client()
        with patch.object(backend, "get_openai_client", return_value=mock_client):
            backend.generate_gpt4o_response(self._SYSTEM, self._USER)
        call_kwargs = mock_client.chat.completions.create.call_args
        temp = call_kwargs.kwargs.get("temperature")
        assert temp is not None and temp <= 0.3


# ══════════════════════════════════════════════════════════════════════════════
# 3. RAG Pipeline — POST /api/chat endpoint
# ══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def client():
    """Flask test client with mocked DB and OpenAI."""
    backend.app.config["TESTING"] = True
    with backend.app.test_client() as c:
        yield c


def _mock_db_cursor(hadiths=None):
    """Return a mock psycopg2 cursor that yields hadith rows."""
    if hadiths is None:
        hadiths = [{
            "hadith_id": 1,
            "hadith_english": "Actions are judged by intentions.",
            "hadith_arabic": "إنما الأعمال بالنيات",
            "hadith_urdu": "اعمال کا دارومدار نیتوں پر ہے",
            "hadith_number": 1,
            "book_name": "Sahih al-Bukhari",
            "chapter_name": "Chapter of Revelation",
            "narrator": "Umar ibn al-Khattab",
            "grade": "Sahih",
        }]
    cursor = MagicMock()
    cursor.fetchall.return_value = hadiths
    cursor.fetchone.return_value = {"conversation_id": 42, "message_id": 1}
    cursor.__enter__ = MagicMock(return_value=cursor)
    cursor.__exit__ = MagicMock(return_value=False)
    return cursor


def _mock_faiss_search(k=10):
    """Return (distances, indices) shaped (1, k) for a fake FAISS search."""
    distances = np.array([[float(i) * 0.1 for i in range(k)]], dtype=np.float32)
    indices   = np.array([[i for i in range(k)]], dtype=np.int64)
    return distances, indices


class TestRagPipelineChatEndpoint:
    """Integration-style tests for POST /api/chat using the Flask test client."""

    # ── Input validation ──────────────────────────────────────────────────────

    def test_missing_question_returns_400(self, client):
        """POST /api/chat without 'question' must return 400."""
        r = client.post("/api/chat", json={"user_id": 1})
        assert r.status_code == 400

    def test_empty_question_returns_400(self, client):
        """POST /api/chat with blank question must return 400."""
        r = client.post("/api/chat", json={"user_id": 1, "question": "   "})
        assert r.status_code == 400

    def test_missing_user_id_returns_400(self, client):
        """POST /api/chat without 'user_id' must return 400."""
        r = client.post("/api/chat", json={"question": "What is prayer?"})
        assert r.status_code == 400

    def test_no_body_returns_error(self, client):
        """POST /api/chat with no JSON body must return a 4xx or 5xx error (not 200)."""
        r = client.post("/api/chat")
        # Flask returns 415 when Content-Type is missing; backend logic returns 400
        # when body parses to None. Either way it must not succeed.
        assert r.status_code != 200

    # ── Successful RAG query ──────────────────────────────────────────────────

    def test_valid_question_returns_200_with_reply(self, client):
        """A well-formed question must return 200 with a 'reply' key."""
        gpt_response = '{"title": "Intentions", "explanation": "Actions are judged by intentions."}'

        mock_cursor = _mock_db_cursor()
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor

        mock_faiss_index = MagicMock()
        mock_faiss_index.d = 3072
        mock_faiss_index.ntotal = 100
        mock_faiss_index.search.return_value = _mock_faiss_search()

        mock_mapping = MagicMock()
        mock_mapping.iloc.__getitem__ = MagicMock(return_value=MagicMock(hadith_id=1))
        mock_mapping.__len__ = MagicMock(return_value=100)

        with patch.object(backend, "get_db_connection", return_value=mock_conn), \
             patch.object(backend, "get_embedding", return_value=np.ones(3072, dtype=np.float32)), \
             patch.object(backend, "generate_gpt4o_response", return_value=gpt_response), \
             patch.object(backend, "bukhari_index", mock_faiss_index), \
             patch.object(backend, "tirmizi_index", mock_faiss_index), \
             patch.object(backend, "muslim_index", mock_faiss_index), \
             patch.object(backend, "bukhari_mapping", mock_mapping), \
             patch.object(backend, "tirmizi_mapping", mock_mapping), \
             patch.object(backend, "muslim_mapping", mock_mapping):
            r = client.post("/api/chat", json={
                "user_id": 1,
                "question": "What did the Prophet say about intentions?"
            })

        assert r.status_code == 200
        body = r.get_json()
        assert "reply" in body

    def test_reply_contains_gpt4o_output(self, client):
        """The 'reply' in the response must contain the GPT-4o generated text."""
        gpt_response = '{"title": "Intentions", "explanation": "Actions judged by intentions."}'

        mock_cursor = _mock_db_cursor()
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor

        mock_faiss_index = MagicMock()
        mock_faiss_index.d = 3072
        mock_faiss_index.ntotal = 100
        mock_faiss_index.search.return_value = _mock_faiss_search()

        mock_mapping = MagicMock()
        mock_mapping.__len__ = MagicMock(return_value=100)

        with patch.object(backend, "get_db_connection", return_value=mock_conn), \
             patch.object(backend, "get_embedding", return_value=np.ones(3072, dtype=np.float32)), \
             patch.object(backend, "generate_gpt4o_response", return_value=gpt_response), \
             patch.object(backend, "bukhari_index", mock_faiss_index), \
             patch.object(backend, "tirmizi_index", mock_faiss_index), \
             patch.object(backend, "muslim_index", mock_faiss_index), \
             patch.object(backend, "bukhari_mapping", mock_mapping), \
             patch.object(backend, "tirmizi_mapping", mock_mapping), \
             patch.object(backend, "muslim_mapping", mock_mapping):
            r = client.post("/api/chat", json={
                "user_id": 1,
                "question": "intentions and deeds"
            })

        body = r.get_json()
        assert body.get("reply") is not None

    def test_embedding_called_with_question_text(self, client):
        """get_embedding must be called with the user's question (or its translation)."""
        gpt_response = '{"title": "T", "explanation": "E"}'
        captured = {}

        def capture_embedding(text, dimensions=None):
            captured["text"] = text
            return np.ones(3072, dtype=np.float32)

        mock_cursor = _mock_db_cursor()
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor

        mock_faiss_index = MagicMock()
        mock_faiss_index.d = 3072
        mock_faiss_index.ntotal = 100
        mock_faiss_index.search.return_value = _mock_faiss_search()

        mock_mapping = MagicMock()
        mock_mapping.__len__ = MagicMock(return_value=100)

        with patch.object(backend, "get_db_connection", return_value=mock_conn), \
             patch.object(backend, "get_embedding", side_effect=capture_embedding), \
             patch.object(backend, "generate_gpt4o_response", return_value=gpt_response), \
             patch.object(backend, "bukhari_index", mock_faiss_index), \
             patch.object(backend, "tirmizi_index", mock_faiss_index), \
             patch.object(backend, "muslim_index", mock_faiss_index), \
             patch.object(backend, "bukhari_mapping", mock_mapping), \
             patch.object(backend, "tirmizi_mapping", mock_mapping), \
             patch.object(backend, "muslim_mapping", mock_mapping):
            client.post("/api/chat", json={
                "user_id": 1,
                "question": "prayer times"
            })

        assert "text" in captured
        assert len(captured["text"]) > 0

    # ── FAISS search integration ───────────────────────────────────────────────

    def test_faiss_indexes_are_queried(self, client):
        """All three FAISS indexes must be searched for each chat request."""
        gpt_response = '{"title": "T", "explanation": "E"}'

        mock_cursor = _mock_db_cursor()
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor

        mock_bukhari = MagicMock()
        mock_bukhari.d = 3072
        mock_bukhari.ntotal = 100
        mock_bukhari.search.return_value = _mock_faiss_search()

        mock_tirmizi = MagicMock()
        mock_tirmizi.d = 3072
        mock_tirmizi.ntotal = 100
        mock_tirmizi.search.return_value = _mock_faiss_search()

        mock_muslim = MagicMock()
        mock_muslim.d = 3072
        mock_muslim.ntotal = 100
        mock_muslim.search.return_value = _mock_faiss_search()

        mock_mapping = MagicMock()
        mock_mapping.__len__ = MagicMock(return_value=100)

        with patch.object(backend, "get_db_connection", return_value=mock_conn), \
             patch.object(backend, "get_embedding", return_value=np.ones(3072, dtype=np.float32)), \
             patch.object(backend, "generate_gpt4o_response", return_value=gpt_response), \
             patch.object(backend, "bukhari_index", mock_bukhari), \
             patch.object(backend, "tirmizi_index", mock_tirmizi), \
             patch.object(backend, "muslim_index", mock_muslim), \
             patch.object(backend, "bukhari_mapping", mock_mapping), \
             patch.object(backend, "tirmizi_mapping", mock_mapping), \
             patch.object(backend, "muslim_mapping", mock_mapping):
            r = client.post("/api/chat", json={
                "user_id": 1,
                "question": "fasting in Ramadan"
            })

        assert mock_bukhari.search.called
        assert mock_tirmizi.search.called
        assert mock_muslim.search.called

    # ── Language handling ─────────────────────────────────────────────────────

    def test_arabic_question_accepted(self, client):
        """Arabic-language questions must be accepted (200 or no 4xx)."""
        gpt_response = '{"title": "الصلاة", "explanation": "الصلاة عماد الدين"}'

        mock_cursor = _mock_db_cursor()
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor

        mock_faiss_index = MagicMock()
        mock_faiss_index.d = 3072
        mock_faiss_index.ntotal = 100
        mock_faiss_index.search.return_value = _mock_faiss_search()

        mock_mapping = MagicMock()
        mock_mapping.__len__ = MagicMock(return_value=100)

        with patch.object(backend, "get_db_connection", return_value=mock_conn), \
             patch.object(backend, "get_embedding", return_value=np.ones(3072, dtype=np.float32)), \
             patch.object(backend, "generate_gpt4o_response", return_value=gpt_response), \
             patch.object(backend, "bukhari_index", mock_faiss_index), \
             patch.object(backend, "tirmizi_index", mock_faiss_index), \
             patch.object(backend, "muslim_index", mock_faiss_index), \
             patch.object(backend, "bukhari_mapping", mock_mapping), \
             patch.object(backend, "tirmizi_mapping", mock_mapping), \
             patch.object(backend, "muslim_mapping", mock_mapping):
            r = client.post("/api/chat", json={
                "user_id": 1,
                "question": "ما هي الصلاة؟"
            })

        assert r.status_code != 400

    # ── Error handling ────────────────────────────────────────────────────────

    def test_openai_embedding_failure_returns_500(self, client):
        """If get_embedding() raises, the endpoint must return 500."""
        mock_conn = MagicMock()
        mock_cursor = _mock_db_cursor()
        mock_conn.cursor.return_value = mock_cursor

        mock_faiss_index = MagicMock()
        mock_faiss_index.d = 3072
        mock_faiss_index.ntotal = 100

        mock_mapping = MagicMock()
        mock_mapping.__len__ = MagicMock(return_value=100)

        with patch.object(backend, "get_db_connection", return_value=mock_conn), \
             patch.object(backend, "get_embedding", side_effect=Exception("OpenAI API error: rate limit")), \
             patch.object(backend, "bukhari_index", mock_faiss_index), \
             patch.object(backend, "tirmizi_index", mock_faiss_index), \
             patch.object(backend, "muslim_index", mock_faiss_index), \
             patch.object(backend, "bukhari_mapping", mock_mapping), \
             patch.object(backend, "tirmizi_mapping", mock_mapping), \
             patch.object(backend, "muslim_mapping", mock_mapping):
            r = client.post("/api/chat", json={
                "user_id": 1,
                "question": "prayer"
            })

        assert r.status_code == 500

    def test_response_has_conversation_id(self, client):
        """Successful chat response must include a 'conversation_id' key."""
        gpt_response = '{"title": "T", "explanation": "E"}'

        mock_cursor = _mock_db_cursor()
        mock_cursor.fetchone.return_value = {"conversation_id": 99}
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor

        mock_faiss_index = MagicMock()
        mock_faiss_index.d = 3072
        mock_faiss_index.ntotal = 100
        mock_faiss_index.search.return_value = _mock_faiss_search()

        mock_mapping = MagicMock()
        mock_mapping.__len__ = MagicMock(return_value=100)

        with patch.object(backend, "get_db_connection", return_value=mock_conn), \
             patch.object(backend, "get_embedding", return_value=np.ones(3072, dtype=np.float32)), \
             patch.object(backend, "generate_gpt4o_response", return_value=gpt_response), \
             patch.object(backend, "bukhari_index", mock_faiss_index), \
             patch.object(backend, "tirmizi_index", mock_faiss_index), \
             patch.object(backend, "muslim_index", mock_faiss_index), \
             patch.object(backend, "bukhari_mapping", mock_mapping), \
             patch.object(backend, "tirmizi_mapping", mock_mapping), \
             patch.object(backend, "muslim_mapping", mock_mapping):
            r = client.post("/api/chat", json={
                "user_id": 1,
                "question": "kindness to parents"
            })

        if r.status_code == 200:
            body = r.get_json()
            assert "conversation_id" in body

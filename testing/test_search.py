"""Unit tests: FAISS index loading and vector correctness."""
import os
import sys
import numpy as np
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import faiss

# Paths relative to repo root (tests are run from there)
FAISS_DIR = os.path.join('data', 'faiss')

BUKHARI_PATH = os.path.join(FAISS_DIR, 'bukhari_faiss.index')
TIRMIZI_PATH = os.path.join(FAISS_DIR, 'tirmizi_faiss.index')
MUSLIM_PATH  = os.path.join(FAISS_DIR, 'Sahih_Muslim_faiss.index')

EXPECTED_DIMENSION   = 3072
EXPECTED_METRIC      = faiss.METRIC_L2               # metric_type == 1 (IndexFlatL2)

EXPECTED_COUNTS = {
    'Bukhari': 7634,
    'Tirmizi': 3966,
    'Muslim':  7592,
}


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(scope='module')
def bukhari_index():
    return faiss.read_index(BUKHARI_PATH)

@pytest.fixture(scope='module')
def tirmizi_index():
    return faiss.read_index(TIRMIZI_PATH)

@pytest.fixture(scope='module')
def muslim_index():
    return faiss.read_index(MUSLIM_PATH)


# ── File existence ─────────────────────────────────────────────────────────────

def test_bukhari_index_file_exists():
    assert os.path.exists(BUKHARI_PATH), f"Missing: {BUKHARI_PATH}"

def test_tirmizi_index_file_exists():
    assert os.path.exists(TIRMIZI_PATH), f"Missing: {TIRMIZI_PATH}"

def test_muslim_index_file_exists():
    assert os.path.exists(MUSLIM_PATH), f"Missing: {MUSLIM_PATH}"


# ── Loading ────────────────────────────────────────────────────────────────────

def test_bukhari_index_loads(bukhari_index):
    assert bukhari_index is not None

def test_tirmizi_index_loads(tirmizi_index):
    assert tirmizi_index is not None

def test_muslim_index_loads(muslim_index):
    assert muslim_index is not None


# ── Dimension ─────────────────────────────────────────────────────────────────

def test_bukhari_index_dimension(bukhari_index):
    assert bukhari_index.d == EXPECTED_DIMENSION, \
        f"Bukhari dimension: expected {EXPECTED_DIMENSION}, got {bukhari_index.d}"

def test_tirmizi_index_dimension(tirmizi_index):
    assert tirmizi_index.d == EXPECTED_DIMENSION, \
        f"Tirmizi dimension: expected {EXPECTED_DIMENSION}, got {tirmizi_index.d}"

def test_muslim_index_dimension(muslim_index):
    assert muslim_index.d == EXPECTED_DIMENSION, \
        f"Muslim dimension: expected {EXPECTED_DIMENSION}, got {muslim_index.d}"


# ── Vector count ──────────────────────────────────────────────────────────────

def test_bukhari_vector_count(bukhari_index):
    expected = EXPECTED_COUNTS['Bukhari']
    assert bukhari_index.ntotal == expected, \
        f"Bukhari ntotal: expected {expected}, got {bukhari_index.ntotal}"

def test_tirmizi_vector_count(tirmizi_index):
    expected = EXPECTED_COUNTS['Tirmizi']
    assert tirmizi_index.ntotal == expected, \
        f"Tirmizi ntotal: expected {expected}, got {tirmizi_index.ntotal}"

def test_muslim_vector_count(muslim_index):
    expected = EXPECTED_COUNTS['Muslim']
    assert muslim_index.ntotal == expected, \
        f"Muslim ntotal: expected {expected}, got {muslim_index.ntotal}"


# ── Metric type ───────────────────────────────────────────────────────────────

def test_bukhari_metric_is_l2(bukhari_index):
    assert bukhari_index.metric_type == EXPECTED_METRIC, \
        f"Bukhari metric: expected L2 ({EXPECTED_METRIC}), got {bukhari_index.metric_type}"

def test_tirmizi_metric_is_l2(tirmizi_index):
    assert tirmizi_index.metric_type == EXPECTED_METRIC, \
        f"Tirmizi metric: expected L2 ({EXPECTED_METRIC}), got {tirmizi_index.metric_type}"

def test_muslim_metric_is_l2(muslim_index):
    assert muslim_index.metric_type == EXPECTED_METRIC, \
        f"Muslim metric: expected L2 ({EXPECTED_METRIC}), got {muslim_index.metric_type}"


# ── Search sanity ─────────────────────────────────────────────────────────────

def _random_query():
    """Normalized random vector matching the index dimension."""
    vec = np.random.rand(1, EXPECTED_DIMENSION).astype('float32')
    faiss.normalize_L2(vec)
    return vec

def test_bukhari_search_returns_results(bukhari_index):
    distances, indices = bukhari_index.search(_random_query(), k=5)
    assert distances.shape == (1, 5)
    assert indices.shape == (1, 5)
    assert np.all(indices[0] >= 0), "Search returned invalid (-1) indices"

def test_tirmizi_search_returns_results(tirmizi_index):
    distances, indices = tirmizi_index.search(_random_query(), k=5)
    assert distances.shape == (1, 5)
    assert indices.shape == (1, 5)
    assert np.all(indices[0] >= 0), "Search returned invalid (-1) indices"

def test_muslim_search_returns_results(muslim_index):
    distances, indices = muslim_index.search(_random_query(), k=5)
    assert distances.shape == (1, 5)
    assert indices.shape == (1, 5)
    assert np.all(indices[0] >= 0), "Search returned invalid (-1) indices"

def test_bukhari_search_scores_are_non_negative(bukhari_index):
    """L2 distances must always be >= 0."""
    distances, _ = bukhari_index.search(_random_query(), k=10)
    assert np.all(distances >= 0), f"Negative L2 distances found: {distances}"

def test_search_top_result_has_lowest_distance(bukhari_index):
    """L2 results must be returned in ascending distance order (closest first)."""
    distances, _ = bukhari_index.search(_random_query(), k=10)
    scores = distances[0].tolist()
    assert scores == sorted(scores), \
        "Top-k results are not in ascending distance order"

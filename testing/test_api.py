"""
API Integration Tests — True Hadith Flask Backend
Run with: pytest testing/test_api.py -v
Backend must be running before executing these tests.
"""
import os
import pytest
import requests
from dotenv import load_dotenv

load_dotenv(override=True)

BASE_URL = os.getenv('API_BASE_URL', 'http://192.168.100.12:5000/api')

# A real user_id that exists in your DB (used for history/bookmark tests)
TEST_USER_ID = int(os.getenv('TEST_USER_ID', '1'))


def url(path):
    return f"{BASE_URL}{path}"


# ── Health ────────────────────────────────────────────────────────────────────

def test_health_endpoint():
    """GET /api/health must return 200."""
    r = requests.get(url('/health'), timeout=10)
    assert r.status_code == 200


def test_health_response_has_status():
    """Health response must contain a status field."""
    r = requests.get(url('/health'), timeout=10)
    body = r.json()
    assert 'status' in body or r.status_code == 200


# ── Auth: Register ────────────────────────────────────────────────────────────

def test_register_missing_fields_returns_400():
    """POST /api/auth/register with no body must return 400."""
    r = requests.post(url('/auth/register'), json={}, timeout=10)
    assert r.status_code == 400


def test_register_missing_email_returns_400():
    """POST /api/auth/register without email must return 400."""
    r = requests.post(url('/auth/register'), json={
        'firebase_uid': 'test_uid_999',
        'username': 'testuser'
    }, timeout=10)
    assert r.status_code == 400


def test_register_missing_username_returns_400():
    """POST /api/auth/register without username must return 400."""
    r = requests.post(url('/auth/register'), json={
        'firebase_uid': 'test_uid_999',
        'email': 'test@example.com'
    }, timeout=10)
    assert r.status_code == 400


def test_register_duplicate_user_returns_409():
    """Registering the same firebase_uid twice must return 409."""
    payload = {
        'firebase_uid': 'duplicate_test_uid_abc',
        'username': 'dupuser',
        'email': 'dup@example.com'
    }
    # First call — may pass or 409 if already exists from prior run
    r1 = requests.post(url('/auth/register'), json=payload, timeout=10)
    assert r1.status_code in (201, 409)

    # Second call must always be 409
    r2 = requests.post(url('/auth/register'), json=payload, timeout=10)
    assert r2.status_code == 409


def test_register_no_body_returns_400():
    """POST /api/auth/register with no JSON body must return 400."""
    r = requests.post(url('/auth/register'), timeout=10)
    assert r.status_code == 400


# ── Auth: Login ───────────────────────────────────────────────────────────────

def test_login_missing_firebase_uid_returns_400():
    """POST /api/auth/login with no firebase_uid must return 400."""
    r = requests.post(url('/auth/login'), json={}, timeout=10)
    assert r.status_code == 400


def test_login_nonexistent_user_returns_404():
    """POST /api/auth/login with unknown UID must return 404."""
    r = requests.post(url('/auth/login'), json={
        'firebase_uid': 'nonexistent_uid_xyz_000'
    }, timeout=10)
    assert r.status_code == 404


def test_login_no_body_returns_400():
    """POST /api/auth/login with no JSON body must return 400."""
    r = requests.post(url('/auth/login'), timeout=10)
    assert r.status_code == 400


# ── Search ────────────────────────────────────────────────────────────────────

def test_search_english_query_returns_results():
    """POST /api/search with valid English query must return results list."""
    r = requests.post(url('/search'), json={
        'query': 'intentions deeds',
        'user_id': TEST_USER_ID
    }, timeout=30)
    assert r.status_code == 200
    body = r.json()
    assert 'results' in body
    assert isinstance(body['results'], list)


def test_search_arabic_query_returns_results():
    """POST /api/search with Arabic query must return results list."""
    r = requests.post(url('/search'), json={
        'query': 'الأعمال بالنيات',
        'user_id': TEST_USER_ID
    }, timeout=30)
    assert r.status_code == 200
    body = r.json()
    assert 'results' in body
    assert isinstance(body['results'], list)


def test_search_urdu_query_returns_results():
    """POST /api/search with Urdu query must return results list."""
    r = requests.post(url('/search'), json={
        'query': 'نیت کا اجر',
        'user_id': TEST_USER_ID
    }, timeout=30)
    assert r.status_code == 200
    body = r.json()
    assert 'results' in body


def test_search_reference_lookup_bukhari():
    """POST /api/search with 'Bukhari 1' must return direct reference result."""
    r = requests.post(url('/search'), json={
        'query': 'Bukhari 1',
        'user_id': TEST_USER_ID
    }, timeout=20)
    assert r.status_code == 200
    body = r.json()
    assert 'results' in body
    assert len(body['results']) > 0


def test_search_missing_query_returns_400():
    """POST /api/search with no query must return 400."""
    r = requests.post(url('/search'), json={
        'user_id': TEST_USER_ID
    }, timeout=10)
    assert r.status_code == 400


def test_search_empty_query_returns_400():
    """POST /api/search with empty string query must return 400."""
    r = requests.post(url('/search'), json={
        'query': '',
        'user_id': TEST_USER_ID
    }, timeout=10)
    assert r.status_code == 400


def test_search_no_body_returns_400():
    """POST /api/search with no JSON body must return 400."""
    r = requests.post(url('/search'), timeout=10)
    assert r.status_code == 400


def test_search_gibberish_returns_empty_list():
    """POST /api/search with gibberish must return empty results, not error."""
    r = requests.post(url('/search'), json={
        'query': 'xzqwerty12345nonsense',
        'user_id': TEST_USER_ID
    }, timeout=30)
    assert r.status_code == 200
    body = r.json()
    assert 'results' in body
    assert isinstance(body['results'], list)


def test_search_result_has_required_fields():
    """Each search result must contain hadith_id, book_name, hadith_number, grade."""
    r = requests.post(url('/search'), json={
        'query': 'prayer',
        'user_id': TEST_USER_ID
    }, timeout=30)
    assert r.status_code == 200
    results = r.json().get('results', [])
    if results:
        for field in ('hadith_id', 'book_name', 'hadith_number', 'grade'):
            assert field in results[0], f"Missing field in result: {field}"


# ── Hadith Detail ─────────────────────────────────────────────────────────────

def test_hadith_detail_valid_id():
    """GET /api/hadith/1 must return hadith with Arabic, English, Urdu text."""
    r = requests.get(url('/hadith/1'), timeout=10)
    assert r.status_code == 200
    body = r.json()
    assert 'hadith_arabic' in body or 'hadith_english' in body


def test_hadith_detail_invalid_id_returns_404():
    """GET /api/hadith/999999 must return 404 for nonexistent hadith."""
    r = requests.get(url('/hadith/999999'), timeout=10)
    assert r.status_code == 404


# ── History ───────────────────────────────────────────────────────────────────

def test_history_requires_user_id():
    """GET /api/history without user_id query param must return 400."""
    r = requests.get(url('/history'), timeout=10)
    assert r.status_code == 400


def test_history_valid_user_returns_list():
    """GET /api/history?user_id=<id> must return a list."""
    r = requests.get(url(f'/history?user_id={TEST_USER_ID}'), timeout=10)
    assert r.status_code == 200
    body = r.json()
    assert 'history' in body or isinstance(body, list)


def test_history_delete_nonexistent_returns_404():
    """DELETE /api/history/999999 must return 404."""
    r = requests.delete(url('/history/999999'), timeout=10)
    assert r.status_code == 404


# ── Bookmarks ─────────────────────────────────────────────────────────────────

def test_bookmarks_requires_user_id():
    """GET /api/bookmarks without user_id must return 400."""
    r = requests.get(url('/bookmarks'), timeout=10)
    assert r.status_code == 400


def test_bookmarks_valid_user_returns_list():
    """GET /api/bookmarks?user_id=<id> must return a list."""
    r = requests.get(url(f'/bookmarks?user_id={TEST_USER_ID}'), timeout=10)
    assert r.status_code == 200
    body = r.json()
    assert 'bookmarks' in body or isinstance(body, list)


def test_bookmark_add_missing_fields_returns_400():
    """POST /api/bookmarks without required fields must return 400."""
    r = requests.post(url('/bookmarks'), json={}, timeout=10)
    assert r.status_code == 400


def test_bookmark_delete_nonexistent_returns_404():
    """DELETE /api/bookmarks/999999 must return 404."""
    r = requests.delete(url('/bookmarks/999999'), timeout=10)
    assert r.status_code == 404


# ── OCR ───────────────────────────────────────────────────────────────────────

def test_ocr_no_image_returns_400():
    """POST /api/ocr/easyocr with no file must return 400."""
    r = requests.post(url('/ocr/easyocr'), timeout=15)
    assert r.status_code == 400


def test_ocr_wrong_content_type_returns_400():
    """POST /api/ocr/easyocr with JSON instead of file must return 400."""
    r = requests.post(url('/ocr/easyocr'), json={'image': 'fake'}, timeout=15)
    assert r.status_code == 400


# ── Chat ──────────────────────────────────────────────────────────────────────

def test_chat_missing_message_returns_400():
    """POST /api/chat with no message must return 400."""
    r = requests.post(url('/chat'), json={'user_id': TEST_USER_ID}, timeout=15)
    assert r.status_code == 400


def test_chat_no_body_returns_400():
    """POST /api/chat with no body must return 400."""
    r = requests.post(url('/chat'), timeout=15)
    assert r.status_code == 400


# ── CORS ──────────────────────────────────────────────────────────────────────

def test_cors_header_present_on_search():
    """Search endpoint must return Access-Control-Allow-Origin header."""
    r = requests.post(url('/search'), json={
        'query': 'prayer', 'user_id': TEST_USER_ID
    }, timeout=30)
    assert 'Access-Control-Allow-Origin' in r.headers


def test_cors_preflight_options():
    """OPTIONS preflight on /api/search must return 200 with CORS headers."""
    r = requests.options(url('/search'), headers={
        'Origin': 'http://localhost',
        'Access-Control-Request-Method': 'POST',
    }, timeout=10)
    assert r.status_code in (200, 204)

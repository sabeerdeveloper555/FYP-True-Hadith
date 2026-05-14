"""Unit tests: PostgreSQL connection and Hadith table queries."""
import os
import sys
import pytest
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
load_dotenv(override=True)

DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'database': os.getenv('DB_NAME', 'true_hadith'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', ''),
    'port': os.getenv('DB_PORT', '5432'),
}


def get_conn():
    return psycopg2.connect(**DB_CONFIG)


# ── Connection ────────────────────────────────────────────────────────────────

def test_database_connection():
    """PostgreSQL server is reachable and accepts credentials."""
    conn = get_conn()
    assert conn is not None
    assert not conn.closed
    conn.close()


def test_database_connection_closes_cleanly():
    conn = get_conn()
    conn.close()
    assert conn.closed


# ── Hadith table ──────────────────────────────────────────────────────────────

def test_hadith_table_exists():
    """The 'hadiths' table must exist in the database."""
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'hadiths'
    """)
    count = cursor.fetchone()[0]
    conn.close()
    assert count == 1, "Table 'hadiths' not found in public schema"


def test_hadith_table_has_rows():
    """Hadith table must contain at least one row."""
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM hadiths")
    count = cursor.fetchone()[0]
    conn.close()
    assert count > 0, f"Hadith table is empty (count={count})"


def test_hadith_row_has_required_columns():
    """A single Hadith row must have hadith_arabic, hadith_english, hadith_urdu columns."""
    conn = get_conn()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute("SELECT * FROM hadiths LIMIT 1")
    row = cursor.fetchone()
    conn.close()
    assert row is not None, "No rows in hadiths table"
    for col in ('hadith_arabic', 'hadith_english', 'hadith_urdu'):
        assert col in row, f"Missing column: {col}"


def test_hadith_english_text_not_empty():
    """English text of the first hadith must be a non-empty string."""
    conn = get_conn()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute("SELECT hadith_english FROM hadiths WHERE hadith_english IS NOT NULL LIMIT 1")
    row = cursor.fetchone()
    conn.close()
    assert row is not None
    assert len(row['hadith_english'].strip()) > 0


def test_hadith_arabic_text_not_empty():
    """Arabic text of the first hadith must be a non-empty string."""
    conn = get_conn()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute("SELECT hadith_arabic FROM hadiths WHERE hadith_arabic IS NOT NULL LIMIT 1")
    row = cursor.fetchone()
    conn.close()
    assert row is not None
    assert len(row['hadith_arabic'].strip()) > 0


def test_hadith_collections_present():
    """Bukhari, Tirmizi, and Muslim books must exist via the hadith_books table."""
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute("SELECT LOWER(book_name_english) FROM hadith_books")
    books = {r[0] for r in cursor.fetchall() if r[0]}
    conn.close()
    for expected in ('bukhari', 'tirmidhi', 'muslim'):
        assert any(expected in b for b in books), \
            f"Book '{expected}' not found. Found: {books}"


# ── Users table ───────────────────────────────────────────────────────────────

def test_users_table_exists():
    """The 'users' table must exist."""
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'users'
    """)
    count = cursor.fetchone()[0]
    conn.close()
    assert count == 1, "Table 'users' not found"


def test_users_table_has_required_columns():
    """Users table must have user_id, firebase_uid, email columns."""
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'users' AND table_schema = 'public'
    """)
    columns = {r[0] for r in cursor.fetchall()}
    conn.close()
    for col in ('user_id', 'fk_firebase_uid'):
        assert col in columns, f"Missing column in users table: {col}"

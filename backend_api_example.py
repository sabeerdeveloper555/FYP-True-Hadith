from flask import Flask, request, jsonify, Response, stream_with_context
import json as _json
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
import os
import sys
import ssl
from dotenv import load_dotenv

# Fix SSL certificate verification on Windows (self-signed cert in chain)
ssl._create_default_https_context = ssl._create_unverified_context
import faiss
import pandas as pd
import numpy as np
from openai import OpenAI
import re
import base64
from PIL import Image, ImageEnhance
import io
import requests
import threading
import time

# Try to import rapidfuzz for fuzzy matching
try:
    from rapidfuzz import fuzz, process
    RAPIDFUZZ_AVAILABLE = True
except ImportError:
    RAPIDFUZZ_AVAILABLE = False
    print("Warning: rapidfuzz not installed. Fuzzy search will be limited. Install with: pip install rapidfuzz")

# Try to import rank_bm25 for keyword-based search
try:
    from rank_bm25 import BM25Okapi
    BM25_AVAILABLE = True
except ImportError:
    BM25_AVAILABLE = False
    print("Warning: rank_bm25 not installed. BM25 hybrid search disabled. Install with: pip install rank-bm25")

try:
    import firebase_admin
    from firebase_admin import credentials, messaging as fcm_messaging
    FIREBASE_ADMIN_AVAILABLE = True
except ImportError:
    FIREBASE_ADMIN_AVAILABLE = False
    print("Warning: firebase-admin not installed. Push notifications disabled. Install with: pip install firebase-admin")

# Fix Unicode encoding for Windows console
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')
try:
    import easyocr
    EASYOCR_AVAILABLE = True
except (ImportError, OSError) as e:
    EASYOCR_AVAILABLE = False
    print(f"Warning: easyocr not available due to: {e}. EasyOCR endpoint will not work.")

load_dotenv(override=True)

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50 MB for audio uploads

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'DB_HOST'),
    'database': os.getenv('DB_NAME', 'DB_NAME'),
    'user': os.getenv('DB_USER', 'DB_USER'),
    'password': os.getenv('DB_PASSWORD', 'DB_PASSWORD'),
    'port': os.getenv('DB_PORT', 'DB_PORT')
}

# FAISS and Mapping File Paths
BUKHARI_FAISS_PATH = os.path.join('data', 'faiss', 'bukhari_faiss.index')
TIRMIZI_FAISS_PATH = os.path.join('data', 'faiss', 'tirmizi_faiss.index')
MUSLIM_FAISS_PATH = os.path.join('data', 'faiss', 'Sahih_Muslim_faiss.index')
BUKHARI_MAPPING_PATH = os.path.join('data', 'mapping', 'bukhari_mapping.csv')
TIRMIZI_MAPPING_PATH = os.path.join('data', 'mapping', 'tirmizi_mapping.csv')
MUSLIM_MAPPING_PATH = os.path.join('data', 'mapping', 'Sahih_Muslim_mapping.csv')

# Global variables to store loaded FAISS indexes and mappings
bukhari_index = None
tirmizi_index = None
muslim_index = None
bukhari_mapping = None
tirmizi_mapping = None
muslim_mapping = None

# BM25 index globals (built from DB at startup)
bm25_index = None          # BM25Okapi instance
bm25_hadith_ids = []       # ordered list of hadith_ids matching bm25_index rows

# OpenAI Client - initialized lazily to avoid version conflicts
_openai_client = None

def get_openai_client():
    """Get or create OpenAI client instance"""
    global _openai_client
    if _openai_client is None:
        api_key = os.getenv('OPENAI_API_KEY', '')
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable is not set")
        _openai_client = OpenAI(api_key=api_key)
    return _openai_client


_firebase_app = None

def get_firebase_app():
    """Initialize Firebase Admin SDK once and reuse the app instance."""
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    if not FIREBASE_ADMIN_AVAILABLE:
        return None

    sa_path = os.getenv('FIREBASE_SERVICE_ACCOUNT_PATH', '')
    if not sa_path or not os.path.exists(sa_path):
        print(f"⚠ Firebase Admin: service account file not found at '{sa_path}'")
        print("  Download it from Firebase Console → Project Settings → Service Accounts")
        return None

    try:
        cred = credentials.Certificate(sa_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        print("✓ Firebase Admin SDK initialized")
        return _firebase_app
    except Exception as e:
        print(f"✗ Firebase Admin SDK init failed: {e}")
        return None


def send_push_notification(fcm_token, title, body, data=None):
    """
    Send a push notification to a single device.
    Returns True on success, False on failure.
    Runs synchronously — call from a background thread if inside a request handler.
    """
    if not get_firebase_app():
        return False

    try:
        message = fcm_messaging.Message(
            notification=fcm_messaging.Notification(title=title, body=body),
            # data values must all be strings
            data={str(k): str(v) for k, v in (data or {}).items()},
            token=fcm_token,
            android=fcm_messaging.AndroidConfig(
                priority='high',
                notification=fcm_messaging.AndroidNotification(
                    channel_id='true_hadith_main',
                    sound='default',
                ),
            ),
            apns=fcm_messaging.APNSConfig(
                payload=fcm_messaging.APNSPayload(
                    aps=fcm_messaging.Aps(sound='default', badge=1)
                )
            ),
        )
        response = fcm_messaging.send(message)
        print(f"✓ Push notification sent: {response}")
        return True
    except fcm_messaging.UnregisteredError:
        # Token is stale — clear it so we don't keep sending to dead tokens
        print(f"⚠ FCM token unregistered, clearing from DB: {fcm_token[:20]}...")
        _clear_stale_fcm_token(fcm_token)
        return False
    except Exception as e:
        print(f"✗ Push notification failed: {e}")
        return False


def _clear_stale_fcm_token(token):
    """Remove an expired FCM token from the database."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE users SET fcm_token = NULL WHERE fcm_token = %s", (token,))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"✗ Could not clear stale FCM token: {e}")
        if conn:
            conn.close()


def send_notification_to_user(user_id, title, body, data=None):
    """
    Look up a user's stored FCM token and send them a push notification.
    Safe to call from a background thread.
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute("SELECT fcm_token FROM users WHERE user_id = %s", (user_id,))
        row = cursor.fetchone()
        cursor.close()
        conn.close()

        if not row or not row.get('fcm_token'):
            print(f"⚠ No FCM token for user_id={user_id}, skipping notification")
            return False

        return send_push_notification(row['fcm_token'], title, body, data)
    except Exception as e:
        print(f"✗ send_notification_to_user error: {e}")
        if conn:
            conn.close()
        return False


def load_faiss_indexes():
    """Load FAISS indexes at startup"""
    global bukhari_index, tirmizi_index, muslim_index

    try:
        if os.path.exists(BUKHARI_FAISS_PATH):
            bukhari_index = faiss.read_index(BUKHARI_FAISS_PATH)
            print(f"✓ Loaded Bukhari FAISS index: {BUKHARI_FAISS_PATH}")
            print(f"  - Dimension: {bukhari_index.d}, Total vectors: {bukhari_index.ntotal}")
        else:
            print(f"⚠ Warning: Bukhari FAISS index not found at {BUKHARI_FAISS_PATH}")

        if os.path.exists(TIRMIZI_FAISS_PATH):
            tirmizi_index = faiss.read_index(TIRMIZI_FAISS_PATH)
            print(f"✓ Loaded Tirmizi FAISS index: {TIRMIZI_FAISS_PATH}")
            print(f"  - Dimension: {tirmizi_index.d}, Total vectors: {tirmizi_index.ntotal}")
        else:
            print(f"⚠ Warning: Tirmizi FAISS index not found at {TIRMIZI_FAISS_PATH}")

        if os.path.exists(MUSLIM_FAISS_PATH):
            muslim_index = faiss.read_index(MUSLIM_FAISS_PATH)
            print(f"✓ Loaded Sahih Muslim FAISS index: {MUSLIM_FAISS_PATH}")
            print(f"  - Dimension: {muslim_index.d}, Total vectors: {muslim_index.ntotal}")
        else:
            print(f"⚠ Warning: Sahih Muslim FAISS index not found at {MUSLIM_FAISS_PATH}")
    except Exception as e:
        print(f"✗ Error loading FAISS indexes: {e}")


def load_mapping_csvs():
    """Load mapping CSV files at startup"""
    global bukhari_mapping, tirmizi_mapping, muslim_mapping

    try:
        if os.path.exists(BUKHARI_MAPPING_PATH):
            bukhari_mapping = pd.read_csv(BUKHARI_MAPPING_PATH)
            print(f"✓ Loaded Bukhari mapping CSV: {BUKHARI_MAPPING_PATH}")
        else:
            print(f"⚠ Warning: Bukhari mapping CSV not found at {BUKHARI_MAPPING_PATH}")

        if os.path.exists(TIRMIZI_MAPPING_PATH):
            tirmizi_mapping = pd.read_csv(TIRMIZI_MAPPING_PATH)
            print(f"✓ Loaded Tirmizi mapping CSV: {TIRMIZI_MAPPING_PATH}")
        else:
            print(f"⚠ Warning: Tirmizi mapping CSV not found at {TIRMIZI_MAPPING_PATH}")

        if os.path.exists(MUSLIM_MAPPING_PATH):
            muslim_mapping = pd.read_csv(MUSLIM_MAPPING_PATH)
            print(f"✓ Loaded Sahih Muslim mapping CSV: {MUSLIM_MAPPING_PATH}")
        else:
            print(f"⚠ Warning: Sahih Muslim mapping CSV not found at {MUSLIM_MAPPING_PATH}")
    except Exception as e:
        print(f"✗ Error loading mapping CSVs: {e}")


def build_bm25_index():
    """Build a BM25 index over all hadith English text at startup for hybrid search."""
    global bm25_index, bm25_hadith_ids
    if not BM25_AVAILABLE:
        print("⚠ BM25 not available — skipping index build")
        return
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT hadith_id, hadith_english FROM hadiths ORDER BY hadith_id")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()

        bm25_hadith_ids = [row[0] for row in rows]
        tokenized = [str(row[1] or '').lower().split() for row in rows]
        bm25_index = BM25Okapi(tokenized)
        print(f"✓ BM25 index built: {len(bm25_hadith_ids)} hadiths indexed")
    except Exception as e:
        print(f"✗ Error building BM25 index: {e}")


def get_db_connection():
    """Create and return a database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        raise


@app.route('/api/auth/register', methods=['POST'])
def register_user():
    """
    Register a new user after Firebase authentication

    Expected JSON body:
    {
        "firebase_uid": "string",
        "username": "string",
        "email": "string"
    }

    Returns:
    {
        "user_id": int,
        "username": "string",
        "created_at": "ISO datetime string"
    }
    """
    conn = None
    cursor = None
    try:
        data = request.get_json()

        if not data:
            return jsonify({'message': 'No data provided'}), 400

        firebase_uid = data.get('firebase_uid')
        username = data.get('username')
        email = data.get('email')

        if not all([firebase_uid, username, email]):
            return jsonify({'message': 'Missing required fields'}), 400

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Check if user already exists
        cursor.execute(
            "SELECT user_id FROM users WHERE FK_firebase_uid = %s",
            (firebase_uid,)
        )
        existing_user = cursor.fetchone()

        if existing_user:
            cursor.close()
            conn.close()
            return jsonify({'message': 'User already exists'}), 409

        # Get profile_photo_url if provided
        profile_photo_url = data.get('profile_photo_url')

        # Insert new user
        cursor.execute(
            """
            INSERT INTO users (FK_firebase_uid, user_name, name_email, profile_photo_url, created_at)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING user_id, user_name, profile_photo_url, created_at
            """,
            (firebase_uid, username, email, profile_photo_url, datetime.now())
        )

        user = cursor.fetchone()
        conn.commit()

        cursor.close()
        conn.close()

        return jsonify({
            'user_id': user['user_id'],
            'username': user['user_name'],
            'profile_photo_url': user.get('profile_photo_url'),
            'created_at': user['created_at'].isoformat(),
        }), 201

    except Exception as e:
        if conn:
            conn.rollback()
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        return jsonify({'message': f'Registration failed: {str(e)}'}), 500


@app.route('/api/auth/login', methods=['POST'])
def login_user():
    """
    Login user and return user data

    Expected JSON body:
    {
        "firebase_uid": "string"
    }

    Returns:
    {
        "user_id": int,
        "username": "string",
        "created_at": "ISO datetime string"
    }
    """
    conn = None
    cursor = None
    try:
        data = request.get_json()

        if not data:
            return jsonify({'message': 'No data provided'}), 400

        firebase_uid = data.get('firebase_uid')

        if not firebase_uid:
            return jsonify({'message': 'Missing firebase_uid'}), 400

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Find user by firebase_uid
        cursor.execute(
            """
            SELECT user_id, user_name, profile_photo_url, created_at
            FROM users
            WHERE FK_firebase_uid = %s
            """,
            (firebase_uid,)
        )

        user = cursor.fetchone()

        cursor.close()
        conn.close()

        if not user:
            return jsonify({'message': 'User not found'}), 404

        return jsonify({
            'user_id': user['user_id'],
            'username': user['user_name'],
            'profile_photo_url': user.get('profile_photo_url'),
            'created_at': user['created_at'].isoformat(),
        }), 200

    except Exception as e:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        return jsonify({'message': f'Login failed: {str(e)}'}), 500


def normalize_arabic_text(text):
    """
    Normalize Arabic text: remove tashkeel, normalize alif/ya
    Enhanced for fuzzy matching - handles missing punctuation and diacritics
    """
    if not text:
        return text
    
    # Remove Arabic diacritics (tashkeel) - comprehensive range
    # Includes: Fathah, Dammah, Kasrah, Sukun, Shaddah, Tanwin, etc.
    text = re.sub(r'[\u064B-\u065F\u0670\u0640]', '', text)  # Added \u0640 (tatweel)
    
    # Remove additional Arabic diacritics and marks
    text = re.sub(r'[\u0610-\u061A\u0640\u06D6-\u06ED]', '', text)

    # Normalize Alif variations (إ, أ, آ, ا) -> ا
    text = re.sub(r'[إأآا]', 'ا', text)

    # Normalize Alif Maqsura (ى) -> Ya (ي)
    text = text.replace("ى", "ي")
    
    # Normalize Teh Marbuta (ة) -> Teh (ت) for better matching
    # Note: This is optional, can be commented if you want to preserve ة
    # text = text.replace("ة", "ت")
    
    # Remove zero-width characters that might interfere
    text = re.sub(r'[\u200B-\u200D\uFEFF]', '', text)
    
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text).strip()

    return text


def clean_text(text):
    """
    Remove punctuation from all languages
    Enhanced for fuzzy matching - removes punctuation but preserves text structure
    """
    if not text:
        return text
    
    # Remove all punctuation including Arabic punctuation
    # Arabic punctuation: ، ؟ ؛ « » ؎ ٭ ـ ۔
    punctuation = r'[!"#$%&\'()*+,\-./:;<=>?@[\\\]^_`{|}~،؟؛«»؎٭ـ۔]'
    text = re.sub(punctuation, ' ', text)  # Replace with space instead of removing
    
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text


def fuzzy_search_hadiths(query, limit=20, min_similarity=60):
    """
    Perform fuzzy search on hadiths database using rapidfuzz
    Handles spelling mistakes and missing Arabic punctuation/tashkeel
    
    Args:
        query: Search query string
        limit: Maximum number of results to return
        min_similarity: Minimum similarity score (0-100) to include result
    
    Returns:
        List of tuples: (hadith_id, similarity_score, source_text_field)
    """
    if not RAPIDFUZZ_AVAILABLE:
        print("Warning: rapidfuzz not available, skipping fuzzy search")
        return []
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Normalize query for fuzzy matching
        normalized_query = normalize_arabic_text(query) if any('\u0600' <= c <= '\u06FF' for c in query) else query
        cleaned_query = clean_text(normalized_query)
        
        if not cleaned_query or not cleaned_query.strip():
            cleaned_query = query.strip()
        
        if not cleaned_query:
            cursor.close()
            conn.close()
            return []
        
        # Fetch all hadiths with their text fields
        # We'll search in Arabic, English, and Urdu text
        cursor.execute("""
            SELECT 
                h.hadith_id,
                h.hadith_arabic,
                h.hadith_english,
                h.hadith_urdu,
                b.book_name_english,
                b.book_id
            FROM hadiths h
            JOIN hadith_books b ON h.FK_book_id = b.book_id
            WHERE h.hadith_arabic IS NOT NULL 
               OR h.hadith_english IS NOT NULL 
               OR h.hadith_urdu IS NOT NULL
        """)
        
        all_hadiths = cursor.fetchall()
        cursor.close()
        conn.close()
        
        if not all_hadiths:
            return []
        
        # Prepare text fields for fuzzy matching
        fuzzy_results = []
        
        for hadith in all_hadiths:
            hadith_id = hadith['hadith_id']
            book_name = hadith['book_name_english'] or ''
            # Determine book source (bukhari/tirmizi) from book name
            book_source = 'unknown'
            if 'bukhari' in book_name.lower():
                book_source = 'bukhari'
            elif 'tirmizi' in book_name.lower() or 'tirmidhi' in book_name.lower():
                book_source = 'tirmizi'
            
            max_score = 0
            best_field = None
            
            # Search in Arabic text (normalized)
            if hadith['hadith_arabic']:
                arabic_text = hadith['hadith_arabic']
                normalized_arabic = normalize_arabic_text(arabic_text)
                cleaned_arabic = clean_text(normalized_arabic)
                
                if cleaned_arabic:
                    # partial_ratio is excluded: it inflates scores for any substring
                    # match and floods results with false positives.
                    score1 = fuzz.ratio(cleaned_query.lower(), cleaned_arabic.lower())
                    score2 = fuzz.token_sort_ratio(cleaned_query.lower(), cleaned_arabic.lower())
                    arabic_score = max(score1, score2)
                    if arabic_score > max_score:
                        max_score = arabic_score
                        best_field = 'arabic'

            # Search in English text
            if hadith['hadith_english']:
                english_text = clean_text(hadith['hadith_english'])
                if english_text:
                    score1 = fuzz.ratio(cleaned_query.lower(), english_text.lower())
                    score2 = fuzz.token_sort_ratio(cleaned_query.lower(), english_text.lower())
                    english_score = max(score1, score2)
                    if english_score > max_score:
                        max_score = english_score
                        best_field = 'english'

            # Search in Urdu text
            if hadith['hadith_urdu']:
                urdu_text = clean_text(hadith['hadith_urdu'])
                if urdu_text:
                    score1 = fuzz.ratio(cleaned_query.lower(), urdu_text.lower())
                    score2 = fuzz.token_sort_ratio(cleaned_query.lower(), urdu_text.lower())
                    urdu_score = max(score1, score2)
                    if urdu_score > max_score:
                        max_score = urdu_score
                        best_field = 'urdu'
            
            # Only include if similarity is above threshold
            if max_score >= min_similarity:
                fuzzy_results.append((hadith_id, max_score, best_field, book_source))
        
        # Sort by similarity score (descending) and return top results
        fuzzy_results.sort(key=lambda x: x[1], reverse=True)
        
        # Return list of (hadith_id, similarity_score, field, book_source)
        return fuzzy_results[:limit]
    
    except Exception as e:
        import traceback
        print(f"Fuzzy search error: {str(e)}")
        print(f"Traceback:\n{traceback.format_exc()}")
        return []


def get_embedding(text, dimensions=None):
    """Get OpenAI embedding for text"""
    # Check if text is empty or None
    if not text or not text.strip():
        raise ValueError("Empty text provided to get_embedding")

    try:
        # Get client instance (initialized on first use)
        client = get_openai_client()
        
        # Use provided dimensions, else fallback to loaded index dimension
        target_dim = dimensions
        if target_dim is None:
            if bukhari_index is not None:
                target_dim = bukhari_index.d
            elif tirmizi_index is not None:
                target_dim = tirmizi_index.d
                
        kwargs = {"model": "text-embedding-3-large", "input": text}
        if target_dim is not None and target_dim > 0:
            kwargs["dimensions"] = target_dim

        response = client.embeddings.create(**kwargs)
        embedding = np.array(response.data[0].embedding, dtype=np.float32)
        print(f"Generated embedding dimension: {embedding.shape}")
        return embedding
    except ValueError:
        # Re-raise ValueError (API key not set)
        raise
    except Exception as e:
        error_msg = str(e)
        print(f"Error getting embedding: {error_msg}")
        print(f"Text that failed: {text[:100]}...")  # Print first 100 chars for debugging
        raise Exception(f"OpenAI API error: {error_msg}")


@app.route('/api/search', methods=['POST'])
def search_hadiths():
    """
    Search hadiths using hybrid approach: FAISS semantic similarity + Fuzzy matching
    Handles spelling mistakes and missing Arabic punctuation/tashkeel

    Expected JSON body:
    {
        "user_id": int,
        "query": "string"
    }

    Returns:
    {
        "results": [
            {
                "hadith_id": int,
                "book_name": "string",
                "hadith_number": int,
                "chapter_number": int,
                "grade": "string"
            }
        ]
    }
    """
    try:
        data = request.get_json()

        if not data:
            return jsonify({'message': 'No data provided'}), 400

        user_id = data.get('user_id')
        query = data.get('query')

        if not query:
            return jsonify({'message': 'Missing query'}), 400

        # Normalize and clean query
        normalized_query = normalize_arabic_text(query) if any('\u0600' <= c <= '\u06FF' for c in query) else query
        cleaned_query = clean_text(normalized_query)

        # If cleaned query is empty, use original query
        if not cleaned_query or not cleaned_query.strip():
            cleaned_query = query.strip()

        # Ensure we have a valid query
        if not cleaned_query:
            return jsonify({'message': 'Query cannot be empty'}), 400

        # ===== REFERENCE SEARCH: "Sahih Muslim 2699", "Muslim-2699", "Bukhari 47" =====
        # Detect book-name + hadith-number patterns and short-circuit to a direct DB
        # lookup.  This runs before the expensive FAISS/fuzzy path.
        ref_match = re.search(
            r'(?:sahih\s+)?'
            r'(muslim|bukhari|tirmidhi?|tirmizi)'
            r'[\s\-:#]*'
            r'(\d+)',
            query,
            re.IGNORECASE
        )
        if ref_match:
            book_keyword = ref_match.group(1).lower()
            hadith_num   = ref_match.group(2)

            if 'muslim' in book_keyword:
                book_filter = '%muslim%'
            elif 'bukhari' in book_keyword:
                book_filter = '%bukhari%'
            else:
                book_filter = '%tirmid%'

            ref_conn   = get_db_connection()
            ref_cursor = ref_conn.cursor(cursor_factory=RealDictCursor)
            try:
                ref_cursor.execute("""
                    SELECT
                        h.hadith_id,
                        h.hadith_number,
                        b.book_name_english,
                        c.chapter_number,
                        g.grade_type
                    FROM hadiths h
                    JOIN hadith_books b  ON h.FK_book_id      = b.book_id
                    JOIN chapters    c  ON h.FK_chapter_id    = c.chapter_id
                    LEFT JOIN hadith_grade  g ON h.FK_hadith_grade_id = g.grade_id
                    WHERE b.book_name_english ILIKE %s
                      AND h.hadith_number::text = %s
                    LIMIT 5
                """, (book_filter, hadith_num))
                ref_hadiths = ref_cursor.fetchall()

                if ref_hadiths:
                    if user_id:
                        ref_cursor.execute(
                            "INSERT INTO history (FK_user_id, query_text, created_at)"
                            " VALUES (%s, %s, %s)",
                            (user_id, query, datetime.now())
                        )
                        ref_conn.commit()

                    results = [{
                        'hadith_id':        h['hadith_id'],
                        'book_name':        h['book_name_english'],
                        'hadith_number':    h['hadith_number'],
                        'chapter_number':   h['chapter_number'],
                        'grade':            h['grade_type'] or 'No grade mention',
                        'similarity_score': 1.0,
                    } for h in ref_hadiths]

                    print(f"[Search] Reference match: {book_filter} #{hadith_num} → {len(results)} result(s)")
                    return jsonify({'results': results}), 200

            except Exception as ref_err:
                print(f"[Search] Reference lookup failed: {ref_err}")
            finally:
                ref_cursor.close()
                ref_conn.close()
            # No DB hit — fall through to semantic search

        # ===== HYBRID SEARCH: Semantic + Fuzzy =====
        # Maps hadith_id -> raw FAISS relevance score (lower = more relevant for L2,
        # higher = more relevant for inner product — normalised later)
        faiss_raw_scores = {}   # per-index raw scores before normalisation
        hadith_score_map = {}   # final merged, normalised FAISS score (lower = better)
        semantic_count = 0
        k = 30  # Increased from 20 → richer candidate pool per index

        # Helper: collect scores from one FAISS index into a per-index dict,
        # then min-max normalise and merge into hadith_score_map.
        def _collect_faiss_scores(index, mapping, label):
            nonlocal semantic_count
            if index is None or mapping is None:
                return
            if embedding_dim != index.d:
                print(f"[Search] {label}: embedding dim mismatch ({embedding_dim} vs {index.d}), skipping")
                return

            distances, indices = index.search(query_vector, k)
            metric = index.metric_type
            raw = {}  # idx -> raw distance

            # Absolute quality thresholds to reject clearly irrelevant FAISS results.
            # For L2 on unit-norm vectors: dist > 1.2 → cosine_sim < 0.28 (too poor).
            # For inner product on unit-norm vectors: dist < 0.28 → cosine_sim < 0.28.
            ABS_L2_THRESHOLD = 1.2
            ABS_IP_THRESHOLD = 0.28

            for idx, dist in zip(indices[0], distances[0]):
                if idx < 0:
                    continue
                # Apply absolute quality filter before accepting the result
                if metric == faiss.METRIC_INNER_PRODUCT:
                    if float(dist) < ABS_IP_THRESHOLD:
                        continue
                else:
                    if float(dist) > ABS_L2_THRESHOLD:
                        continue
                hadith_id = None
                if 'faiss_index' in mapping.columns:
                    matched = mapping[mapping['faiss_index'] == idx]
                    if not matched.empty:
                        hadith_id = int(matched.iloc[0]['hadith_id'])
                else:
                    if idx < len(mapping):
                        hadith_id = int(mapping.iloc[idx]['hadith_id'])
                if hadith_id is not None:
                    # For inner product: higher = better → negate so lower = better
                    score = -float(dist) if metric == faiss.METRIC_INNER_PRODUCT else float(dist)
                    raw[hadith_id] = score
                    semantic_count += 1

            if not raw:
                return

            # Min-max normalise this index's scores to [0, 1] before merging
            scores = list(raw.values())
            s_min, s_max = min(scores), max(scores)
            s_range = s_max - s_min if s_max != s_min else 1.0
            for hid, sc in raw.items():
                norm = (sc - s_min) / s_range  # 0 = best, 1 = worst
                # Keep the best (lowest) normalised score if the hadith appears in multiple indexes
                if hid not in hadith_score_map or norm < hadith_score_map[hid]:
                    hadith_score_map[hid] = norm

            print(f"[Search] {label}: {len(raw)} results (k={k})")

        # 1. SEMANTIC SEARCH (FAISS)
        try:
            # Translate Urdu/Arabic to English for FAISS embedding (indexes are English-based)
            embedding_query = cleaned_query
            detected_lang = detect_language_from_text(cleaned_query)
            if detected_lang in ('ar', 'ur'):
                print(f"[Search] Detected {detected_lang} query — translating for embedding")
                embedding_query = translate_to_english_for_embedding(cleaned_query)

            query_embedding = get_embedding(embedding_query)
            query_vector = query_embedding.reshape(1, -1)
            embedding_dim = query_embedding.shape[0]
            print(f"[Search] Query embedding dimension: {embedding_dim}")

            _collect_faiss_scores(bukhari_index, bukhari_mapping, "Bukhari")
            _collect_faiss_scores(tirmizi_index, tirmizi_mapping, "Tirmizi")
            _collect_faiss_scores(muslim_index, muslim_mapping, "Sahih Muslim")
        except Exception as e:
            print(f"[Search] Semantic search failed: {e}")

        # 2. FUZZY SEARCH - always run in parallel with semantic (blended below)
        fuzzy_score_map = {}  # hadith_id -> fuzzy similarity 0-100 (higher = better)
        print(f"[Search] Running fuzzy search in parallel (semantic found {semantic_count})")
        fuzzy_results = fuzzy_search_hadiths(query, limit=10, min_similarity=82)
        print(f"[Search] Fuzzy search found {len(fuzzy_results)} results")
        for result in fuzzy_results:
            hid = result[0]
            sim = float(result[1]) if len(result) >= 2 else 0.0
            fuzzy_score_map[hid] = sim
            # Add to candidate pool if not already found by FAISS
            if hid not in hadith_score_map:
                # Place at end of FAISS range (score=1) so FAISS candidates rank first
                hadith_score_map[hid] = 1.0

        print(f"[Search] Total unique hadiths found: {len(hadith_score_map)}")

        # Fetch hadiths from database
        if not hadith_score_map:
            return jsonify({'results': []}), 200

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Build query to fetch hadiths
        # Convert to Python native int types (not numpy.int64) for PostgreSQL compatibility
        hadith_id_list = [int(hid) for hid in hadith_score_map.keys()]
        placeholders = ','.join(['%s'] * len(hadith_id_list))

        cursor.execute(f"""
            SELECT 
                h.hadith_id,
                h.hadith_number,
                h.hadith_arabic,
                h.hadith_english,
                h.hadith_urdu,
                b.book_name_english,
                c.chapter_number,
                c.chapter_title_english,
                g.grade_type,
                n.narrator_name
            FROM hadiths h
            JOIN hadith_books b ON h.FK_book_id = b.book_id
            JOIN chapters c ON h.FK_chapter_id = c.chapter_id
            LEFT JOIN hadith_grade g ON h.FK_hadith_grade_id = g.grade_id
            LEFT JOIN hadith_narrator n ON h.FK_hadith_narrator_id = n.narrator_id
            WHERE h.hadith_id IN ({placeholders})
        """, hadith_id_list)

        hadiths = cursor.fetchall()

        # Save search to history
        if user_id:
            cursor.execute(
                "INSERT INTO history (FK_user_id, query_text, created_at) VALUES (%s, %s, %s)",
                (user_id, query, datetime.now())
            )
            conn.commit()

        cursor.close()
        conn.close()

        # Build results without similarity_score — it will be set after final ranking
        results = []
        for h in hadiths:
            results.append({
                'hadith_id': h['hadith_id'],
                'book_name': h['book_name_english'],
                'hadith_number': h['hadith_number'],
                'chapter_number': h['chapter_number'],
                'grade': h['grade_type'] or 'No grade mention',
            })

        # ===== FINAL RANKING: FAISS (normalised) + BM25 + Fuzzy + Grade boost =====
        # All signals are normalised to [0, 1] where lower final score = better rank.

        # Grade boost: Sahih hadiths get a head-start, weak ones are pushed down
        GRADE_BOOST = {'Sahih': -0.20, 'Hasan': -0.10, 'Da\'if': 0.15}

        # BM25 keyword scores (higher = better match for short queries)
        bm25_score_map = {}
        if BM25_AVAILABLE and bm25_index is not None and bm25_hadith_ids:
            try:
                bm25_query_tokens = cleaned_query.lower().split()
                raw_bm25 = bm25_index.get_scores(bm25_query_tokens)
                bm25_max = float(raw_bm25.max()) if raw_bm25.max() > 0 else 1.0
                for idx, hid in enumerate(bm25_hadith_ids):
                    if hid in hadith_score_map:
                        bm25_score_map[hid] = float(raw_bm25[idx]) / bm25_max
                print(f"[Search] BM25 scored {len(bm25_score_map)} hadiths")
            except Exception as bm25_err:
                print(f"[Search] BM25 scoring failed: {bm25_err}")

        # Fuzzy scores normalised to [0, 1] (higher = better)
        fuzzy_max = max(fuzzy_score_map.values(), default=1.0)
        fuzzy_norm_map = {hid: sc / fuzzy_max for hid, sc in fuzzy_score_map.items()}

        def final_score(r):
            hid = r['hadith_id']
            faiss_norm  = hadith_score_map.get(hid, 1.0)          # [0,1] lower=better
            bm25_norm   = bm25_score_map.get(hid, 0.0)            # [0,1] higher=better
            fuzzy_norm  = fuzzy_norm_map.get(hid, 0.0)            # [0,1] higher=better
            grade_delta = GRADE_BOOST.get(r['grade'], 0.0)
            # Weights: FAISS 60%, BM25 30%, Fuzzy 10% — convert BM25/Fuzzy to lower=better
            score = (0.60 * faiss_norm
                     + 0.30 * (1.0 - bm25_norm)
                     + 0.10 * (1.0 - fuzzy_norm)
                     + grade_delta)
            return score

        results.sort(key=final_score)
        print(f"[Search] Final ranking applied: FAISS+BM25+Fuzzy+GradeBoost")

        # Remove results that score too poorly (final_score > 0.80 means all signals
        # are weak — FAISS far-off, no BM25/fuzzy overlap, possibly wrong grade boost).
        FINAL_SCORE_CUTOFF = 0.80
        results = [r for r in results if final_score(r) <= FINAL_SCORE_CUTOFF]

        # Cap at 15 results to avoid overwhelming the user with low-confidence matches
        results = results[:15]

        # Set similarity_score from the final combined score so color highlights
        # in the Flutter app reflect actual ranking quality, not just FAISS distance.
        # final_score range is roughly [-0.20, 1.0]; map to [0, 1] for display.
        for r in results:
            fs = final_score(r)
            r['similarity_score'] = round(max(0.0, min(1.0, 1.0 - fs)), 4)

        # Notify user of results (handy if they minimised the app during a slow search)
        if user_id and results:
            count = len(results)
            threading.Thread(
                target=send_notification_to_user,
                args=(user_id, 'Search Complete',
                      f'Found {count} hadith{"s" if count != 1 else ""} for "{query[:40]}"'),
                kwargs={'data': {'type': 'search'}},
                daemon=True
            ).start()

        return jsonify({'results': results}), 200

    except Exception as e:
        import traceback
        error_msg = str(e)
        error_traceback = traceback.format_exc()
        print(f"Search error: {error_msg}")
        print(f"Traceback:\n{error_traceback}")
        return jsonify({'message': f'Search failed: {error_msg}'}), 500


@app.route('/api/user/update-profile-photo', methods=['PUT'])
def update_profile_photo():
    """
    Update user's profile photo URL

    Expected JSON body:
    {
        "user_id": int,
        "profile_photo_url": "string"
    }

    Returns:
    {
        "user_id": int,
        "username": "string",
        "profile_photo_url": "string",
        "created_at": "ISO datetime string"
    }
    """
    conn = None
    cursor = None
    try:
        data = request.get_json()

        if not data:
            return jsonify({'message': 'No data provided'}), 400

        user_id = data.get('user_id')
        profile_photo_url = data.get('profile_photo_url')

        if not user_id:
            return jsonify({'message': 'Missing user_id'}), 400

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Update profile photo URL
        cursor.execute(
            """
            UPDATE users
            SET profile_photo_url = %s
            WHERE user_id = %s
            RETURNING user_id, user_name, profile_photo_url, created_at
            """,
            (profile_photo_url, user_id)
        )

        user = cursor.fetchone()

        if not user:
            cursor.close()
            conn.close()
            return jsonify({'message': 'User not found'}), 404

        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({
            'user_id': user['user_id'],
            'username': user['user_name'],
            'profile_photo_url': user.get('profile_photo_url'),
            'created_at': user['created_at'].isoformat(),
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        return jsonify({'message': f'Update failed: {str(e)}'}), 500


@app.route('/api/user/delete-profile-photo', methods=['DELETE'])
def delete_profile_photo():
    """
    Delete user's profile photo

    Expected JSON body:
    {
        "user_id": int
    }

    Returns:
    {
        "user_id": int,
        "username": "string",
        "profile_photo_url": null,
        "created_at": "ISO datetime string"
    }
    """
    conn = None
    cursor = None
    try:
        data = request.get_json()

        if not data:
            return jsonify({'message': 'No data provided'}), 400

        user_id = data.get('user_id')

        if not user_id:
            return jsonify({'message': 'Missing user_id'}), 400

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Get current profile photo URL before deleting
        cursor.execute(
            """
            SELECT profile_photo_url
            FROM users
            WHERE user_id = %s
            """,
            (user_id,)
        )
        user = cursor.fetchone()

        if not user:
            cursor.close()
            conn.close()
            return jsonify({'message': 'User not found'}), 404

        # Update profile photo URL to NULL
        cursor.execute(
            """
            UPDATE users
            SET profile_photo_url = NULL
            WHERE user_id = %s
            RETURNING user_id, user_name, profile_photo_url, created_at
            """,
            (user_id,)
        )

        updated_user = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({
            'user_id': updated_user['user_id'],
            'username': updated_user['user_name'],
            'profile_photo_url': updated_user.get('profile_photo_url'),
            'created_at': updated_user['created_at'].isoformat(),
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        return jsonify({'message': f'Delete failed: {str(e)}'}), 500


@app.route('/api/user/fcm-token', methods=['POST'])
def register_fcm_token():
    """
    Store or refresh the FCM device token for push notifications.

    Expected JSON body:
    {
        "user_id": int,
        "fcm_token": "string"
    }
    """
    conn = None
    cursor = None
    try:
        data = request.get_json()
        if not data:
            return jsonify({'message': 'No data provided'}), 400

        user_id = data.get('user_id')
        fcm_token = data.get('fcm_token')

        if not user_id or not fcm_token:
            return jsonify({'message': 'Missing user_id or fcm_token'}), 400

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE users SET fcm_token = %s WHERE user_id = %s",
            (fcm_token, user_id)
        )
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({'message': 'FCM token registered'}), 200

    except Exception as e:
        if conn:
            conn.rollback()
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        return jsonify({'message': f'Failed to register token: {str(e)}'}), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    faiss_status = {
        'bukhari_loaded': bukhari_index is not None,
        'tirmizi_loaded': tirmizi_index is not None,
        'muslim_loaded': muslim_index is not None,
        'bukhari_mapping_loaded': bukhari_mapping is not None,
        'tirmizi_mapping_loaded': tirmizi_mapping is not None,
        'muslim_mapping_loaded': muslim_mapping is not None,
    }
    return jsonify({
        'status': 'ok',
        'message': 'API is running',
        'faiss_status': faiss_status
    }), 200


@app.route('/api/history', methods=['GET'])
def get_history():
    """
    Get user's search history

    Query parameters:
    - user_id: int (required)

    Returns:
    {
        "history": [
            {
                "history_id": int,
                "query_text": "string",
                "created_at": "ISO datetime string"
            }
        ]
    }
    """
    conn = None
    try:
        user_id = request.args.get('user_id', type=int)

        if not user_id:
            return jsonify({'message': 'Missing user_id parameter'}), 400

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        cursor.execute("""
            SELECT history_id, query_text, created_at
            FROM history
            WHERE FK_user_id = %s
            ORDER BY created_at DESC
        """, (user_id,))

        history = cursor.fetchall()
        cursor.close()
        conn.close()

        history_list = [{
            'history_id': h['history_id'],
            'query_text': h['query_text'],
            'created_at': h['created_at'].isoformat()
        } for h in history]

        return jsonify({'history': history_list}), 200

    except Exception as e:
        if conn:
            conn.close()
        return jsonify({'message': f'Failed to fetch history: {str(e)}'}), 500


@app.route('/api/history/<int:history_id>', methods=['DELETE'])
def delete_history(history_id):
    """
    Delete a history entry

    URL parameters:
    - history_id: int (required)

    Returns:
    {
        "message": "History deleted successfully"
    }
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            DELETE FROM history
            WHERE history_id = %s
        """, (history_id,))

        if cursor.rowcount == 0:
            cursor.close()
            conn.close()
            return jsonify({'message': 'History entry not found'}), 404

        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({'message': 'History deleted successfully'}), 200

    except Exception as e:
        if conn:
            conn.rollback()
            conn.close()
        return jsonify({'message': f'Failed to delete history: {str(e)}'}), 500


@app.route('/api/bookmarks', methods=['GET'])
def get_bookmarks():
    """
    Get user's bookmarks

    Query parameters:
    - user_id: int (required)

    Returns:
    {
        "bookmarks": [
            {
                "bookmark_id": int,
                "hadith_id": int,
                "created_at": "ISO datetime string",
                "summary": {
                    "hadith_id": int,
                    "book_name": "string",
                    "hadith_number": "string",
                    "chapter_number": "string",
                    "grade": "string"
                }
            }
        ]
    }
    """
    conn = None
    try:
        user_id = request.args.get('user_id', type=int)

        if not user_id:
            return jsonify({'message': 'Missing user_id parameter'}), 400

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        cursor.execute("""
            SELECT 
                b.bookmark_id,
                b.FK_hadith_id as hadith_id,
                b.created_at,
                h.hadith_number,
                hb.book_name_english as book_name,
                c.chapter_number,
                COALESCE(hg.grade_type, 'Unknown') as grade
            FROM bookmark b
            JOIN hadiths h ON b.FK_hadith_id = h.hadith_id
            JOIN hadith_books hb ON h.FK_book_id = hb.book_id
            JOIN chapters c ON h.FK_chapter_id = c.chapter_id
            LEFT JOIN hadith_grade hg ON h.FK_hadith_grade_id = hg.grade_id
            WHERE b.FK_user_id = %s
            ORDER BY b.created_at DESC
        """, (user_id,))

        bookmarks = cursor.fetchall()
        cursor.close()
        conn.close()

        bookmark_list = [{
            'bookmark_id': b['bookmark_id'],
            'hadith_id': b['hadith_id'],
            'created_at': b['created_at'].isoformat(),
            'summary': {
                'hadith_id': b['hadith_id'],
                'book_name': b['book_name'],
                'hadith_number': b['hadith_number'],
                'chapter_number': str(b['chapter_number']),
                'grade': b['grade']
            }
        } for b in bookmarks]

        return jsonify({'bookmarks': bookmark_list}), 200

    except Exception as e:
        if conn:
            conn.close()
        return jsonify({'message': f'Failed to fetch bookmarks: {str(e)}'}), 500


@app.route('/api/hadith/<int:hadith_id>', methods=['GET'])
def get_hadith_detail(hadith_id):
    """
    Get hadith detail by ID

    Query parameters:
    - user_id: int (optional, used to check if bookmarked)

    Returns:
    {
        "hadith_id": int,
        "book_name": "string",
        "hadith_number": int,
        "chapter_number": int,
        "chapter_name": "string",
        "grade": "string",
        "narrator": "string",
        "arabic_text": "string",
        "english_text": "string",
        "urdu_text": "string",
        "bookmarked": bool,
        "bookmark_id": int (if bookmarked)
    }
    """
    conn = None
    try:
        user_id = request.args.get('user_id', type=int)

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Fetch hadith details
        cursor.execute("""
            SELECT 
                h.hadith_id,
                h.hadith_number,
                h.hadith_arabic,
                h.hadith_english,
                h.hadith_urdu,
                b.book_name_english as book_name,
                c.chapter_number,
                c.chapter_title_english as chapter_name,
                COALESCE(g.grade_type, 'No grade mention') as grade,
                COALESCE(n.narrator_name, 'Unknown') as narrator
            FROM hadiths h
            JOIN hadith_books b ON h.FK_book_id = b.book_id
            JOIN chapters c ON h.FK_chapter_id = c.chapter_id
            LEFT JOIN hadith_grade g ON h.FK_hadith_grade_id = g.grade_id
            LEFT JOIN hadith_narrator n ON h.FK_hadith_narrator_id = n.narrator_id
            WHERE h.hadith_id = %s
        """, (hadith_id,))

        hadith = cursor.fetchone()

        if not hadith:
            cursor.close()
            conn.close()
            return jsonify({'message': 'Hadith not found'}), 404

        # Check if bookmarked (if user_id provided)
        bookmarked = False
        bookmark_id = None
        if user_id:
            cursor.execute("""
                SELECT bookmark_id, created_at
                FROM bookmark
                WHERE FK_user_id = %s AND FK_hadith_id = %s
            """, (user_id, hadith_id))

            bookmark = cursor.fetchone()
            if bookmark:
                bookmarked = True
                bookmark_id = bookmark['bookmark_id']

        cursor.close()
        conn.close()

        return jsonify({
            'hadith_id': hadith['hadith_id'],
            'book_name': hadith['book_name'],
            'hadith_number': hadith['hadith_number'],
            'chapter_number': hadith['chapter_number'],
            'chapter_name': hadith['chapter_name'],
            'grade': hadith['grade'],
            'narrator': hadith['narrator'],
            'arabic_text': hadith['hadith_arabic'],
            'english_text': hadith['hadith_english'],
            'urdu_text': hadith['hadith_urdu'],
            'bookmarked': bookmarked,
            'bookmark_id': bookmark_id
        }), 200

    except Exception as e:
        if conn:
            conn.close()
        return jsonify({'message': f'Failed to fetch hadith detail: {str(e)}'}), 500


@app.route('/api/bookmarks', methods=['POST'])
def create_bookmark():
    """
    Create a bookmark

    Expected JSON body:
    {
        "user_id": int,
        "hadith_id": int
    }

    Returns:
    {
        "bookmark_id": int,
        "user_id": int,
        "hadith_id": int,
        "created_at": "ISO datetime string"
    }
    """
    conn = None
    cursor = None
    try:
        data = request.get_json()

        if not data:
            return jsonify({'message': 'No data provided'}), 400

        user_id = data.get('user_id')
        hadith_id = data.get('hadith_id')

        if not user_id or not hadith_id:
            return jsonify({'message': 'Missing required fields: user_id and hadith_id'}), 400

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Check if bookmark already exists
        cursor.execute("""
            SELECT bookmark_id FROM bookmark
            WHERE FK_user_id = %s AND FK_hadith_id = %s
        """, (user_id, hadith_id))

        existing = cursor.fetchone()
        if existing:
            cursor.close()
            conn.close()
            return jsonify({
                'bookmark_id': existing['bookmark_id'],
                'user_id': user_id,
                'hadith_id': hadith_id,
                'message': 'Bookmark already exists'
            }), 200

        # Create bookmark
        cursor.execute("""
            INSERT INTO bookmark (FK_user_id, FK_hadith_id, created_at)
            VALUES (%s, %s, %s)
            RETURNING bookmark_id, created_at
        """, (user_id, hadith_id, datetime.now()))

        result = cursor.fetchone()
        conn.commit()

        cursor.close()
        conn.close()

        return jsonify({
            'bookmark_id': result['bookmark_id'],
            'user_id': user_id,
            'hadith_id': hadith_id,
            'created_at': result['created_at'].isoformat()
        }), 201

    except Exception as e:
        if conn:
            conn.rollback()
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        return jsonify({'message': f'Failed to create bookmark: {str(e)}'}), 500


@app.route('/api/bookmarks/<int:bookmark_id>', methods=['DELETE'])
def delete_bookmark(bookmark_id):
    """
    Delete a bookmark

    URL parameters:
    - bookmark_id: int (required)

    Returns:
    {
        "message": "Bookmark deleted successfully"
    }
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            DELETE FROM bookmark
            WHERE bookmark_id = %s
        """, (bookmark_id,))

        if cursor.rowcount == 0:
            cursor.close()
            conn.close()
            return jsonify({'message': 'Bookmark not found'}), 404

        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({'message': 'Bookmark deleted successfully'}), 200

    except Exception as e:
        if conn:
            conn.rollback()
            conn.close()
        return jsonify({'message': f'Failed to delete bookmark: {str(e)}'}), 500


# Global EasyOCR readers (initialized ONCE at startup)
# CRITICAL: Never initialize EasyOCR Reader per request - reuse these instances
AR_UR_READER = None  # Arabic/Urdu reader
EN_READER = None  # English reader (for fallback when Tesseract fails)
AR_UR_READER_INITIALIZING = False
AR_UR_READER_INIT_ERROR = None
EN_READER_INITIALIZING = False
EN_READER_INIT_ERROR = None

# STEP 4: NO preprocessing function - use original images
# ❌ No grayscale
# ❌ No thresholding
# ❌ No resizing (unless image > 3000px)


@app.route('/api/ocr/easyocr', methods=['POST'])
def easyocr_extract_text():
    """
    Extract text from image using EasyOCR
    
    Request body:
    {
        "image": "base64_encoded_image_string",
        "image_format": "jpg" (optional, default: "jpg"),
        "languages": ["ar", "ur"] (optional, but should be Arabic/Urdu only)
    }
    
    Returns:
    {
        "text": "extracted text from image",
        "success": true
    }
    """
    try:
        if not EASYOCR_AVAILABLE:
            return jsonify({
                'message': 'EasyOCR is not installed. Please install it with: pip install easyocr',
                'success': False
            }), 503
        
        # Language routing will select the appropriate reader below
        
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({
                'message': 'Missing image data in request',
                'success': False
            }), 400
        
        # Get requested languages
        requested_languages = data.get('languages', ['ar', 'ur'])
        if not isinstance(requested_languages, list):
            requested_languages = ['ar', 'ur']
        
        # Validate languages - support English, Arabic, and Urdu
        valid_languages = ['en', 'ar', 'ur']
        languages = [lang for lang in requested_languages if lang in valid_languages]
        if not languages:
            languages = ['ar', 'ur']  # Default to Arabic/Urdu if invalid
        
        # Route to appropriate reader based on language
        use_english_reader = 'en' in languages and len(languages) == 1
        use_ar_ur_reader = 'ar' in languages or 'ur' in languages or (not use_english_reader)
        
        # Select reader
        if use_english_reader:
            # English only - use English reader
            if EN_READER is None:
                if EN_READER_INITIALIZING:
                    return jsonify({
                        'message': 'EasyOCR English reader is still initializing. Please wait and try again.',
                        'success': False
                    }), 503
                elif EN_READER_INIT_ERROR:
                    return jsonify({
                        'message': f'EasyOCR English reader initialization failed: {EN_READER_INIT_ERROR}. Please restart the backend.',
                        'success': False
                    }), 503
                else:
                    return jsonify({
                        'message': 'EasyOCR English reader not initialized. Please restart the backend.',
                        'success': False
                    }), 503
            reader = EN_READER
            print(f"Using English EasyOCR reader")
        else:
            # Arabic/Urdu - use Arabic/Urdu reader
            if AR_UR_READER is None:
                if AR_UR_READER_INITIALIZING:
                    return jsonify({
                        'message': 'EasyOCR reader is still initializing. Please wait 60-90 seconds and try again.',
                        'success': False
                    }), 503
                elif AR_UR_READER_INIT_ERROR:
                    return jsonify({
                        'message': f'EasyOCR reader initialization failed: {AR_UR_READER_INIT_ERROR}. Please restart the backend.',
                        'success': False
                    }), 503
                else:
                    return jsonify({
                        'message': 'EasyOCR reader not initialized. Please restart the backend.',
                        'success': False
                    }), 503
            reader = AR_UR_READER
            # CRITICAL: Use ONLY the requested language (no mixing!)
            # Filter to only Arabic/Urdu languages, but keep only what was requested
            languages = [lang for lang in languages if lang in ['ar', 'ur']]
            if not languages:
                # Default based on what was requested
                if 'ur' in requested_languages:
                    languages = ['ur']
                elif 'ar' in requested_languages:
                    languages = ['ar']
                else:
                    languages = ['ur']  # Default to Urdu
            print(f"Using Arabic/Urdu EasyOCR reader with languages: {languages} (NO mixing)")
        
        print(f"EasyOCR request: languages={languages}")
        print(f"📊 OCR Request Details:")
        print(f"   - Requested languages: {languages}")
        print(f"   - Using reader: {'English' if use_english_reader else 'Arabic/Urdu (CRAFT)'}")
        
        # Decode base64 image
        try:
            import numpy as np
            image_base64 = data['image']
            image_format = data.get('image_format', 'jpg')
            image_bytes = base64.b64decode(image_base64)
            
            # Convert to PIL Image
            image = Image.open(io.BytesIO(image_bytes))
            
            # STEP 4: Resize ONLY if image > 3000px (preserve quality)
            original_width, original_height = image.width, image.height
            max_dimension = 3000  # Only resize if dimension > 3000px
            if image.width > max_dimension or image.height > max_dimension:
                # Maintain aspect ratio
                if image.width > image.height:
                    ratio = max_dimension / image.width
                else:
                    ratio = max_dimension / image.height
                new_width = int(image.width * ratio)
                new_height = int(image.height * ratio)
                image = image.resize((new_width, new_height), Image.Resampling.LANCZOS)
                print(f"Resized image from {original_width}x{original_height} to {new_width}x{new_height} (dimension > 3000px)")
            else:
                print(f"Image size {original_width}x{original_height} - no resizing needed")
            
            # STEP 4: NO preprocessing - use original image
            # ❌ No grayscale
            # ❌ No thresholding
            # ❌ No contrast adjustment
            # Ensure RGB for EasyOCR
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            # Convert PIL Image to numpy array for EasyOCR
            image_array = np.array(image)
            
            print(f"📊 Image Processing Details:")
            print(f"   - Final image dimensions: {image.width}x{image.height}")
            print(f"   - Image mode: {image.mode}")
            print(f"   - Preprocessing: NONE (using original image)")
            
        except Exception as e:
            return jsonify({
                'message': f'Invalid image data: {str(e)}',
                'success': False
            }), 400
        
        # Reader already selected above based on language
        
        # Extract text using EasyOCR with timeout protection (60 seconds max)
        print(f"🔍 Running EasyOCR inference with languages: {languages}...")
        print(f"   - Detection network: {'CRAFT' if use_ar_ur_reader else 'Default'}")
        try:
            # Use threading for timeout (cross-platform compatible)
            import threading
            results = None
            error_occurred = None
            
            def run_ocr():
                nonlocal results, error_occurred
                try:
                    # STEP 4: Use readtext without paragraph parameter (paragraph=True not supported in EasyOCR)
                    # EasyOCR automatically groups text by paragraphs
                    results = reader.readtext(image_array)
                except Exception as e:
                    error_occurred = e
                    print(f"❌ EasyOCR readtext error: {e}")
                    import traceback
                    print(f"Traceback: {traceback.format_exc()}")
            
            ocr_thread = threading.Thread(target=run_ocr, daemon=True)
            ocr_thread.start()
            ocr_thread.join(timeout=120.0)  # 120 second timeout (CPU EasyOCR can be slow)

            if ocr_thread.is_alive():
                # Thread is still running - timeout occurred
                return jsonify({
                    'message': 'OCR processing timed out after 120 seconds. The image may be too complex or the server is under load.',
                    'success': False
                }), 408
            
            if error_occurred:
                raise error_occurred
            
            if results is None:
                return jsonify({
                    'message': 'OCR processing failed',
                    'success': False
                }), 500
                
        except Exception as e:
            import traceback
            error_trace = traceback.format_exc()
            print(f"❌ EasyOCR processing error: {error_trace}")
            return jsonify({
                'message': f'OCR processing failed: {str(e)}',
                'success': False
            }), 500
        
        # STEP 4: NO confidence filtering - return all text
        # Combine all detected text
        try:
            extracted_text = '\n'.join([result[1] for result in results])
        except Exception as e:
            print(f"❌ Error combining OCR results: {e}")
            import traceback
            print(f"Traceback: {traceback.format_exc()}")
            return jsonify({
                'message': f'Error processing OCR results: {str(e)}',
                'success': False
            }), 500
        
        # Log results for debugging
        print(f"📊 OCR Results Summary:")
        print(f"   - Total detections: {len(results)}")
        print(f"   - Extracted text length: {len(extracted_text)} characters")
        if results:
            print(f"   - Confidence range: {min(r[2] for r in results):.3f} - {max(r[2] for r in results):.3f}")
            print(f"   - Sample text: {[r[1][:30] for r in results[:3]]}")
        
        if not extracted_text.strip():
            return jsonify({
                'text': '',
                'message': 'No text detected in image (or all text filtered by confidence threshold)',
                'success': False
            }), 200
        
        print(f"✅ EasyOCR extracted {len(extracted_text)} characters successfully")
        return jsonify({
            'text': extracted_text,
            'success': True
        }), 200
        
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        print(f"❌ EasyOCR endpoint error: {error_trace}")
        print(f"Error type: {type(e).__name__}")
        print(f"Error message: {str(e)}")
        return jsonify({
            'message': f'Failed to extract text: {str(e)}',
            'success': False,
            'error_type': type(e).__name__
        }), 500


@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    """
    Transcribe audio file using OpenAI Whisper API.

    Accepts multipart/form-data:
      - audio    : the audio file (required)
      - language : 'ur', 'en', or 'ar' (optional, omit for auto-detect)

    Returns:
    {
        "transcript": "transcribed text",
        "success": true
    }

    Uses chunked streaming to send keep-alive bytes every 5 s so NAT/firewall
    idle-connection timeouts never drop the socket while Whisper is processing.
    """
    import tempfile

    if 'audio' not in request.files:
        return jsonify({'message': 'Missing audio file in request', 'success': False}), 400

    audio_file = request.files['audio']
    language = request.form.get('language') or None

    valid_languages = ['ur', 'en', 'ar']
    if language and language not in valid_languages:
        return jsonify({
            'message': f'Invalid language code. Must be one of: {", ".join(valid_languages)}',
            'success': False
        }), 400

    filename = audio_file.filename or 'audio.m4a'
    dot = filename.rfind('.')
    ext = filename[dot + 1:].lower() if dot >= 0 else 'm4a'

    print(f"🎤 Transcription request received:")
    print(f"   - Filename: {filename}, Format: {ext}")
    print(f"   - Language: {language if language else 'auto-detect'}")

    with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{ext}') as tmp:
        audio_file.save(tmp.name)
        temp_audio_path = tmp.name

    def generate():
        whisper_result = {'text': None, 'error': None}

        def _call_whisper():
            try:
                client = get_openai_client()
                print("🔍 Sending audio to OpenAI Whisper API...")
                with open(temp_audio_path, 'rb') as f:
                    resp = client.audio.transcriptions.create(
                        model="whisper-1",
                        file=f,
                        language=language,
                        response_format="text",
                    )
                whisper_result['text'] = str(resp).strip()
            except Exception as exc:
                whisper_result['error'] = exc

        whisper_thread = threading.Thread(target=_call_whisper, daemon=True)
        whisper_thread.start()

        # Poll every 5 s and yield a single space so the router never sees
        # an idle connection. Each space is a valid JSON whitespace character,
        # so jsonDecode on the Flutter side handles it correctly after trim().
        elapsed = 0
        max_wait = 150
        while whisper_thread.is_alive() and elapsed < max_wait:
            whisper_thread.join(timeout=5)
            elapsed += 5
            if whisper_thread.is_alive():
                yield ' '

        try:
            if whisper_thread.is_alive():
                print("❌ Whisper API timed out after 150 seconds")
                yield _json.dumps({
                    'message': 'Transcription timed out. Try a shorter audio clip (under 2 minutes).',
                    'success': False,
                    'error': 'TIMEOUT',
                })
            elif whisper_result['error'] is not None:
                error_msg = str(whisper_result['error'])
                print(f"❌ Whisper API Error: {error_msg}")
                if 'api key' in error_msg.lower() or 'authentication' in error_msg.lower() or '401' in error_msg or '403' in error_msg:
                    yield _json.dumps({'message': 'OpenAI API key issue. Check OPENAI_API_KEY in .env.', 'success': False, 'error': 'API_KEY_ERROR'})
                elif 'quota' in error_msg.lower():
                    yield _json.dumps({'message': 'OpenAI API quota exceeded. Check account billing.', 'success': False, 'error': 'QUOTA_ERROR'})
                else:
                    yield _json.dumps({'message': f'Whisper API error: {error_msg}', 'success': False, 'error': 'WHISPER_ERROR'})
            else:
                transcript_text = whisper_result['text']
                if not transcript_text:
                    yield _json.dumps({'message': 'Empty transcript received from API', 'success': False})
                else:
                    print(f"✅ Transcription successful: {len(transcript_text)} characters")
                    yield _json.dumps({'transcript': transcript_text, 'success': True})
        finally:
            try:
                if os.path.exists(temp_audio_path):
                    os.unlink(temp_audio_path)
            except Exception as cleanup_err:
                print(f"Warning: Could not delete temp file: {cleanup_err}")

    return Response(stream_with_context(generate()), content_type='application/json')


def is_english_only(text):
    """Reject only if the ENTIRE query is non-Latin script (Arabic, Urdu, CJK, etc.).
    Accepts English text that contains Arabic loanwords written in Latin letters
    (e.g. 'What is Zakat?', 'Tell me about Salah')."""
    # Strip spaces, digits, and punctuation — look only at word characters
    cleaned = re.sub(r'[\s\d\W]', '', text)
    if not cleaned:
        return True
    # Accept if at least one Latin letter is present
    return any('a' <= c.lower() <= 'z' for c in cleaned)


def detect_language_from_text(text):
    """Detect language from Unicode character ranges.
    Returns 'ar' for Arabic, 'ur' for Urdu (Nastaliq), 'en' for English/Latin."""
    arabic_count = sum(1 for c in text if '؀' <= c <= 'ۿ' or 'ݐ' <= c <= 'ݿ')
    latin_count = sum(1 for c in text if 'a' <= c.lower() <= 'z')

    if arabic_count == 0 and latin_count == 0:
        return 'en'
    if arabic_count <= latin_count:
        return 'en'

    # Distinguish Urdu from Arabic by Urdu-specific characters:
    # ں (U+06BA) noon ghunna — appears in کریں، ہیں، ہوں (very common)
    # ہ (U+06C1) he goal — common Urdu form of ه
    # ھ (U+06BE) do chashmi he — common in Urdu (بھ، پھ، تھ)
    # ے (U+06D2) ye barree — sentence-final ye in Urdu
    # ٹ (U+0679), ڈ (U+0688), ڑ (U+0691), ژ (U+0698), ۓ (U+06D3)
    urdu_chars = set('ںہھےٹڈڑژۓ')
    urdu_specific = sum(1 for c in text if c in urdu_chars)
    return 'ur' if urdu_specific > 0 else 'ar'


def translate_to_english_for_embedding(text):
    """Translate Arabic/Urdu question to English for FAISS embedding search.
    Falls back to original text if translation fails."""
    try:
        client = get_openai_client()
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "Translate the following question to English. Output ONLY the English translation, nothing else."},
                {"role": "user", "content": text}
            ],
            max_tokens=200,
            temperature=0
        )
        translated = response.choices[0].message.content.strip()
        print(f"[Chat] Translated question for embedding: {translated}")
        return translated
    except Exception as e:
        print(f"[Chat] Translation for embedding failed: {e}. Using original text.")
        return text


def generate_gpt4o_response(system_prompt, user_prompt, timeout=60):
    """Generate response using OpenAI GPT-4o API with timeout"""
    try:
        client = get_openai_client()
        
        print(f"[GPT-4o] Generating response...")
        print(f"[GPT-4o] System prompt length: {len(system_prompt)} characters")
        print(f"[GPT-4o] User prompt length: {len(user_prompt)} characters")
        print(f"[GPT-4o] Timeout: {timeout} seconds")
        
        import time
        start_time = time.time()
        
        # Add timeout to the API call
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.2,
            max_tokens=2000,
            timeout=timeout  # Add timeout parameter
        )
        
        elapsed_time = time.time() - start_time
        print(f"[GPT-4o] Generation took {elapsed_time:.2f} seconds")
        
        generated_text = response.choices[0].message.content.strip()
        
        if not generated_text:
            raise Exception("GPT-4o returned empty response")
        
        print(f"[GPT-4o] Response generated successfully ({len(generated_text)} characters)")
        return generated_text
        
    except Exception as e:
        error_msg = str(e)
        print(f"[GPT-4o] ✗ ERROR: {error_msg}")
        import traceback
        print(f"[GPT-4o] Traceback: {traceback.format_exc()}")
        
        # Check for timeout errors
        if "timeout" in error_msg.lower() or "timed out" in error_msg.lower():
            raise Exception("Request timeout: The GPT-4o API call took too long. Please try again.")
        elif "connection" in error_msg.lower() or "connect" in error_msg.lower():
            raise Exception("Connection error: Cannot connect to OpenAI service. Please check your internet connection and API key.")
        else:
            raise


def _make_chat_response(data, status_code=200):
    """Helper function to create chat response with keep-alive headers"""
    response = jsonify(data)
    response.headers['Connection'] = 'keep-alive'
    response.headers['Keep-Alive'] = 'timeout=60'
    return response, status_code


@app.route('/api/conversations/<int:conversation_id>/messages', methods=['GET'])
def get_conversation_messages(conversation_id):
    """
    Get all messages from a specific conversation
    
    URL parameters:
    - conversation_id: int (required)
    
    Returns:
    {
        "conversation_id": int,
        "messages": [
            {
                "message_id": int,
                "message_text": "string",
                "is_user": bool,
                "created_at": "ISO datetime string"
            }
        ]
    }
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Verify conversation exists
        cursor.execute("""
            SELECT conversation_id, FK_user_id
            FROM conversations
            WHERE conversation_id = %s
        """, (conversation_id,))
        
        conversation = cursor.fetchone()
        if not conversation:
            cursor.close()
            conn.close()
            return jsonify({'message': 'Conversation not found'}), 404
        
        # Fetch ALL messages from the conversation (no limit)
        cursor.execute("""
            SELECT 
                message_id,
                message_text,
                FK_user_type_id,
                created_at
            FROM messages
            WHERE FK_conversation_id = %s
            ORDER BY created_at ASC
        """, (conversation_id,))
        
        messages = cursor.fetchall()
        cursor.close()
        conn.close()
        
        print(f"[API] Found {len(messages)} messages for conversation_id={conversation_id}")
        
        # Format messages
        messages_list = []
        for msg in messages:
            messages_list.append({
                'message_id': msg['message_id'],
                'message_text': msg['message_text'],
                'is_user': (msg.get('FK_user_type_id') or msg.get('fk_user_type_id') or 0) == 1,  # 1 = User, 2 = Bot
                'created_at': msg['created_at'].isoformat()
            })
        
        print(f"[API] Returning {len(messages_list)} formatted messages")
        
        return jsonify({
            'conversation_id': conversation_id,
            'messages': messages_list
        }), 200
        
    except Exception as e:
        if conn:
            conn.close()
        import traceback
        error_trace = traceback.format_exc()
        print(f"Get conversation messages error: {error_trace}")
        return jsonify({'message': f'Failed to fetch messages: {str(e)}'}), 500


@app.route('/api/conversations', methods=['GET'])
def get_user_conversations():
    """
    Get all conversations for a user
    
    Query parameters:
    - user_id: int (required)
    
    Returns:
    {
        "conversations": [
            {
                "conversation_id": int,
                "created_at": "ISO datetime string",
                "updated_at": "ISO datetime string",
                "last_message": "string" (optional, preview of last message)
            }
        ]
    }
    """
    conn = None
    try:
        user_id = request.args.get('user_id', type=int)
        
        if not user_id:
            return jsonify({'message': 'Missing user_id parameter'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Fetch all conversations for the user
        cursor.execute("""
            SELECT
                c.conversation_id,
                c.created_at,
                c.updated_at,
                (SELECT message_text
                 FROM messages
                 WHERE FK_conversation_id = c.conversation_id
                 AND FK_user_type_id = 1
                 ORDER BY created_at ASC
                 LIMIT 1) as description,
                (SELECT message_text
                 FROM messages
                 WHERE FK_conversation_id = c.conversation_id
                 ORDER BY created_at DESC
                 LIMIT 1) as last_message
            FROM conversations c
            WHERE c.FK_user_id = %s
            ORDER BY c.updated_at DESC
        """, (user_id,))

        conversations = cursor.fetchall()
        cursor.close()
        conn.close()

        conversations_list = []
        for conv in conversations:
            conversations_list.append({
                'conversation_id': conv['conversation_id'],
                'created_at': conv['created_at'].isoformat(),
                'updated_at': conv['updated_at'].isoformat(),
                'description': conv['description'] or '',
                'last_message': conv['last_message'] or ''
            })
        
        return jsonify({'conversations': conversations_list}), 200
        
    except Exception as e:
        if conn:
            conn.close()
        import traceback
        error_trace = traceback.format_exc()
        print(f"Get user conversations error: {error_trace}")
        return jsonify({'message': f'Failed to fetch conversations: {str(e)}'}), 500


@app.route('/api/conversations/latest', methods=['GET'])
def get_latest_conversation():
    """
    Get the most recent conversation with all its messages for a user
    
    Query parameters:
    - user_id: int (required)
    
    Returns:
    {
        "conversation_id": int | null,
        "created_at": "ISO datetime string" | null,
        "updated_at": "ISO datetime string" | null,
        "messages": [
            {
                "message_id": int,
                "message_text": "string",
                "is_user": bool,
                "created_at": "ISO datetime string"
            }
        ]
    }
    """
    conn = None
    try:
        user_id = request.args.get('user_id', type=int)
        
        if not user_id:
            return jsonify({'message': 'Missing user_id parameter'}), 400
        
        print(f"[API] Loading latest conversation for user_id={user_id}")
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get the most recent conversation for the user
        cursor.execute("""
            SELECT 
                conversation_id,
                created_at,
                updated_at
            FROM conversations
            WHERE FK_user_id = %s
            ORDER BY updated_at DESC
            LIMIT 1
        """, (user_id,))
        
        conversation = cursor.fetchone()
        
        if not conversation:
            # No conversation found, return empty
            print(f"[API] No conversation found for user_id={user_id}")
            cursor.close()
            conn.close()
            return jsonify({
                'conversation_id': None,
                'created_at': None,
                'updated_at': None,
                'messages': []
            }), 200
        
        conversation_id = conversation['conversation_id']
        print(f"[API] Found conversation_id={conversation_id} for user_id={user_id}")
        
        # Fetch ALL messages from the conversation (no limit)
        cursor.execute("""
            SELECT 
                message_id,
                message_text,
                FK_user_type_id,
                created_at
            FROM messages
            WHERE FK_conversation_id = %s
            ORDER BY created_at ASC
        """, (conversation_id,))
        
        messages = cursor.fetchall()
        cursor.close()
        conn.close()
        
        print(f"[API] Found {len(messages)} messages for conversation_id={conversation_id}")
        
        # Format messages
        messages_list = []
        for msg in messages:
            # Handle None values safely
            is_user = (msg.get('FK_user_type_id') or 0) == 1  # 1 = User, 2 = Bot
            created_at = msg.get('created_at')
            created_at_str = created_at.isoformat() if created_at else None
            
            messages_list.append({
                'message_id': msg.get('message_id'),
                'message_text': msg.get('message_text') or '',
                'FK_user_type_id': msg.get('FK_user_type_id'),  # Include raw FK_user_type_id for frontend
                'is_user': is_user,  # Boolean flag: True for user (1), False for bot (2)
                'created_at': created_at_str
            })
            print(f"[API] Message {msg.get('message_id')}: FK_user_type_id={msg.get('FK_user_type_id')}, is_user={is_user}, text_length={len(msg.get('message_text') or '')}")
        
        print(f"[API] Returning {len(messages_list)} formatted messages")
        
        # Handle None dates safely
        conv_created_at = conversation.get('created_at')
        conv_updated_at = conversation.get('updated_at')
        
        response_data = {
            'conversation_id': conversation_id,
            'created_at': conv_created_at.isoformat() if conv_created_at else None,
            'updated_at': conv_updated_at.isoformat() if conv_updated_at else None,
            'messages': messages_list
        }
        
        return jsonify(response_data), 200
        
    except Exception as e:
        if conn:
            conn.close()
        import traceback
        error_trace = traceback.format_exc()
        print(f"[ERROR] Get latest conversation error: {error_trace}")
        print(f"[ERROR] Exception type: {type(e).__name__}")
        print(f"[ERROR] Exception message: {str(e)}")
        return jsonify({
            'message': f'Failed to fetch latest conversation: {str(e)}',
            'error_type': type(e).__name__
        }), 500


@app.route('/api/conversations/user/<int:user_id>/all_messages', methods=['GET'])
def get_all_user_messages(user_id):
    """
    Get ALL messages from ALL conversations for a user (ordered chronologically)
    
    URL parameters:
    - user_id: int (required)
    
    Returns:
    {
        "user_id": int,
        "total_messages": int,
        "messages": [
            {
                "message_id": int,
                "message_text": "string",
                "is_user": bool,
                "created_at": "ISO datetime string",
                "conversation_id": int
            }
        ]
    }
    
    NOTE: This loads ALL messages from ALL conversations (no limit).
    Use /api/conversations/latest for just the latest conversation.
    """
    conn = None
    try:
        print(f"[API] Loading ALL messages for user_id={user_id}")
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Fetch ALL messages from ALL conversations for the user
        cursor.execute("""
            SELECT 
                m.message_id,
                m.message_text,
                m.FK_user_type_id,
                m.created_at,
                m.FK_conversation_id
            FROM messages m
            INNER JOIN conversations c ON m.FK_conversation_id = c.conversation_id
            WHERE c.FK_user_id = %s
            ORDER BY m.created_at ASC
        """, (user_id,))
        
        messages = cursor.fetchall()
        cursor.close()
        conn.close()
        
        print(f"[API] Found {len(messages)} total messages for user_id={user_id}")
        
        # Format messages
        messages_list = []
        for msg in messages:
            # DEBUG: Print all keys to see what PostgreSQL is returning
            if len(messages_list) == 0:  # Only print for first message
                print(f"[DEBUG] First message keys: {list(msg.keys())}")
                print(f"[DEBUG] First message full: {dict(msg)}")
            
            # Handle None values safely
            # PostgreSQL RealDictCursor may return lowercase column names
            fk_user_type_id = msg.get('FK_user_type_id') or msg.get('fk_user_type_id') or msg.get('FK_user_type_id'.lower())
            is_user = (fk_user_type_id or 0) == 1  # 1 = User, 2 = Bot
            created_at = msg.get('created_at')
            created_at_str = created_at.isoformat() if created_at else None
            
            # DEBUG: Print what we're sending
            print(f"[API] Message {msg.get('message_id')}: FK_user_type_id={fk_user_type_id}, is_user={is_user}, text_preview={str(msg.get('message_text') or '')[:50]}")
            
            messages_list.append({
                'message_id': msg.get('message_id'),
                'message_text': msg.get('message_text') or '',
                'FK_user_type_id': fk_user_type_id,  # Include raw FK_user_type_id for frontend
                'is_user': is_user,  # Boolean flag: True for user (1), False for bot (2)
                'created_at': created_at_str,
                'conversation_id': msg.get('FK_conversation_id') or msg.get('fk_conversation_id')
            })
        
        print(f"[API] Returning {len(messages_list)} formatted messages")
        
        return jsonify({
            'user_id': user_id,
            'total_messages': len(messages_list),
            'messages': messages_list
        }), 200
        
    except Exception as e:
        if conn:
            conn.close()
        import traceback
        error_trace = traceback.format_exc()
        print(f"[ERROR] Get all user messages error: {error_trace}")
        print(f"[ERROR] Exception type: {type(e).__name__}")
        print(f"[ERROR] Exception message: {str(e)}")
        return jsonify({
            'message': f'Failed to fetch all messages: {str(e)}',
            'error_type': type(e).__name__
        }), 500


@app.route('/api/chat', methods=['POST'])
def chat():
    """
    Chat endpoint for True Hadith AI - RAG Model Implementation
    
    Request JSON:
    {
        "user_id": INTEGER,
        "conversation_id": INTEGER | null,
        "question": STRING
    }
    
    Response JSON:
    {
        "conversation_id": INTEGER,
        "reply": STRING
    }
    
    RAG Logic:
    1. Generate query embedding using OpenAI text-embedding-3-large
    2. Search FAISS with K=8 or 10
    3. Sort by similarity score (descending)
    4. Take highest similarity hadith_id from each FAISS file
    5. Fetch English translation only first
    6. Send to GPT-4o LLM
    7. After LLM response, fetch remaining fields
    """
    conn = None
    cursor = None
    
    # Track request start time for timeout checking
    request_start_time = time.time()
    REQUEST_TIMEOUT = 60  # 60 seconds total timeout
    
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'message': 'No data provided'}), 400
        
        user_id = data.get('user_id')
        conversation_id = data.get('conversation_id')
        question = data.get('question')
        
        if not user_id:
            return jsonify({'message': 'Missing user_id'}), 400
        
        if not question or not question.strip():
            return jsonify({'message': 'Missing question'}), 400
        
        question = question.strip()

        # Detect language from the question text
        requested_language = data.get('language') or detect_language_from_text(question)
        print(f"[Chat] Detected/requested language: {requested_language}")

        # For non-English questions, translate to English for FAISS embedding
        embedding_question = question
        if requested_language in ('ar', 'ur'):
            embedding_question = translate_to_english_for_embedding(question)

        # Connect to database
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Ensure hadith_id column exists on messages BEFORE any query that touches it.
        # This must run first so the SELECT/INSERT below don't fail on a missing column.
        try:
            cursor.execute(
                "ALTER TABLE messages ADD COLUMN IF NOT EXISTS hadith_id INTEGER NULL"
            )
            conn.commit()
        except Exception as _e:
            conn.rollback()
            print(f"[Chat] hadith_id column ensure: {_e}")

        # Ensure user_type table has required values (1 = User, 2 = Bot)
        # This prevents foreign key constraint violations
        try:
            # Check what exists
            cursor.execute("""
                SELECT user_type_id FROM user_type WHERE user_type_id IN (1, 2)
            """)
            existing_types = {row.get('user_type_id') for row in cursor.fetchall() if row.get('user_type_id') is not None}
            print(f"[Chat] Existing user_type IDs: {existing_types}")
            
            # Insert user_type_id=1 if it doesn't exist
            if 1 not in existing_types:
                try:
                    cursor.execute("""
                        INSERT INTO user_type (user_type_id, user_type_name) 
                        VALUES (1, 'user')
                        ON CONFLICT (user_type_id) DO NOTHING
                    """)
                    print("[Chat] ✓ Created user_type_id=1 (user)")
                except Exception as insert_error:
                    # If it fails due to conflict, that's okay - try without ON CONFLICT
                    error_str = str(insert_error).lower()
                    if "duplicate" in error_str or "unique" in error_str or "conflict" in error_str:
                        print("[Chat] user_type_id=1 already exists (conflict handled)")
                    else:
                        # Try without ON CONFLICT clause (in case it's not supported)
                        try:
                            cursor.execute("""
                                INSERT INTO user_type (user_type_id, user_type_name) 
                                VALUES (1, 'user')
                            """)
                            print("[Chat] ✓ Created user_type_id=1 (user) - without ON CONFLICT")
                        except:
                            print(f"[Chat] ⚠ Could not insert user_type_id=1: {insert_error}")
            
            # Insert user_type_id=2 if it doesn't exist
            if 2 not in existing_types:
                try:
                    cursor.execute("""
                        INSERT INTO user_type (user_type_id, user_type_name) 
                        VALUES (2, 'bot')
                        ON CONFLICT (user_type_id) DO NOTHING
                    """)
                    print("[Chat] ✓ Created user_type_id=2 (bot)")
                except Exception as insert_error:
                    # If it fails due to conflict, that's okay - try without ON CONFLICT
                    error_str = str(insert_error).lower()
                    if "duplicate" in error_str or "unique" in error_str or "conflict" in error_str:
                        print("[Chat] user_type_id=2 already exists (conflict handled)")
                    else:
                        # Try without ON CONFLICT clause (in case it's not supported)
                        try:
                            cursor.execute("""
                                INSERT INTO user_type (user_type_id, user_type_name) 
                                VALUES (2, 'bot')
                            """)
                            print("[Chat] ✓ Created user_type_id=2 (bot) - without ON CONFLICT")
                        except:
                            print(f"[Chat] ⚠ Could not insert user_type_id=2: {insert_error}")
            
            conn.commit()
            print("[Chat] ✓ user_type table verified/initialized")
        except Exception as e:
            # If user_type table doesn't exist or has different structure, continue anyway
            # The INSERT might still work if FK constraint doesn't exist
            import traceback
            print(f"[Chat] ⚠ Warning: Could not verify user_type table: {str(e)}")
            print(f"[Chat] Traceback: {traceback.format_exc()}")
            conn.rollback()
        
        # Create conversation if needed
        current_time = datetime.now()
        if conversation_id is None:
            cursor.execute(
                """
                INSERT INTO conversations (fk_user_id, created_at, updated_at) 
                VALUES (%s, %s, %s) 
                RETURNING conversation_id
                """,
                (user_id, current_time, current_time)
            )
            conversation = cursor.fetchone()
            conversation_id = conversation['conversation_id']
            conn.commit()
        else:
            # Update conversation's updated_at timestamp
            cursor.execute(
                """
                UPDATE conversations 
                SET updated_at = %s 
                WHERE conversation_id = %s
                """,
                (current_time, conversation_id)
            )
            conn.commit()
        
        # Save user message
        try:
            # Use lowercase unquoted column names (PostgreSQL stores unquoted identifiers as lowercase)
            cursor.execute(
                """
                INSERT INTO messages (fk_conversation_id, fk_user_type_id, message_text, created_at)
                VALUES (%s, %s, %s, %s)
                """,
                (conversation_id, 1, question, current_time)
            )
            conn.commit()
            print(f"[Chat] ✓ Saved user message to conversation_id={conversation_id}")
        except Exception as e:
            error_msg = str(e)
            import traceback
            print(f"[Chat] ✗ ERROR inserting user message: {error_msg}")
            print(f"[Chat] Full traceback: {traceback.format_exc()}")
            # If column doesn't exist error, it means the server needs to be restarted
            if "does not exist" in error_msg.lower() and ("column" in error_msg.lower() or "fk_" in error_msg.lower()):
                print(f"[Chat] ⚠ Column name error detected. Please restart the backend server to load the latest code changes.")
                raise Exception(f"Database column error: {error_msg}. Please restart the backend server.")
            # If foreign key constraint fails, check if user_type table has the required values
            if "foreign key" in error_msg.lower() or "fk_user_type_id" in error_msg.lower():
                print(f"[Chat] Foreign key error detected. Checking user_type table...")
                # Verify user_type table has required values
                try:
                    cursor.execute("SELECT user_type_id FROM user_type WHERE user_type_id IN (1, 2)")
                    existing = cursor.fetchall()
                    print(f"[Chat] Found user_type records: {existing}")
                    if not existing or len(existing) < 2:
                        print(f"[Chat] ⚠ user_type table is missing required values!")
                        # Try to insert them again
                        try:
                            cursor.execute("INSERT INTO user_type (user_type_id, user_type_name) VALUES (1, 'user') ON CONFLICT DO NOTHING")
                            cursor.execute("INSERT INTO user_type (user_type_id, user_type_name) VALUES (2, 'bot') ON CONFLICT DO NOTHING")
                            conn.commit()
                            print(f"[Chat] ✓ Inserted missing user_type values, retrying message insert...")
                            # Retry the message insert
                            cursor.execute(
                                """
                                INSERT INTO messages (fk_conversation_id, fk_user_type_id, message_text, created_at)
                                VALUES (%s, %s, %s, %s)
                                """,
                                (conversation_id, 1, question, current_time)
                            )
                            conn.commit()
                            print(f"[Chat] ✓ Retry successful!")
                        except Exception as retry_error:
                            print(f"[Chat] ✗ Retry failed: {retry_error}")
                            raise Exception(f"Database constraint error: {error_msg}. Please ensure user_type table has id=1 and id=2. Run: INSERT INTO user_type (user_type_id, user_type_name) VALUES (1, 'user'), (2, 'bot');")
                    else:
                        raise Exception(f"Database constraint error: {error_msg}. user_type table exists but foreign key constraint is failing.")
                except Exception as check_error:
                    print(f"[Chat] ✗ Error checking user_type: {check_error}")
                    raise Exception(f"Database constraint error: {error_msg}. Please ensure user_type table exists with id=1 and id=2.")
            raise
        
        # Load the last hadith the bot cited in this conversation (by stored hadith_id — no regex).
        # This is passed as context to the LLM regardless of question type; the LLM decides relevance.
        previous_hadith_context_text = None
        if conversation_id:
            try:
                cursor.execute("""
                    SELECT hadith_id FROM messages
                    WHERE FK_conversation_id = %s
                      AND FK_user_type_id = 2
                      AND hadith_id IS NOT NULL
                    ORDER BY created_at DESC
                    LIMIT 1
                """, (conversation_id,))
                prev_row = cursor.fetchone()
                if prev_row and prev_row.get('hadith_id'):
                    cursor.execute(
                        "SELECT hadith_english FROM hadiths WHERE hadith_id = %s",
                        (prev_row['hadith_id'],)
                    )
                    prev_h = cursor.fetchone()
                    if prev_h:
                        previous_hadith_context_text = prev_h['hadith_english']
                        print(f"[RAG] Loaded previous hadith (id={prev_row['hadith_id']}) as context")
            except Exception as e:
                conn.rollback()
                print(f"[RAG] Could not load previous hadith context: {e}")

        if True:  # Always run FAISS retrieval for every question
            # RAG Retrieval: Generate embedding using OpenAI text-embedding-3-large
            try:
                query_embedding = get_embedding(embedding_question)
                query_vector = query_embedding.reshape(1, -1)
                embedding_dim = query_embedding.shape[0]
                print(f"[RAG] Generated embedding dimension: {embedding_dim}")
            except Exception as e:
                cursor.close()
                conn.close()
                return jsonify({
                    'conversation_id': conversation_id,
                    'reply': f'Error generating embedding: {str(e)}'
                }), 500
            
            # Search both FAISS indexes with K=8 or 10
            k = 10  # K value can be 8 or 10
            selected_hadith_ids = []  # Will store (source, hadith_id, similarity_score)
        
        # Search Bukhari FAISS
        if bukhari_index is not None and bukhari_mapping is not None:
            if embedding_dim == bukhari_index.d:
                print(f"[RAG] Searching Bukhari FAISS with K={k}")
                distances, indices = bukhari_index.search(query_vector, k)
                
                # Create list of (index, distance) pairs and sort by similarity (lower distance = higher similarity)
                results = []
                for i, (idx, dist) in enumerate(zip(indices[0], distances[0])):
                    if idx < 0:
                        continue
                    
                    # Get hadith_id from mapping
                    hadith_id = None
                    if 'faiss_index' in bukhari_mapping.columns:
                        matched_rows = bukhari_mapping[bukhari_mapping['faiss_index'] == idx]
                        if not matched_rows.empty:
                            hadith_id = int(matched_rows.iloc[0]['hadith_id'])
                    else:
                        if idx < len(bukhari_mapping):
                            hadith_id = int(bukhari_mapping.iloc[idx]['hadith_id'])
                    
                    if hadith_id is not None:
                        # Convert distance to similarity score (lower distance = higher similarity)
                        similarity_score = 1.0 / (1.0 + dist)
                        results.append((hadith_id, similarity_score, 'bukhari'))
                
                # Sort by similarity score in descending order
                results.sort(key=lambda x: x[1], reverse=True)

                # Take top-3 from Bukhari so the LLM can pick the most relevant
                for best_hadith_id, best_score, source in results[:3]:
                    selected_hadith_ids.append((source, best_hadith_id, best_score))
                    print(f"[RAG] Bukhari: candidate hadith_id={best_hadith_id} similarity={best_score:.4f}")
        
        # Search Tirmizi FAISS
        if tirmizi_index is not None and tirmizi_mapping is not None:
            if embedding_dim == tirmizi_index.d:
                print(f"[RAG] Searching Tirmizi FAISS with K={k}")
                distances, indices = tirmizi_index.search(query_vector, k)
                
                # Create list of (index, distance) pairs and sort by similarity (lower distance = higher similarity)
                results = []
                for i, (idx, dist) in enumerate(zip(indices[0], distances[0])):
                    if idx < 0:
                        continue
                    
                    # Get hadith_id from mapping
                    hadith_id = None
                    if 'faiss_index' in tirmizi_mapping.columns:
                        matched_rows = tirmizi_mapping[tirmizi_mapping['faiss_index'] == idx]
                        if not matched_rows.empty:
                            hadith_id = int(matched_rows.iloc[0]['hadith_id'])
                    else:
                        if idx < len(tirmizi_mapping):
                            hadith_id = int(tirmizi_mapping.iloc[idx]['hadith_id'])
                    
                    if hadith_id is not None:
                        # Convert distance to similarity score (lower distance = higher similarity)
                        similarity_score = 1.0 / (1.0 + dist)
                        results.append((hadith_id, similarity_score, 'tirmizi'))
                
                # Sort by similarity score in descending order
                results.sort(key=lambda x: x[1], reverse=True)

                # Take top-3 from Tirmizi so the LLM can pick the most relevant
                for best_hadith_id, best_score, source in results[:3]:
                    selected_hadith_ids.append((source, best_hadith_id, best_score))
                    print(f"[RAG] Tirmizi: candidate hadith_id={best_hadith_id} similarity={best_score:.4f}")

        # Search Sahih Muslim FAISS
        if muslim_index is not None and muslim_mapping is not None:
            if embedding_dim == muslim_index.d:
                print(f"[RAG] Searching Sahih Muslim FAISS with K={k}")
                distances, indices = muslim_index.search(query_vector, k)

                results = []
                for i, (idx, dist) in enumerate(zip(indices[0], distances[0])):
                    if idx < 0:
                        continue

                    hadith_id = None
                    if 'faiss_index' in muslim_mapping.columns:
                        matched_rows = muslim_mapping[muslim_mapping['faiss_index'] == idx]
                        if not matched_rows.empty:
                            hadith_id = int(matched_rows.iloc[0]['hadith_id'])
                    else:
                        if idx < len(muslim_mapping):
                            hadith_id = int(muslim_mapping.iloc[idx]['hadith_id'])

                    if hadith_id is not None:
                        similarity_score = 1.0 / (1.0 + dist)
                        results.append((hadith_id, similarity_score, 'muslim'))

                results.sort(key=lambda x: x[1], reverse=True)

                # Take top-3 from Muslim so the LLM can pick the most relevant
                for best_hadith_id, best_score, source in results[:3]:
                    selected_hadith_ids.append((source, best_hadith_id, best_score))
                    print(f"[RAG] Sahih Muslim: candidate hadith_id={best_hadith_id} similarity={best_score:.4f}")

        # If no hadith found and not a follow-up question, return without calling LLM
        if not selected_hadith_ids and not (is_followup_question and previous_hadith_data):
            bot_reply = "No matching hadith found."
            bot_message_time = datetime.now()
            cursor.execute(
                """
                INSERT INTO messages (fk_conversation_id, fk_user_type_id, message_text, created_at)
                VALUES (%s, %s, %s, %s)
                """,
                (conversation_id, 2, bot_reply, bot_message_time)
            )
            cursor.execute(
                """
                UPDATE conversations 
                SET updated_at = %s 
                WHERE conversation_id = %s
                """,
                (bot_message_time, conversation_id)
            )
            conn.commit()
            cursor.close()
            conn.close()
            return _make_chat_response({
                'conversation_id': conversation_id,
                'reply': bot_reply
            })
        
        # Fetch ONLY English translations first (to reduce input token cost)
        if True:
            hadith_id_list = [int(h[1]) for h in selected_hadith_ids]
            placeholders = ','.join(['%s'] * len(hadith_id_list))
            
            cursor.execute(f"""
                SELECT 
                    h.hadith_id,
                    h.hadith_english
                FROM hadiths h
                WHERE h.hadith_id IN ({placeholders})
            """, hadith_id_list)
            
            hadiths_english = cursor.fetchall()
        
        if not hadiths_english:
            bot_reply = "No matching hadith found."
            bot_message_time = datetime.now()
            cursor.execute(
                """
                INSERT INTO messages (fk_conversation_id, fk_user_type_id, message_text, created_at)
                VALUES (%s, %s, %s, %s)
                """,
                (conversation_id, 2, bot_reply, bot_message_time)
            )
            cursor.execute(
                """
                UPDATE conversations 
                SET updated_at = %s 
                WHERE conversation_id = %s
                """,
                (bot_message_time, conversation_id)
            )
            conn.commit()
            cursor.close()
            conn.close()
            return _make_chat_response({
                'conversation_id': conversation_id,
                'reply': bot_reply
            })
        
        # Build context from English translations only
        english_hadiths_text = "\n\n".join([
            f"Hadith {i+1}:\n{h['hadith_english'] or 'N/A'}"
            for i, h in enumerate(hadiths_english)
        ])
        
        # Load previous conversation messages for context (last 8 messages to keep context manageable)
        conversation_history = ""
        if conversation_id:
            # Get the current message ID to exclude it from history
            cursor.execute("""
                SELECT message_id
                FROM messages
                WHERE FK_conversation_id = %s
                  AND FK_user_type_id = 1
                ORDER BY created_at DESC
                LIMIT 1
            """, (conversation_id,))
            
            current_msg = cursor.fetchone()
            current_message_id = current_msg.get('message_id') if current_msg else None
            
            # Load previous messages (excluding the current one)
            if current_message_id:
                cursor.execute("""
                    SELECT 
                        message_text,
                        created_at,
                        FK_user_type_id
                    FROM messages
                    WHERE FK_conversation_id = %s
                      AND message_id < %s
                    ORDER BY created_at DESC
                    LIMIT 8
                """, (conversation_id, current_message_id))
            else:
                cursor.execute("""
                    SELECT
                        message_text,
                        created_at,
                        FK_user_type_id
                    FROM messages
                    WHERE FK_conversation_id = %s
                    ORDER BY created_at DESC
                    LIMIT 8
                """, (conversation_id,))
            
            previous_messages = cursor.fetchall()
            if previous_messages:
                # Reverse to show chronological order
                previous_messages.reverse()
                conversation_history = "\n\nPrevious conversation:\n"
                for msg in previous_messages:
                    # FK_user_type_id: 1 = User, 2 = Bot/Assistant
                    # PostgreSQL returns lowercase column names, so check both cases
                    fk_user_type_id = msg.get('FK_user_type_id') or msg.get('fk_user_type_id') or 0
                    if fk_user_type_id == 1:
                        message_text = msg.get('message_text') or ''
                        conversation_history += f"User: {message_text}\n"
                    else:
                        # For bot messages, show only the explanation part if it's a full hadith response
                        bot_msg = msg.get('message_text') or ''
                        if '✅ Explanation' in bot_msg:
                            # Extract just the explanation
                            parts = bot_msg.split('✅ Explanation')
                            if len(parts) > 1:
                                explanation_part = parts[1].split(':', 1)[1].strip() if ':' in parts[1] else parts[1].strip()
                                conversation_history += f"Assistant: {explanation_part}\n"
                            else:
                                conversation_history += f"Assistant: [Previous hadith response]\n"
                        elif 'No matching hadith found' in bot_msg:
                            conversation_history += f"Assistant: No matching hadith found.\n"
                        else:
                            conversation_history += f"Assistant: {bot_msg}\n"
                
                print(f"[RAG] Loaded {len(previous_messages)} previous messages for context")
        
        # System prompt — GPT-4o outputs a JSON object {title, explanation}.
        # All hadith metadata (Arabic, Urdu, book, chapter, etc.) is added by the backend from DB.
        language_instruction_map = {
            'ar': 'Respond in Arabic (العربية). Write both the title and explanation entirely in Arabic.',
            'ur': 'Respond in Urdu (اردو). Write both the title and explanation entirely in Urdu.',
            'en': 'Respond in English.',
        }
        language_instruction = language_instruction_map.get(requested_language, 'Respond in English.')

        system_prompt = f"""You are True Hadith AI, a strictly controlled Islamic Hadith explanation assistant.

The system has already retrieved the most relevant hadith(s) from the database. Your job is to explain them clearly.

LANGUAGE: {language_instruction}

ALLOWED:
✔ Explain who is mentioned and what they said or did
✔ Clarify what is explicitly stated in the hadith text
✔ Paraphrase meaning that already exists clearly in the text
✔ For broad questions, briefly address multiple hadiths provided

NOT ALLOWED:
✘ No Fatwas, rulings, Halal/Haram decisions
✘ No scholar opinions, Tafsir, or Fiqh
✘ No use of Qur'an or texts not provided
✘ No assumptions, guesses, or personal advice
✘ No moral conclusions beyond the text

OUTPUT FORMAT — respond with ONLY valid JSON, no markdown, no code blocks, no extra text:
{{"title": "Short 5-10 word headline summarising the main point", "explanation": "2-3 clear sentences explaining what the hadith says."}}

If no hadith is relevant or none was provided, respond with:
{{"title": "", "explanation": "No matching hadith found."}}

You are a safe academic Hadith verification system, NOT a scholar, mufti, or religious authority."""
        
        # User prompt with English hadiths and conversation history
        previous_context_block = ""
        if previous_hadith_context_text:
            previous_context_block = f"\nPrevious Hadith (shown in last bot reply — use as context if the question relates to it):\n{previous_hadith_context_text}\n"

        user_prompt = f"""{conversation_history if conversation_history else ''}{previous_context_block}User Question: {question}

Retrieved Hadith Candidates (English Translation Only). Choose the most relevant to the question:
{english_hadiths_text}

Respond with ONLY a JSON object in this exact format (no markdown, no code block):
{{"title": "Short headline", "explanation": "2-3 sentence explanation using only what is stated in the hadith text."}}"""
        
        # Check if we're approaching timeout before calling LLM
        elapsed_time = time.time() - request_start_time
        if elapsed_time > 50:  # If we've already used 50 seconds, don't call LLM
            raise TimeoutError("Request timeout: The chat request took too long to process.")
        
        # Generate LLM response using GPT-4o with timeout
        try:
            print(f"[RAG] Sending to GPT-4o LLM...")
            print(f"[RAG] English hadiths count: {len(hadiths_english)}")
            print(f"[RAG] Elapsed time so far: {elapsed_time:.2f} seconds")
            
            # Calculate remaining time for GPT-4o (leave 10 seconds buffer)
            remaining_time = REQUEST_TIMEOUT - elapsed_time - 10
            if remaining_time < 10:
                remaining_time = 10  # Minimum 10 seconds
            
            # Use calculated timeout for GPT-4o
            bot_reply = generate_gpt4o_response(system_prompt, user_prompt, timeout=int(remaining_time))
            
            if not bot_reply or len(bot_reply.strip()) == 0:
                raise Exception("GPT-4o returned empty response")
            
            print(f"[RAG] GPT-4o response generated successfully ({len(bot_reply)} characters)")
            
        except TimeoutError as e:
            error_message = str(e)
            print(f"✗ ERROR: Request timeout")
            print(f"  Error Message: {error_message}")
            bot_reply = "The request took too long to process. Please try again with a shorter question."
        except Exception as e:
            error_type = type(e).__name__
            error_message = str(e)
            print(f"✗ ERROR generating GPT-4o response:")
            print(f"  Error Type: {error_type}")
            print(f"  Error Message: {error_message}")
            import traceback
            print(f"  Full Traceback:")
            print(traceback.format_exc())
            
            # Provide error message
            if "timeout" in error_message.lower() or "timed out" in error_message.lower():
                bot_reply = "The response is taking too long. Please try again."
            elif "connection" in error_message.lower() or "connect" in error_message.lower():
                bot_reply = "Connection error: Cannot connect to OpenAI service. Please check your internet connection and API key."
            elif "empty response" in error_message.lower():
                bot_reply = "Received empty response from GPT-4o. Please try again."
            else:
                bot_reply = f"Error generating response: {error_message[:100]}. Please try again."
        
        # After LLM response, fetch remaining hadith chunks (Arabic, Urdu, grade, narrator, book, chapter)
        hadiths_by_book = {}  # Initialize to avoid scope issues
        if True:
            # Sort selected_hadith_ids by similarity score (descending) to get the best match first
            if selected_hadith_ids:
                selected_hadith_ids.sort(key=lambda x: x[2], reverse=True)
                print(f"[RAG] Selected hadiths sorted by similarity: {[(h[1], f'{h[2]:.4f}') for h in selected_hadith_ids]}")
            
            # Fetch full hadith data from database
            if selected_hadith_ids:
                hadith_id_list = [int(h[1]) for h in selected_hadith_ids]
                placeholders = ','.join(['%s'] * len(hadith_id_list))
                
                cursor.execute(f"""
                    SELECT 
                        h.hadith_id,
                        h.hadith_number,
                        h.hadith_arabic,
                        h.hadith_english,
                        h.hadith_urdu,
                        b.book_name_english,
                        c.chapter_number,
                        c.chapter_title_english,
                        COALESCE(g.grade_type, 'No grade mention') as grade_type,
                        COALESCE(n.narrator_name, 'Unknown') as narrator_name
                    FROM hadiths h
                    JOIN hadith_books b ON h.FK_book_id = b.book_id
                    JOIN chapters c ON h.FK_chapter_id = c.chapter_id
                    LEFT JOIN hadith_grade g ON h.FK_hadith_grade_id = g.grade_id
                    LEFT JOIN hadith_narrator n ON h.FK_hadith_narrator_id = n.narrator_id
                    WHERE h.hadith_id IN ({placeholders})
                """, hadith_id_list)
                
                full_hadiths = cursor.fetchall()
                
                # Create a mapping of hadith_id to hadith data and source
                hadith_map = {h['hadith_id']: h for h in full_hadiths}
                
                # Organize hadiths by book (source)
                hadiths_by_book = {}
                for source, hadith_id, similarity_score in selected_hadith_ids:
                    if hadith_id in hadith_map:
                        if source not in hadiths_by_book:
                            hadiths_by_book[source] = []
                        hadith_data = hadith_map[hadith_id].copy()
                        hadith_data['similarity_score'] = similarity_score
                        hadiths_by_book[source].append(hadith_data)
                
                print(f"[RAG] Hadiths organized by book: {list(hadiths_by_book.keys())}")
                
                # Get the best hadith from each book (for LLM context, we'll use the best overall)
                best_hadith_info = selected_hadith_ids[0]  # (source, hadith_id, similarity_score)
                best_hadith_id = best_hadith_info[1]
                
                # Get the best hadith from the map (for single hadith display fallback)
                if best_hadith_id not in hadith_map:
                    print(f"[RAG] WARNING: Best hadith_id {best_hadith_id} not found in fetched hadiths!")
                    # Fallback to first hadith if best not found
                    if full_hadiths:
                        hadith = full_hadiths[0]
                    else:
                        hadith = None
                else:
                    hadith = hadith_map[best_hadith_id]
                    print(f"[RAG] Using best hadith_id={best_hadith_id} with similarity={best_hadith_info[2]:.4f} from {best_hadith_info[0]}")
            else:
                full_hadiths = []
                hadith = None
                hadiths_by_book = {}
        
        # Parse GPT-4o JSON response {title, explanation}
        import json as _json
        explanation_title = ''
        explanation_body = ''
        raw_llm = bot_reply.strip()

        # Strip accidental markdown code fences
        if raw_llm.startswith('```'):
            raw_llm = re.sub(r'^```[a-z]*\n?', '', raw_llm).rstrip('`').strip()

        try:
            gpt_data = _json.loads(raw_llm)
            explanation_title = str(gpt_data.get('title', '')).strip()
            explanation_body  = str(gpt_data.get('explanation', '')).strip()
            print(f"[RAG] GPT-4o JSON parsed — title='{explanation_title[:60]}'")
        except (_json.JSONDecodeError, AttributeError) as _je:
            print(f"[RAG] WARNING: GPT-4o did not return valid JSON ({_je}), using raw text as body")
            explanation_body = raw_llm
            explanation_title = ''

        no_hadith = (
            "no matching hadith found" in explanation_body.lower()
            or "no hadith found" in explanation_body.lower()
        )

        # Build structured hadith evidence list (top 3 by match score)
        hadith_evidence = []
        if full_hadiths and not no_hadith:
            all_sorted = sorted(selected_hadith_ids, key=lambda x: x[2], reverse=True)
            seen_ids = set()
            for source, h_id, score in all_sorted:
                if h_id in seen_ids:
                    continue
                seen_ids.add(h_id)
                if h_id not in hadith_map:
                    continue
                h = hadith_map[h_id]
                hadith_evidence.append({
                    'rank': len(hadith_evidence) + 1,
                    'book_name': h.get('book_name_english') or 'N/A',
                    'hadith_number': str(h.get('hadith_number') or 'N/A'),
                    'narrator': h.get('narrator_name') or 'Unknown',
                    'grade': h.get('grade_type') or 'N/A',
                    'arabic_text': h.get('hadith_arabic') or 'N/A',
                    'english_text': h.get('hadith_english') or 'N/A',
                    'urdu_text': h.get('hadith_urdu') or 'N/A',
                    'chapter': f"{h.get('chapter_number','') or ''} {h.get('chapter_title_english','') or ''}".strip(),
                    'match_score': round(float(score), 2),
                })
                if len(hadith_evidence) >= 3:
                    break

        # Plain-text reply kept for history / backwards compat
        if no_hadith:
            bot_reply = "No matching hadith found."
            explanation_title = ''
            explanation_body = 'No matching hadith found.'
        else:
            title_line = f"{explanation_title}\n\n" if explanation_title else ''
            bot_reply = f"{title_line}{explanation_body}"

        print(f"[RAG] Structured response — {len(hadith_evidence)} evidence hadiths")
        
        # Save bot reply, storing the best hadith_id so future follow-ups can retrieve it by ID
        saved_hadith_id = hadith.get('hadith_id') if hadith else None
        bot_message_time = datetime.now()
        cursor.execute(
            """
            INSERT INTO messages (fk_conversation_id, fk_user_type_id, message_text, hadith_id, created_at)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (conversation_id, 2, bot_reply, saved_hadith_id, bot_message_time)
        )
        cursor.execute(
            """
            UPDATE conversations 
            SET updated_at = %s 
            WHERE conversation_id = %s
            """,
            (bot_message_time, conversation_id)
        )
        conn.commit()
        
        cursor.close()
        conn.close()

        # Check total elapsed time
        total_elapsed = time.time() - request_start_time
        print(f"[RAG] Total request time: {total_elapsed:.2f} seconds")

        # Push notification — useful when the user minimises the app while the
        # chatbot is thinking (requests can take up to 60 s).
        preview = bot_reply[:80] + '…' if len(bot_reply) > 80 else bot_reply
        threading.Thread(
            target=send_notification_to_user,
            args=(user_id, 'True Hadith AI replied', preview),
            kwargs={'data': {'type': 'chat', 'conversation_id': str(conversation_id)}},
            daemon=True
        ).start()

        return _make_chat_response({
            'conversation_id': conversation_id,
            'reply': bot_reply,
            'explanation_title': explanation_title if 'explanation_title' in locals() else '',
            'explanation_body': explanation_body if 'explanation_body' in locals() else bot_reply,
            'hadiths': hadith_evidence if 'hadith_evidence' in locals() else [],
        })

    except TimeoutError as e:
        if conn:
            conn.rollback()
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        
        error_message = str(e)
        print(f"Chat endpoint timeout: {error_message}")
        return _make_chat_response({
            'conversation_id': conversation_id if 'conversation_id' in locals() else None,
            'reply': 'The request took too long to process. Please try again.'
        }, 408)  # 408 Request Timeout
        
    except Exception as e:
        if conn:
            conn.rollback()
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        import traceback
        error_trace = traceback.format_exc()
        print(f"Chat endpoint error: {error_trace}")
        
        # Check if it's a connection-related error
        error_message = str(e)
        
        # Check for foreign key constraint violations
        if "fk_user_type_id" in error_message.lower() or "foreign key" in error_message.lower():
            print(f"[ERROR] Foreign key constraint violation detected: {error_message}")
            # Try to provide helpful error message
            if "violates foreign key constraint" in error_message.lower():
                reply_message = "Database configuration error: Please ensure user_types table exists with id values 1 and 2."
            else:
                reply_message = f'Database error: {error_message[:150]}. Please check database schema.'
        elif "connection" in error_message.lower() or "connect" in error_message.lower() or "interrupted" in error_message.lower():
            reply_message = "Connection error: The request was interrupted. Please try again."
        elif "timeout" in error_message.lower() or "timed out" in error_message.lower():
            reply_message = "Request timeout: The request took too long. Please try again."
        else:
            # Show more of the error message for debugging
            reply_message = f'Chat failed: {error_message[:200]}. Please try again.'
        
        return _make_chat_response({
            'conversation_id': conversation_id if 'conversation_id' in locals() else None,
            'reply': reply_message
        }, 500)


# Initialize on startup
print("\n" + "=" * 50)
print("Initializing backend...")
print("=" * 50)

# Initialize Firebase Admin SDK for push notifications
get_firebase_app()

# Load FAISS indexes and mappings
print("Loading FAISS indexes and mapping files...")
load_faiss_indexes()
load_mapping_csvs()

# Build BM25 keyword index
print("Building BM25 keyword index...")
build_bm25_index()

# Initialize EasyOCR Readers ONCE at startup (CRITICAL PERFORMANCE FIX)
# This eliminates the 60-90 second delay on every request
if EASYOCR_AVAILABLE:
    print("Initializing EasyOCR Readers (this may take 60-90 seconds each)...")
    print("  CRITICAL: Readers initialized ONCE and reused for all requests")
    
    def initialize_ar_ur_reader():
        """Initialize Arabic/Urdu EasyOCR reader at startup with CRAFT detection network"""
        global AR_UR_READER, AR_UR_READER_INITIALIZING, AR_UR_READER_INIT_ERROR
        AR_UR_READER_INITIALIZING = True
        AR_UR_READER_INIT_ERROR = None
        try:
            print("  Initializing EasyOCR Reader(['ar','ur'], gpu=False, quantize=True, detect_network='craft')...")
            print("  Using CRAFT detection network for better Arabic/Urdu text detection")
            AR_UR_READER = easyocr.Reader(
                ['ar', 'ur'],
                gpu=False,
                quantize=True,
                detect_network='craft'  # CRAFT network better for cursive scripts
            )
            print("  ✓ EasyOCR Reader initialized successfully for Arabic/Urdu with CRAFT")
            AR_UR_READER_INITIALIZING = False
        except Exception as e:
            print(f"  ✗ Failed to initialize EasyOCR Reader: {e}")
            import traceback
            print(f"  Traceback: {traceback.format_exc()}")
            AR_UR_READER = None
            AR_UR_READER_INITIALIZING = False
            AR_UR_READER_INIT_ERROR = str(e)
    
    def initialize_en_reader():
        """Initialize English EasyOCR reader at startup (for Tesseract fallback)"""
        global EN_READER, EN_READER_INITIALIZING, EN_READER_INIT_ERROR
        EN_READER_INITIALIZING = True
        EN_READER_INIT_ERROR = None
        try:
            print("  Initializing EasyOCR Reader(['en'], gpu=False, quantize=True)...")
            EN_READER = easyocr.Reader(
                ['en'],
                gpu=False,
                quantize=True
            )
            print("  ✓ EasyOCR Reader initialized successfully for English")
            EN_READER_INITIALIZING = False
        except Exception as e:
            print(f"  ✗ Failed to initialize English EasyOCR Reader: {e}")
            import traceback
            print(f"  Traceback: {traceback.format_exc()}")
            EN_READER = None
            EN_READER_INITIALIZING = False
            EN_READER_INIT_ERROR = str(e)
    
    # Run initialization in background threads to avoid blocking startup
    import threading
    ar_ur_thread = threading.Thread(target=initialize_ar_ur_reader, daemon=True)
    ar_ur_thread.start()
    print("  Arabic/Urdu reader initialization started in background thread...")
    
    en_thread = threading.Thread(target=initialize_en_reader, daemon=True)
    en_thread.start()
    print("  English reader initialization started in background thread...")
else:
    print("⚠ EasyOCR not available - install with: pip install easyocr")

print("=" * 50 + "\n")

if __name__ == '__main__':
    HOTSPOT_IP = '192.168.137.1'
    print(f" * Android devices connect via: http://{HOTSPOT_IP}:5000")
    print("=" * 50 + "\n")
    app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=False, use_debugger=False)


"""One-off: rebuild FAISS indexes + mapping CSVs from the current production DB.

Re-embeds every hadith's English text with text-embedding-3-large (3072-dim,
matching the existing index dimension) and writes fresh IndexFlatL2 files plus
matching mapping CSVs (faiss_index -> hadith_id), replacing the stale ones that
no longer matched the DB content.
"""
import os
import sys
import time

import faiss
import numpy as np
import pandas as pd
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv(override=True)

DB_HOST = os.environ.get("REBUILD_DB_HOST", "127.0.0.1")
DB_PORT = os.environ.get("REBUILD_DB_PORT", "5433")
DB_NAME = os.environ.get("REBUILD_DB_NAME", "hadith_db_2")
DB_USER = os.environ.get("REBUILD_DB_USER", "postgres")
DB_PASSWORD = os.environ["REBUILD_DB_PASSWORD"]

EMBED_MODEL = "text-embedding-3-large"
EMBED_DIM = 3072
BATCH_SIZE = 100

BOOKS = {
    "Sahih al-Bukhari": ("bukhari_faiss.index", "bukhari_mapping.csv"),
    "Sahih Muslim": ("Sahih_Muslim_faiss.index", "Sahih_Muslim_mapping.csv"),
    "Jami at-Tirmidhi": ("tirmizi_faiss.index", "tirmizi_mapping.csv"),
}

OUT_FAISS_DIR = os.path.join("data", "faiss")
OUT_MAPPING_DIR = os.path.join("data", "mapping")

client = OpenAI()


def fetch_hadiths(book_name):
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD
    )
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute(
        """
        SELECT h.hadith_id,
               COALESCE(h.hadith_english, h.hadith_arabic, h.hadith_urdu, '') AS text
        FROM hadiths h
        JOIN hadith_books b ON h.FK_book_id = b.book_id
        WHERE b.book_name_english = %s
        ORDER BY h.hadith_id
        """,
        (book_name,),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [r for r in rows if r["text"].strip()]


def embed_batch(texts, retries=3):
    for attempt in range(retries):
        try:
            resp = client.embeddings.create(
                model=EMBED_MODEL, input=texts, dimensions=EMBED_DIM
            )
            return [np.array(d.embedding, dtype=np.float32) for d in resp.data]
        except Exception as e:
            if attempt == retries - 1:
                raise
            print(f"  retry {attempt + 1} after error: {e}")
            time.sleep(2 * (attempt + 1))


def rebuild_book(book_name, faiss_filename, mapping_filename):
    print(f"\n=== {book_name} ===")
    rows = fetch_hadiths(book_name)
    print(f"Fetched {len(rows)} hadiths with text")

    index = faiss.IndexFlatL2(EMBED_DIM)
    mapping_rows = []

    for start in range(0, len(rows), BATCH_SIZE):
        batch = rows[start:start + BATCH_SIZE]
        texts = [r["text"][:8000] for r in batch]  # guard against extreme outliers
        vecs = embed_batch(texts)
        index.add(np.stack(vecs))
        for i, r in enumerate(batch):
            mapping_rows.append({
                "faiss_index": start + i,
                "hadith_id": r["hadith_id"],
                "chunk_id": start + i + 1,
            })
        print(f"  embedded {min(start + BATCH_SIZE, len(rows))}/{len(rows)}")

    os.makedirs(OUT_FAISS_DIR, exist_ok=True)
    os.makedirs(OUT_MAPPING_DIR, exist_ok=True)
    faiss.write_index(index, os.path.join(OUT_FAISS_DIR, faiss_filename))
    pd.DataFrame(mapping_rows).to_csv(
        os.path.join(OUT_MAPPING_DIR, mapping_filename), index=False
    )
    print(f"Wrote {index.ntotal} vectors -> {faiss_filename} / {mapping_filename}")


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    for book_name, (faiss_filename, mapping_filename) in BOOKS.items():
        if only and only.lower() not in book_name.lower():
            continue
        rebuild_book(book_name, faiss_filename, mapping_filename)


if __name__ == "__main__":
    main()

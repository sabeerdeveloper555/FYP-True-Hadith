# Hadith Search — How It Works

This document explains the end-to-end search pipeline in True Hadith, from the moment a user submits a query to the ranked list of results displayed on screen.

---

## Table of Contents

1. [Input Methods](#1-input-methods)
2. [Query Flow Overview](#2-query-flow-overview)
3. [Backend Search Pipeline](#3-backend-search-pipeline)
   - [3.1 Query Cleaning](#31-query-cleaning)
   - [3.2 Semantic Search (FAISS)](#32-semantic-search-faiss)
   - [3.3 Fuzzy Search](#33-fuzzy-search)
   - [3.4 BM25 Keyword Search](#34-bm25-keyword-search)
   - [3.5 Score Normalisation](#35-score-normalisation)
   - [3.6 Final Blended Ranking](#36-final-blended-ranking)
   - [3.7 Grade Boost](#37-grade-boost)
4. [Result Format](#4-result-format)
5. [Flutter Side](#5-flutter-side)
   - [5.1 ApiService](#51-apiservice)
   - [5.2 ResultPage — Filter Tags](#52-resultpage--filter-tags)
   - [5.3 HadithCard — Match Badge](#53-hadithcard--match-badge)
6. [Why Typed Text vs Image/Audio Differs](#6-why-typed-text-vs-imageaudio-differs)
7. [Data Indexes at a Glance](#7-data-indexes-at-a-glance)
8. [Startup Initialisation](#8-startup-initialisation)

---

## 1. Input Methods

The app supports four ways to submit a search query. All four ultimately produce a plain text string that is sent to the same `/api/search` endpoint.

| Input Method | How text is produced | Typical query length |
|---|---|---|
| **Text** | User types directly | Short (5–20 words) |
| **Voice** | OpenAI Whisper transcription via `/api/transcribe` | Medium (20–60 words) |
| **Image (OCR)** | Tesseract (English) or EasyOCR (Arabic/Urdu) via `/api/ocr/easyocr` | Long (full hadith text, 50–200 words) |
| **Audio clip** | OpenAI Whisper transcription after optional trim | Medium–Long |

> **Why image/audio ranks better than typed text:**  
> OCR and transcription extract the full verbatim hadith text. When that long exact text is embedded and compared to FAISS (which stores embeddings of the same full texts), the cosine similarity is near-perfect. A short typed query is semantically related but not identical, so similarity scores are lower. The BM25 + Fuzzy layers partially compensate for this gap.

---

## 2. Query Flow Overview

```
User Input (text / voice / image / audio)
        │
        ▼
  Flutter App
  ┌─────────────────────────────┐
  │  HomeScreen / VoiceInputPage│
  │  / CropImagePage            │
  │  → ApiService.searchHadiths │
  └─────────────┬───────────────┘
                │  POST /api/search
                │  { user_id, query }
                ▼
  Flask Backend
  ┌──────────────────────────────────────────────┐
  │  1. Clean & normalise query                  │
  │  2. OpenAI embedding  →  FAISS (×3 indexes)  │
  │  3. Fuzzy search (always, in parallel)       │
  │  4. BM25 keyword scoring                     │
  │  5. Normalise + blend scores                 │
  │  6. Grade boost                              │
  │  7. Fetch hadith rows from PostgreSQL        │
  │  8. Return ranked results + similarity_score │
  └──────────────────────────────────────────────┘
                │
                ▼
  Flutter App
  ┌──────────────────────────────┐
  │  ResultPage (filter by book) │
  │  HadithCard (match badge)    │
  └──────────────────────────────┘
```

---

## 3. Backend Search Pipeline

**Entry point:** `POST /api/search` in `backend_api_example.py`

### 3.1 Query Cleaning

```python
normalized_query = normalize_arabic_text(query)   # strips tashkeel, normalises alef forms
cleaned_query    = clean_text(normalized_query)    # removes punctuation, extra whitespace
```

- Arabic/Urdu queries go through `normalize_arabic_text` first to strip diacritics (tashkeel) and normalise different forms of the same letter (e.g. أ / إ / آ → ا).
- `clean_text` then removes punctuation and collapses whitespace.
- If the cleaned result is empty, the original raw query is used as a fallback.

---

### 3.2 Semantic Search (FAISS)

FAISS (Facebook AI Similarity Search) stores pre-computed vector embeddings for every hadith. At search time the query is embedded using the same model and the nearest vectors are retrieved.

**Embedding model:** `text-embedding-3-large` (OpenAI)  
**Candidate pool:** `k = 20` results per index (previously 10)

Three separate FAISS indexes are searched in parallel:

| Index | File | Book |
|---|---|---|
| `bukhari_index` | `data/faiss/bukhari_faiss.index` | Sahih Bukhari |
| `tirmizi_index` | `data/faiss/tirmizi_faiss.index` | Jami' at-Tirmidhi |
| `muslim_index`  | `data/faiss/Sahih_Muslim_faiss.index` | Sahih Muslim |

Each index returns distances and vector positions. Positions are mapped to `hadith_id` values using a CSV mapping file:

```
bukhari_mapping.csv   →  faiss_index ↔ hadith_id
tirmizi_mapping.csv   →  faiss_index ↔ hadith_id
Sahih_Muslim_mapping.csv → faiss_index ↔ hadith_id
```

**Score direction:**
- L2 distance index: lower distance = better match
- Inner product index: higher value = better match → negated so lower = better

---

### 3.3 Fuzzy Search

`fuzzy_search_hadiths()` uses `rapidfuzz` to compare the query against stored Arabic, English, and Urdu text using three scoring functions:

```python
score = max(
    fuzz.partial_ratio(query, text),      # handles substrings
    fuzz.ratio(query, text),              # overall similarity
    fuzz.token_sort_ratio(query, text),   # order-independent word match
)
```

- Searches all three text fields per hadith.
- Minimum similarity threshold: **60 / 100**.
- Returns up to **15 candidates**.
- **Always runs** alongside FAISS (previously only ran when FAISS found fewer than 3 results).
- Fuzzy-only candidates (not found by FAISS) are added to the pool with a neutral FAISS score of `1.0`.

---

### 3.4 BM25 Keyword Search

BM25 (Best Match 25) is a classic information retrieval algorithm. It ranks documents by how often query terms appear, weighted by term rarity across the corpus (inverse document frequency).

**Library:** `rank-bm25` (`pip install rank-bm25`)  
**Built at startup** from all hadith English text in PostgreSQL.

```python
bm25_index   = BM25Okapi(tokenized_corpus)
bm25_hadith_ids = [hadith_id, ...]   # ordered list matching corpus rows
```

At search time:

```python
tokens = cleaned_query.lower().split()
raw_scores = bm25_index.get_scores(tokens)   # one score per hadith in corpus
```

BM25 is particularly effective for **short typed queries** because it rewards exact keyword matches — something FAISS (which is purely semantic) can miss when the query is brief.

---

### 3.5 Score Normalisation

Before blending, every signal is normalised to the range **[0, 1]** so they are directly comparable.

**FAISS — per-index min-max normalisation:**

```python
norm = (score - min_score) / (max_score - min_score)
# 0 = best match, 1 = worst match
```

Each index is normalised independently before scores are merged. When the same hadith appears in multiple indexes, the best (lowest) normalised score is kept.

**BM25 — divide by max:**

```python
bm25_norm = raw_score / max_raw_score
# 0 = no keyword match, 1 = best keyword match
```

**Fuzzy — divide by max:**

```python
fuzzy_norm = raw_similarity / max_raw_similarity
# 0 = no match, 1 = best fuzzy match
```

---

### 3.6 Final Blended Ranking

All three normalised signals are combined into a single score. Since lower = better for the final sort, BM25 and Fuzzy scores (where higher = better) are inverted.

```python
final_score = (
    0.50 * faiss_norm          +   # semantic meaning
    0.30 * (1.0 - bm25_norm)  +   # keyword match (inverted)
    0.20 * (1.0 - fuzzy_norm) +   # fuzzy character match (inverted)
    grade_delta                    # grade boost (see below)
)
```

| Signal | Weight | Direction | Strength |
|---|---|---|---|
| FAISS semantic | 50% | lower = better | Best for long / paraphrase queries |
| BM25 keyword | 30% | higher = better (inverted) | Best for short / exact keyword queries |
| Fuzzy | 20% | higher = better (inverted) | Best for typos / transliteration variants |

Results are sorted ascending by `final_score` — the hadith with the lowest score appears first.

---

### 3.7 Grade Boost

Hadiths with stronger authentication grades receive a score adjustment applied before the final sort:

| Grade | Adjustment | Effect |
|---|---|---|
| Sahih (authentic) | −0.10 | Pushed higher in results |
| Hasan (good) | −0.05 | Slightly higher |
| Da'if (weak) | +0.05 | Pushed lower in results |
| Other / unknown | 0.00 | No change |

The boost is intentionally small so it refines rather than overrides relevance — a highly relevant Da'if hadith still ranks above a weakly relevant Sahih one.

---

## 4. Result Format

The `/api/search` endpoint returns:

```json
{
  "results": [
    {
      "hadith_id": 1234,
      "book_name": "Sahih Bukhari",
      "hadith_number": "6311",
      "chapter_number": "80",
      "grade": "Sahih",
      "similarity_score": 0.87
    }
  ]
}
```

`similarity_score` is derived from the normalised FAISS score:

```python
similarity_score = round(1.0 - hadith_score_map[hadith_id], 4)
# 1.0 = perfect match, 0.0 = least relevant
```

---

## 5. Flutter Side

### 5.1 ApiService

`lib/services/api_service.dart` — `searchHadiths()`

- Sends `POST /api/search` with `{ user_id, query }`.
- Parses the response into a `List<HadithSummary>`.
- Maps `similarity_score` from the JSON into `HadithSummary.similarityScore`.

```dart
HadithSummary(
  hadithId: item['hadith_id'],
  bookName: item['book_name'],
  hadithNumber: item['hadith_number'].toString(),
  chapterNumber: item['chapter_number'].toString(),
  grade: item['grade'] ?? 'No grade mention',
  similarityScore: (item['similarity_score'] as num?)?.toDouble(),
)
```

The list arrives **pre-ranked** from the backend. The app does not re-sort it.

---

### 5.2 ResultPage — Filter Tags

`lib/screens/result_page.dart`

The `ResultPage` displays the ranked list and provides horizontal filter chips to narrow results by book:

| Tag | Matches book names containing |
|---|---|
| All | (no filter) |
| Sahih Bukhari | `bukhari` |
| Sahih Muslim | `muslim` |
| Jami-at-Tirmizi | `tirmidhi` or `tirmizi` |

Filtering preserves the backend rank order — it only hides hadiths from other books, it does not re-rank.

---

### 5.3 HadithCard — Match Badge

`lib/widgets/hadith_card.dart`

When `similarityScore` is present, a coloured badge is shown next to the grade:

```
[ 87% match ]  Sahih
```

- Score is multiplied by 100 and rounded to the nearest integer.
- Badge only appears on search results (not bookmarks or history).
- Colour uses `AppColors.primary` at 12% opacity for the background.

---

## 6. Why Typed Text vs Image/Audio Differs

| Scenario | Query sent to backend | FAISS similarity |
|---|---|---|
| User types "prayer intention" | 2-word phrase | Moderate — semantically related but short |
| OCR on hadith image | Full 80-word Arabic/English hadith text | Very high — near-exact match to stored embedding |
| Whisper audio transcription | Full spoken hadith (20–60 words) | High — long text captures meaning richly |

The BM25 (30%) and Fuzzy (20%) layers are specifically introduced to compensate for the gap caused by short typed queries, boosting results that match the query keywords exactly even when the semantic vector distance is not ideal.

---

## 7. Data Indexes at a Glance

```
data/
├── faiss/
│   ├── bukhari_faiss.index          ← FAISS vector index (Bukhari)
│   ├── tirmizi_faiss.index          ← FAISS vector index (Tirmizi)
│   └── Sahih_Muslim_faiss.index     ← FAISS vector index (Muslim)
└── mapping/
    ├── bukhari_mapping.csv          ← faiss_index ↔ hadith_id
    ├── tirmizi_mapping.csv          ← faiss_index ↔ hadith_id
    └── Sahih_Muslim_mapping.csv     ← faiss_index ↔ hadith_id
```

The BM25 index is **not persisted to disk** — it is rebuilt from PostgreSQL every time the server starts. This ensures it stays in sync with the database.

---

## 8. Startup Initialisation

When the Flask server starts, the following sequence runs:

```
1. get_firebase_app()          — Firebase Admin SDK for push notifications
2. load_faiss_indexes()        — Load 3 FAISS .index files into memory
3. load_mapping_csvs()         — Load 3 mapping CSV files into pandas DataFrames
4. build_bm25_index()          — Query all hadith English text from PostgreSQL,
                                 tokenise, build BM25Okapi in memory
5. initialize_ar_ur_reader()   — EasyOCR Arabic/Urdu reader (background thread)
6. initialize_en_reader()      — EasyOCR English reader (background thread)
```

The BM25 index typically builds in 2–5 seconds depending on corpus size and database speed. If `rank-bm25` is not installed, step 4 is skipped and a warning is printed — the search still works using FAISS + Fuzzy only.

**Install requirement:**
```bash
pip install rank-bm25
```

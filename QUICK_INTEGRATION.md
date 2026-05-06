# Quick Integration Steps

## What You Have:
✅ Database backup file  
✅ FAISS index files (bukhari.index, tirmizi.index)  
✅ Mapping CSV files (bukhari_mapping.csv, tirmizi_mapping.csv)

---

## Step 1: Restore Database (5 minutes)

Open PowerShell and run:

```powershell
# Replace "path/to/backup" with actual path to your backup file
pg_restore -U postgres -d true_hadith_db "path/to/true_hadith_db.backup"
```

**Example:**
```powershell
pg_restore -U postgres -d true_hadith_db "C:\Users\M.M\Downloads\true_hadith_db.backup"
```

---

## Step 2: Create Folders (2 minutes)

In your project folder (`C:\Users\M.M\Documents\true hadith\`):

1. Create folder: `data`
2. Inside `data`, create folder: `faiss`
3. Inside `data`, create folder: `mapping`

**Final structure should be:**
```
true hadith/
├── data/
│   ├── faiss/
│   └── mapping/
```

---

## Step 3: Copy Files (1 minute)

1. Copy `bukhari.index` → `data/faiss/bukhari.index`
2. Copy `tirmizi.index` → `data/faiss/tirmizi.index`
3. Copy `bukhari_mapping.csv` → `data/mapping/bukhari_mapping.csv`
4. Copy `tirmizi_mapping.csv` → `data/mapping/tirmizi_mapping.csv`

---

## Step 4: Install Python Packages (3 minutes)

Open terminal in project folder and run:

```powershell
pip install -r requirements.txt
```

This will install:
- flask, flask-cors, psycopg2-binary, python-dotenv
- faiss-cpu (for FAISS search)
- openai (for embeddings)
- pandas, numpy (for CSV handling)

---

## Step 5: Set OpenAI API Key (2 minutes)

1. Create `.env` file in project root (same folder as `backend_api_example.py`)
2. Add this line:

```env
DB_HOST=localhost
DB_NAME=true_hadith_db
DB_USER=postgres
DB_PASSWORD=your_password
DB_PORT=5432
OPENAI_API_KEY=sk-your-openai-key-here
```

---

## Step 6: Test Everything (2 minutes)

1. **Start PostgreSQL** (make sure it's running)

2. **Start Backend:**
```powershell
python backend_api_example.py
```

3. **Check Output:**
You should see:
```
==================================================
Loading FAISS indexes and mapping files...
==================================================
✓ Loaded Bukhari FAISS index: data/faiss/bukhari.index
✓ Loaded Tirmizi FAISS index: data/faiss/tirmizi.index
✓ Loaded Bukhari mapping CSV: data/mapping/bukhari_mapping.csv
✓ Loaded Tirmizi mapping CSV: data/mapping/tirmizi_mapping.csv
==================================================
```

4. **Test Health Endpoint:**
Open browser: `http://localhost:5000/api/health`

Should show JSON with `"status": "ok"` and FAISS status.

---

## ✅ Done!

Your backend is now ready to:
- Search hadiths using FAISS semantic similarity
- Return results from PostgreSQL database
- Save search history

---

## Troubleshooting

**"FAISS index not found"?**
→ Check files are in `data/faiss/` folder with exact names

**"Mapping CSV not found"?**
→ Check files are in `data/mapping/` folder with exact names

**"Database connection error"?**
→ Check PostgreSQL is running and `.env` has correct DB password

**"OpenAI API error"?**
→ Check `.env` has valid `OPENAI_API_KEY`


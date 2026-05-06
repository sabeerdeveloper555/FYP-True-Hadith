# Integration Guide - FAISS, Mapping Files & Database Backup

## Step-by-Step Instructions

### Step 1: Restore Database Backup

1. **Make sure PostgreSQL is running** on your PC

2. **Open PowerShell/Terminal** and run:

```powershell
# Create the database (if it doesn't exist)
createdb -U postgres true_hadith_db

# Restore the backup file
pg_restore -U postgres -d true_hadith_db "path/to/true_hadith_db.backup"
```

**Example:**
If your backup file is in `C:\Users\M.M\Downloads\true_hadith_db.backup`:

```powershell
pg_restore -U postgres -d true_hadith_db "C:\Users\M.M\Downloads\true_hadith_db.backup"
```

3. **Verify** - Connect to PostgreSQL and check:
```sql
SELECT COUNT(*) FROM hadiths;
SELECT COUNT(*) FROM hadith_books;
```

---

### Step 2: Create Folder Structure for FAISS & Mapping Files

In your project root (`C:\Users\M.M\Documents\true hadith\`), create these folders:

```
true hadith/
├── data/
│   ├── faiss/
│   │   ├── bukhari.index
│   │   └── tirmizi.index
│   └── mapping/
│       ├── bukhari_mapping.csv
│       └── tirmizi_mapping.csv
```

**How to create:**
- Right-click in your project folder → New Folder → name it `data`
- Inside `data`, create `faiss` folder
- Inside `data`, create `mapping` folder

---

### Step 3: Copy Files to Correct Locations

1. **FAISS Index Files:**
   - Copy `bukhari.index` → `data/faiss/bukhari.index`
   - Copy `tirmizi.index` → `data/faiss/tirmizi.index`

2. **Mapping CSV Files:**
   - Copy `bukhari_mapping.csv` → `data/mapping/bukhari_mapping.csv`
   - Copy `tirmizi_mapping.csv` → `data/mapping/tirmizi_mapping.csv`

---

### Step 4: Update Backend Code

The backend code will be updated to load these files. See `backend_api_example.py` for the updated code.

---

### Step 5: Test Everything

1. **Start PostgreSQL** (make sure it's running)

2. **Start Backend:**
```powershell
python backend_api_example.py
```

3. **Check if files are loaded:**
   - Look at backend terminal - it should show "FAISS indexes loaded" or similar
   - If you see errors about file paths, check Step 3 again

4. **Test Search:**
   - Open Flutter app
   - Try a search query
   - Should return results from database

---

## Troubleshooting

### Database restore fails?
- Make sure PostgreSQL is running
- Check database name matches: `true_hadith_db`
- Try: `dropdb -U postgres true_hadith_db` then create again

### FAISS files not found?
- Check file paths in `backend_api_example.py`
- Make sure files are in `data/faiss/` folder
- Check file names match exactly (case-sensitive)

### Mapping CSV not found?
- Check file paths in `backend_api_example.py`
- Make sure files are in `data/mapping/` folder
- Check CSV has correct columns: `row_index, chunk_id, hadith_id`


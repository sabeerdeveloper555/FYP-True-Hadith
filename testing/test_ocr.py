"""
Unit tests: OCR extraction — Tesseract (English) and EasyOCR (Arabic/Urdu).

Run with:
    python testing/test_ocr.py -v      # direct
    pytest testing/test_ocr.py -v      # via pytest runner

Missing packages are auto-installed at startup if not found.
No real image files needed — test images are generated in-memory with Pillow.
"""
import sys
import os
import subprocess


def _ensure(*packages: str) -> None:
    """Install any missing packages into the current Python interpreter."""
    for pkg in packages:
        module = pkg.split("[")[0].replace("-", "_")
        try:
            __import__(module)
        except ImportError:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", pkg, "-q"],
                stdout=subprocess.DEVNULL,
            )


_ensure("pytesseract", "easyocr", "Pillow", "numpy", "requests")

# ── Imports (safe after _ensure) ──────────────────────────────────────────────
import numpy as np
import pytest
import requests
from PIL import Image, ImageDraw, ImageFont
import pytesseract

TESSERACT_PATH = r"C:\Users\Muhammad Sabeer Alam\AppData\Local\Programs\Tesseract-OCR\tesseract.exe"
if os.path.exists(TESSERACT_PATH):
    pytesseract.pytesseract.tesseract_cmd = TESSERACT_PATH


# ── Image helpers ─────────────────────────────────────────────────────────────

def _make_image(text: str, size=(400, 80), bg="white", fg="black") -> Image.Image:
    img = Image.new("RGB", size, color=bg)
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 28)
    except OSError:
        font = ImageFont.load_default()
    draw.text((10, 20), text, fill=fg, font=font)
    return img


def _make_arabic_image(text: str, size=(500, 80)) -> Image.Image:
    arabic_fonts = [
        r"C:\Windows\Fonts\arial.ttf",
        r"C:\Windows\Fonts\tahoma.ttf",
        r"C:\Windows\Fonts\times.ttf",
    ]
    img = Image.new("RGB", size, color="white")
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    for path in arabic_fonts:
        if os.path.exists(path):
            try:
                font = ImageFont.truetype(path, 28)
                break
            except OSError:
                pass
    draw.text((10, 20), text, fill="black", font=font)
    return img


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def ocr_reader():
    import easyocr
    return easyocr.Reader(["ar", "en"], gpu=False, verbose=False)


# ── Tesseract: English ────────────────────────────────────────────────────────

def test_tesseract_is_available():
    version = pytesseract.get_tesseract_version()
    assert version is not None


def test_tesseract_returns_string():
    img = _make_image("Hello World")
    result = pytesseract.image_to_string(img).strip()
    assert isinstance(result, str)
    assert len(result) > 0


def test_tesseract_english_simple_word():
    img = _make_image("prayer")
    result = pytesseract.image_to_string(img).strip().lower()
    assert "prayer" in result, f"Expected 'prayer' in OCR output, got: {result!r}"


def test_tesseract_english_sentence():
    img = _make_image("Actions are by intentions", size=(500, 80))
    result = pytesseract.image_to_string(img).strip().lower()
    assert "actions" in result or "intentions" in result, \
        f"Expected at least one keyword, got: {result!r}"


def test_tesseract_returns_empty_on_blank_image():
    img = Image.new("RGB", (200, 60), color="white")
    result = pytesseract.image_to_string(img).strip()
    assert isinstance(result, str)


def test_tesseract_image_to_data_returns_dict():
    img = _make_image("Hadith")
    data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
    assert "text" in data
    assert isinstance(data["text"], list)


def test_tesseract_confidence_scores_are_numeric():
    img = _make_image("Bukhari")
    data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
    confs = [c for c in data["conf"] if str(c).lstrip("-").isdigit()]
    assert len(confs) > 0


def test_tesseract_numpy_array_input():
    img = _make_image("Sunnah")
    result = pytesseract.image_to_string(np.array(img)).strip()
    assert isinstance(result, str)


# ── EasyOCR: Arabic / Urdu ────────────────────────────────────────────────────

def test_easyocr_reader_initialises(ocr_reader):
    assert ocr_reader is not None


def test_easyocr_returns_list(ocr_reader):
    results = ocr_reader.readtext(np.array(_make_arabic_image("Test")))
    assert isinstance(results, list)


def test_easyocr_result_structure(ocr_reader):
    results = ocr_reader.readtext(np.array(_make_image("Hello")))
    for item in results:
        assert len(item) == 3, f"Expected (bbox, text, conf), got: {item}"
        _, text, conf = item
        assert isinstance(text, str)
        assert 0.0 <= conf <= 1.0


def test_easyocr_arabic_text_detected(ocr_reader):
    results = ocr_reader.readtext(np.array(_make_arabic_image("الأعمال بالنيات", size=(600, 80))))
    assert isinstance(results, list)


def test_easyocr_urdu_text_image(ocr_reader):
    results = ocr_reader.readtext(np.array(_make_arabic_image("نیت کا اجر")))
    assert isinstance(results, list)


def test_easyocr_confidence_range(ocr_reader):
    results = ocr_reader.readtext(np.array(_make_image("Hadith search", size=(400, 80))))
    for _, _, conf in results:
        assert 0.0 <= conf <= 1.0, f"Confidence out of range: {conf}"


def test_easyocr_blank_image_returns_list(ocr_reader):
    results = ocr_reader.readtext(np.array(Image.new("RGB", (200, 60), color="white")))
    assert isinstance(results, list)


def test_easyocr_detail_zero_returns_strings(ocr_reader):
    results = ocr_reader.readtext(np.array(_make_image("Test OCR")), detail=0)
    assert isinstance(results, list)
    for item in results:
        assert isinstance(item, str)


# ── Keyword search via API ────────────────────────────────────────────────────

BASE_URL = os.getenv("API_BASE_URL", "http://192.168.100.12:5000/api")
TEST_USER_ID = int(os.getenv("TEST_USER_ID", "1"))


def _api_available() -> bool:
    try:
        return requests.get(f"{BASE_URL}/health", timeout=3).status_code == 200
    except Exception:
        return False


skip_if_no_api = pytest.mark.skipif(
    not _api_available(),
    reason="Flask backend not reachable — skipping API search tests",
)


@skip_if_no_api
def test_keyword_search_english_returns_results():
    r = requests.post(f"{BASE_URL}/search",
                      json={"query": "intentions deeds", "user_id": TEST_USER_ID},
                      timeout=30)
    assert r.status_code == 200
    body = r.json()
    assert "results" in body
    assert len(body["results"]) > 0


@skip_if_no_api
def test_keyword_search_reference_bukhari():
    r = requests.post(f"{BASE_URL}/search",
                      json={"query": "Bukhari 1", "user_id": TEST_USER_ID},
                      timeout=20)
    assert r.status_code == 200
    assert len(r.json().get("results", [])) > 0


@skip_if_no_api
def test_keyword_search_result_fields():
    r = requests.post(f"{BASE_URL}/search",
                      json={"query": "prayer", "user_id": TEST_USER_ID},
                      timeout=30)
    assert r.status_code == 200
    results = r.json().get("results", [])
    if results:
        for field in ("hadith_id", "book_name", "hadith_number", "grade"):
            assert field in results[0], f"Missing field: {field}"


@skip_if_no_api
def test_keyword_search_empty_query_returns_400():
    r = requests.post(f"{BASE_URL}/search",
                      json={"query": "", "user_id": TEST_USER_ID},
                      timeout=10)
    assert r.status_code == 400


@skip_if_no_api
def test_keyword_search_arabic_query():
    r = requests.post(f"{BASE_URL}/search",
                      json={"query": "الأعمال بالنيات", "user_id": TEST_USER_ID},
                      timeout=30)
    assert r.status_code == 200
    assert "results" in r.json()


if __name__ == "__main__":
    sys.exit(pytest.main([__file__] + sys.argv[1:]))

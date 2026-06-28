FROM python:3.10-slim

# 1. System dependencies install karein (EasyOCR aur OpenCV ke liye zaroori hain)
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 2. App directory banayein
WORKDIR /code

# 3. requirements.txt copy aur install karein
COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r /code/requirements.txt

# 4. Baqi saara code copy karein
COPY . .

# 5. Hugging Face default port 7860 use karta hai, gunicorn se run karein
CMD ["gunicorn", "-b", "0.0.0.0:7860", "backend_api_example:app"]
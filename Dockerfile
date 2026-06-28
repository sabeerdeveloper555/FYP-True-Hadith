FROM python:3.10-slim

WORKDIR /code

# Purane package 'libgl1-mesa-glx' ki jagah 'libgl1' use kiya hai jo crash nahi hoga
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY ./requirements.txt /code/requirements.txt

RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r /code/requirements.txt

COPY . .

CMD ["python", "backend_api_example.py"]
from openai import OpenAI
from dotenv import load_dotenv
import time

load_dotenv()
c = OpenAI()
print("Sending to Whisper API...")
start = time.time()
result = c.audio.transcriptions.create(
    model="whisper-1",
    file=open(r"E:\WhatsApp Audio 2026-05-13 at 11.01.26 AM.mpeg", "rb"),
    response_format="text",
)
print(f"Done in {time.time() - start:.1f}s")
print("Transcript:", result)

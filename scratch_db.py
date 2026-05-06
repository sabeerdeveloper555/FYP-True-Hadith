import psycopg2
import os
from dotenv import load_dotenv

load_dotenv(override=True)
conn = psycopg2.connect(
    host=os.getenv('DB_HOST'),
    database=os.getenv('DB_NAME'),
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD'),
    port=os.getenv('DB_PORT')
)
cursor = conn.cursor()
cursor.execute("ALTER TABLE bookmark RENAME COLUMN created_id TO created_at;")
conn.commit()
print("Successfully renamed column")

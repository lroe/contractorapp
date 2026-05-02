import sqlalchemy
from sqlalchemy import create_engine
import os
from dotenv import load_dotenv

load_dotenv()
url = os.getenv("DATABASE_URL")
try:
    engine = create_engine(url)
    with engine.connect() as conn:
        print("Successfully connected to the database!")
except Exception as e:
    print(f"Connection failed: {e}")

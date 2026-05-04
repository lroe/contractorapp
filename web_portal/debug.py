import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.database import SessionLocal
from app import models
db = SessionLocal()
users = db.query(models.User).all()
for u in users:
    print(u.email, u.role, u.google_id)

import bcrypt
import sys
import os

# Add the parent directory to sys.path to import app
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.database import SessionLocal
from app import models

def get_password_hash(password):
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def add_users():
    db = SessionLocal()
    
    new_users = [
        {"name": "James Stark", "phone": "7994788157", "role": "owner", "pass": "pass123"},
        {"name": "Ramesh", "phone": "7994788156", "role": "supervisor", "pass": "pass123"},
    ]

    for u in new_users:
        # Check if user already exists
        existing_user = db.query(models.User).filter(models.User.phone == u["phone"]).first()
        if existing_user:
            print(f"User with phone {u['phone']} already exists.")
            continue
            
        db_user = models.User(
            name=u["name"],
            phone=u["phone"],
            role=u["role"],
            password_hash=get_password_hash(u["pass"]),
            is_active=True
        )
        db.add(db_user)
        print(f"Added user: {u['name']} ({u['role']})")
    
    db.commit()
    db.close()

if __name__ == "__main__":
    add_users()

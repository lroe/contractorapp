import bcrypt
import sys
import os

# Add the parent directory to sys.path to import app
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.database import SessionLocal
from app import models

def get_password_hash(password):
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def add_user():
    db = SessionLocal()
    
    u = {"name": "Suhail", "phone": "7994788159", "role": "owner", "pass": "pass123"}

    # Check if user already exists
    existing_user = db.query(models.User).filter(models.User.phone == u["phone"]).first()
    if existing_user:
        print(f"User with phone {u['phone']} already exists.")
        db.close()
        return
        
    db_user = models.User(
        name=u["name"],
        phone=u["phone"],
        role=u["role"],
        password_hash=get_password_hash(u["pass"]),
        is_active=True
    )
    db.add(db_user)
    db.commit()
    print(f"Added user: {u['name']} ({u['role']}) with phone {u['phone']}")
    db.close()

if __name__ == "__main__":
    add_user()

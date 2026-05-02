from sqlalchemy.orm import Session
from app.database import SessionLocal, engine
from app import models, crud
from passlib.context import CryptContext

import bcrypt

def get_password_hash(password):
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def seed():
    db = SessionLocal()
    
    # Check if users already exist
    if db.query(models.User).count() > 0:
        print("Users already exist. Skipping seed.")
        return

    users = [
        {"name": "Contractor Owner", "phone": "1234567890", "role": "owner", "pass": "pass123"},
        {"name": "Supervisor One", "phone": "1111111111", "role": "supervisor", "pass": "pass123"},
        {"name": "Supervisor Two", "phone": "2222222222", "role": "supervisor", "pass": "pass123"},
    ]

    for u in users:
        db_user = models.User(
            name=u["name"],
            phone=u["phone"],
            role=u["role"],
            password_hash=get_password_hash(u["pass"]),
            is_active=True
        )
        db.add(db_user)
    
    db.commit()
    print("Seeded 3 users successfully.")
    db.close()

if __name__ == "__main__":
    seed()

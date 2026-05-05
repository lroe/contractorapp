#!/usr/bin/env python3
"""
Script to add phone number to existing user.
Usage: python add_phone.py
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app import models

def main():
    db = SessionLocal()
    
    # Find the user by email
    user = db.query(models.User).filter(models.User.email == "123@gmail.com").first()
    if not user:
        print("❌ User with email '123@gmail.com' not found.")
        return
    
    # Update phone number
    user.phone = "1234567890"
    db.commit()
    
    print(f"✅ Added phone number '1234567890' to user: {user.email} (ID: {user.id})")
    
    db.close()

if __name__ == "__main__":
    main()
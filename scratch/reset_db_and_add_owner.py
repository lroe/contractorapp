#!/usr/bin/env python3
"""
Script to reset the database and add an owner user with username '123' and password 'pass123'.
Usage: python reset_db_and_add_owner.py
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal, engine
from app import models, schemas, crud

def main():
    # Reset database
    print("⚠️  WARNING: This will DELETE ALL DATA!")
    print("⚠️  This operation cannot be undone.")
    response = input("Type 'reset-all' to confirm: ")
    
    if response != "reset-all":
        print("❌ Reset cancelled.")
        return
    
    print("Dropping all tables...")
    models.Base.metadata.drop_all(bind=engine)
    
    print("Creating all tables...")
    models.Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    
    # Create organization
    org_data = schemas.OrganizationCreate(name="Guidee Constructions")
    org = crud.create_organization(db, org_data)
    print(f"✅ Created organization: {org.name} (ID: {org.id})")
    
    # Create owner user
    user_data = schemas.UserCreate(
        organization_id=org.id,
        name="Owner",
        email="123@gmail.com",  # Using email as username
        password="pass123",
        role="owner",
        auth_provider="local"
    )
    user = crud.create_user(db, user_data)
    print(f"✅ Created owner user: {user.email} (ID: {user.id})")
    
    db.close()
    print("✅ Database reset and owner user added successfully!")

if __name__ == "__main__":
    main()
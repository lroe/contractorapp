#!/usr/bin/env python3
"""
Script to create a new organization.
Usage: python create_org.py <organization_name>
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app import models
import uuid

def create_organization(name: str):
    """
    Create a new organization with the given name.
    """
    db = SessionLocal()
    try:
        # Check if organization with this name already exists
        existing = db.query(models.Organization).filter(models.Organization.name == name).first()
        if existing:
            print(f"❌ Organization with name '{name}' already exists (ID: {existing.id}).")
            return existing.id

        # Create new organization
        org = models.Organization(name=name)
        db.add(org)
        db.commit()
        db.refresh(org)

        print("✅ Successfully created organization:")
        print(f"   Name: {org.name}")
        print(f"   ID: {org.id}")

        return org.id

    except Exception as e:
        db.rollback()
        print(f"❌ Error creating organization: {e}")
        return None
    finally:
        db.close()

def main():
    if len(sys.argv) != 2:
        print("Usage: python create_org.py <organization_name>")
        print("Example: python create_org.py 'ABC Construction'")
        sys.exit(1)

    name = sys.argv[1]

    print(f"Creating organization '{name}'...")

    org_id = create_organization(name)
    if org_id:
        print(f"\n💡 To set an owner, run:")
        print(f"   python scratch/set_owner.py <email> {org_id}")
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Script to set a user as the owner of a specific organization.
Usage: python set_owner.py <email> <organization_id>
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app import models

def set_user_as_owner(email: str, organization_id: str):
    """
    Set a user with the given email as the owner of the specified organization.
    """
    db = SessionLocal()
    try:
        # Find the user by email
        user = db.query(models.User).filter(models.User.email == email).first()
        if not user:
            print(f"❌ User with email '{email}' not found.")
            return False

        # Find the organization
        org = db.query(models.Organization).filter(models.Organization.id == organization_id).first()
        if not org:
            print(f"❌ Organization with ID '{organization_id}' not found.")
            return False

        # Update user's organization and role
        user.organization_id = organization_id
        user.role = 'owner'

        db.commit()
        db.refresh(user)

        print("✅ Successfully set user as owner:")
        print(f"   Email: {user.email}")
        print(f"   Name: {user.name}")
        print(f"   Organization: {org.name} ({org.id})")
        print(f"   Role: {user.role}")

        return True

    except Exception as e:
        db.rollback()
        print(f"❌ Error setting user as owner: {e}")
        return False
    finally:
        db.close()

def main():
    if len(sys.argv) != 3:
        print("Usage: python set_owner.py <email> <organization_id>")
        print("Example: python set_owner.py owner@example.com 12345678-1234-1234-1234-123456789abc")
        sys.exit(1)

    email = sys.argv[1]
    organization_id = sys.argv[2]

    print(f"Setting user '{email}' as owner of organization '{organization_id}'...")

    success = set_user_as_owner(email, organization_id)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
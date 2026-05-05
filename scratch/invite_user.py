#!/usr/bin/env python3
"""
Script to invite a user to an organization.
Usage: python invite_user.py <email> <role> <organization_id> [name]
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app import models
from app.schemas import UserInvite
import uuid

def invite_user(email: str, role: str, organization_id: str, name: str = "Invited User"):
    """
    Invite a user to an organization by creating a placeholder user record.
    """
    db = SessionLocal()
    try:
        # Validate role
        valid_roles = ['owner', 'supervisor', 'material_manager']
        if role not in valid_roles:
            print(f"❌ Invalid role '{role}'. Valid roles: {', '.join(valid_roles)}")
            return False

        # Check if organization exists
        org = db.query(models.Organization).filter(models.Organization.id == organization_id).first()
        if not org:
            print(f"❌ Organization with ID '{organization_id}' not found.")
            return False

        # Check if user already exists
        existing_user = db.query(models.User).filter(models.User.email == email).first()
        if existing_user:
            if existing_user.organization_id == organization_id:
                print(f"❌ User '{email}' is already a member of this organization.")
                return False
            elif existing_user.organization_id:
                print(f"❌ User '{email}' is already a member of another organization.")
                return False
            else:
                # User exists but not in any org, add them
                existing_user.organization_id = organization_id
                existing_user.role = role
                if name != "Invited User":
                    existing_user.name = name
                db.commit()
                db.refresh(existing_user)
                print("✅ Successfully invited existing user:")
                print(f"   Email: {existing_user.email}")
                print(f"   Name: {existing_user.name}")
                print(f"   Organization: {org.name} ({org.id})")
                print(f"   Role: {existing_user.role}")
                return True

        # Create invite object
        invite = UserInvite(
            email=email,
            role=role,
            organization_id=organization_id,
            name=name
        )

        # Create new user (placeholder for pre-signup invite)
        new_user = models.User(
            organization_id=invite.organization_id,
            name=invite.name,
            email=invite.email,
            role=invite.role,
            auth_provider="google"  # Assume they will login with Google
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        print("✅ Successfully invited user:")
        print(f"   Email: {new_user.email}")
        print(f"   Name: {new_user.name}")
        print(f"   Organization: {org.name} ({org.id})")
        print(f"   Role: {new_user.role}")
        print("   Note: This is a placeholder record. User will be activated when they sign up with Google.")

        return True

    except Exception as e:
        db.rollback()
        print(f"❌ Error inviting user: {e}")
        return False
    finally:
        db.close()

def main():
    if len(sys.argv) < 4 or len(sys.argv) > 5:
        print("Usage: python invite_user.py <email> <role> <organization_id> [name]")
        print("Example: python invite_user.py user@example.com supervisor c6880ff5-b719-454c-9cc8-539cc900965d 'John Doe'")
        print("Valid roles: owner, supervisor, material_manager")
        sys.exit(1)

    email = sys.argv[1]
    role = sys.argv[2]
    organization_id = sys.argv[3]
    name = sys.argv[4] if len(sys.argv) > 4 else "Invited User"

    success = invite_user(email, role, organization_id, name)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
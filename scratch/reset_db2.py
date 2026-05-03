import bcrypt
import uuid
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.database import SessionLocal, engine
from app import models




def get_password_hash(password):
    return bcrypt.hashpw(
        password.encode("utf-8"),
        bcrypt.gensalt()
    ).decode("utf-8")


def reset_database():
    db = SessionLocal()

    print("Dropping all tables...")
    models.Base.metadata.drop_all(bind=engine)

    print("Recreating all tables...")
    models.Base.metadata.create_all(bind=engine)

    print("Database schema reset complete.\n")

    # Create Organizations
    org1 = models.Organization(
        id=uuid.uuid4(),
        name="Lroe Construction"
    )

    org2 = models.Organization(
        id=uuid.uuid4(),
        name="Global Builders"
    )

    db.add_all([org1, org2])
    db.flush()

    print("Organizations created:")
    print(f"  - {org1.name} ({org1.id})")
    print(f"  - {org2.name} ({org2.id})\n")

    # Users to Create
    users = [
        # Org 1 Owners
        {
            "name": "Owner1_Lroe",
            "phone": "9000000001",
            "password": "pass123",
            "organization_id": org1.id,
            "role": "owner"
        },
        {
            "name": "Owner2_Lroe",
            "phone": "9000000002",
            "password": "pass123",
            "organization_id": org1.id,
            "role": "owner"
        },

        # Org 1 Supervisor
        {
            "name": "Supervisor_Lroe",
            "phone": "9000000005",
            "password": "pass123",
            "organization_id": org1.id,
            "role": "supervisor"
        },

        # Org 2 Owners
        {
            "name": "Owner1_Global",
            "phone": "9000000003",
            "password": "pass123",
            "organization_id": org2.id,
            "role": "owner"
        },
        {
            "name": "Owner2_Global",
            "phone": "9000000004",
            "password": "pass123",
            "organization_id": org2.id,
            "role": "owner"
        },

        # Org 2 Supervisor
        {
            "name": "Supervisor_Global",
            "phone": "9000000006",
            "password": "pass123",
            "organization_id": org2.id,
            "role": "supervisor"
        },
    ]

    print("Creating users...")

    for user_data in users:
        user = models.User(
            id=uuid.uuid4(),
            organization_id=user_data["organization_id"],
            name=user_data["name"],
            phone=user_data["phone"],
            role=user_data["role"],
            password_hash=get_password_hash(user_data["password"]),
            is_active=True
        )

        db.add(user)

        print(
            f"  + Created {user_data['role']} '{user_data['name']}' "
            f"for organization {user_data['organization_id']}"
        )

    db.commit()
    db.close()

    print("\nDatabase reset and user setup complete.")


if __name__ == "__main__":
    reset_database()

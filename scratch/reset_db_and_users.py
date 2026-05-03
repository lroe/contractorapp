import bcrypt
from app.database import SessionLocal, engine
from app import models
import uuid

def get_password_hash(password):
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def reset_everything():
    db = SessionLocal()
    
    print("Dropping and recreating all tables...")
    models.Base.metadata.drop_all(bind=engine)
    models.Base.metadata.create_all(bind=engine)
    print("Database schema recreated.")

    # 1. Create Organizations
    org_lroe = models.Organization(id=uuid.uuid4(), name="Lroe Construction")
    org_global = models.Organization(id=uuid.uuid4(), name="Global Builders")
    db.add_all([org_lroe, org_global])
    db.flush()
    print(f"\nOrganizations created:\n  - {org_lroe.name} ({org_lroe.id})\n  - {org_global.name} ({org_global.id})")

    # 2. Create Users
    print("\nCreating users...")
    
    users_to_create = [
        # Organization A
        {
            "name": "suhail",
            "phone": "9999999999",
            "role": "owner",
            "password": "pass123",
            "org_id": org_lroe.id
        },
        {
            "name": "jeevan",
            "phone": "8888888888",
            "role": "supervisor",
            "password": "pass123",
            "org_id": org_lroe.id
        },
        {
            "name": "store",
            "phone": "7777777777",
            "role": "material_manager",
            "password": "pass123",
            "org_id": org_lroe.id
        },
        # Organization B
        {
            "name": "ramesh",
            "phone": "6666666666",
            "role": "owner",
            "password": "pass123",
            "org_id": org_global.id
        }
    ]
    
    for user_data in users_to_create:
        db_user = models.User(
            id=uuid.uuid4(),
            organization_id=user_data["org_id"],
            name=user_data["name"],
            phone=user_data["phone"],
            role=user_data["role"],
            password_hash=get_password_hash(user_data["password"]),
            is_active=True
        )
        db.add(db_user)
        print(f"  + User '{user_data['name']}' ({user_data['role']}) created in {user_data['org_id']}")

    # 3. Create initial materials for Lroe
    print("\nSeeding materials for Lroe Construction...")
    materials = [
        {"name": "Cement (53 Grade)", "unit": "Bags", "category": "Binders", "min": 100},
        {"name": "Steel (12mm)", "unit": "Kg", "category": "Metal", "min": 500},
        {"name": "Sand (Coarse)", "unit": "CFT", "category": "Aggregates", "min": 200},
    ]
    for m in materials:
        db.add(models.Material(
            organization_id=org_lroe.id,
            name=m["name"],
            unit=m["unit"],
            category=m["category"],
            min_stock_level=m["min"]
        ))

    db.commit()
    db.close()
    print("\nDatabase reset and multi-tenant seeding complete.")

if __name__ == "__main__":
    reset_everything()

import bcrypt
from sqlalchemy import text
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

    # 2. Create the two requested accounts
    print("\nCreating new accounts...")
    
    users_to_create = [
        {
            "name": "suhail",
            "phone": "9999999999",
            "role": "owner",
            "password": "pass123"
        },
        {
            "name": "jeevan",
            "phone": "8888888888",
            "role": "supervisor",
            "password": "pass123"
        },
        {
            "name": "store",
            "phone": "7777777777",
            "role": "material_manager",
            "password": "pass123"
        }
    ]
    
    for user_data in users_to_create:
        db_user = models.User(
            id=uuid.uuid4(),
            name=user_data["name"],
            phone=user_data["phone"],
            role=user_data["role"],
            password_hash=get_password_hash(user_data["password"]),
            is_active=True
        )
        db.add(db_user)
        print(f"  + User '{user_data['name']}' ({user_data['role']}) created.")

    db.commit()
    db.close()
    print("\nDatabase reset and account creation complete.")

if __name__ == "__main__":
    reset_everything()

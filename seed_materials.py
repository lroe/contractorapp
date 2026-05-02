from sqlalchemy.orm import Session
from app.database import SessionLocal
from app import models
import uuid

def seed_materials():
    db = SessionLocal()
    materials = [
        {"name": "Cement", "unit": "Bags", "category": "Structural"},
        {"name": "Steel (TMT)", "unit": "Tons", "category": "Structural"},
        {"name": "Sand", "unit": "Cum", "category": "Structural"},
        {"name": "Bricks", "unit": "Units", "category": "Structural"},
        {"name": "Paint (White)", "unit": "Liters", "category": "Finishing"},
        {"name": "Tiles (2x2)", "unit": "Sqft", "category": "Finishing"},
    ]
    
    for m in materials:
        exists = db.query(models.Material).filter(models.Material.name == m["name"]).first()
        if not exists:
            db_material = models.Material(id=uuid.uuid4(), **m)
            db.add(db_material)
    
    db.commit()
    db.close()
    print("Materials seeded successfully!")

if __name__ == "__main__":
    seed_materials()

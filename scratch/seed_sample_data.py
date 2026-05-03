import uuid
from datetime import date, timedelta
from app.database import SessionLocal
from app import models

def seed_data():
    db = SessionLocal()
    
    # 1. Get Organizations
    orgs = db.query(models.Organization).all()
    if not orgs:
        print("No organizations found. Please run reset_db_and_users.py first.")
        return

    lroe = orgs[0]
    global_builders = orgs[1] if len(orgs) > 1 else None

    # 2. Get Users
    suhail = db.query(models.User).filter(models.User.name == "suhail").first()
    jeevan = db.query(models.User).filter(models.User.name == "jeevan").first()
    ramesh = db.query(models.User).filter(models.User.name == "ramesh").first()

    print(f"Seeding data for {lroe.name} and {global_builders.name if global_builders else 'N/A'}...")

    # 3. Add Materials for Lroe
    materials_lroe = [
        {"name": "OPC Cement (53 Grade)", "unit": "Bags", "category": "Binders", "min": 200},
        {"name": "TMT Steel (12mm)", "unit": "Kg", "category": "Metal", "min": 1000},
        {"name": "TMT Steel (16mm)", "unit": "Kg", "category": "Metal", "min": 800},
        {"name": "River Sand", "unit": "CFT", "category": "Aggregates", "min": 500},
        {"name": "Red Bricks", "unit": "Nos", "category": "Masonry", "min": 5000},
        {"name": "Granite Tiles", "unit": "SqFt", "category": "Finishing", "min": 300},
    ]
    
    material_objs_lroe = []
    for m in materials_lroe:
        mat = models.Material(
            organization_id=lroe.id,
            name=m["name"],
            unit=m["unit"],
            category=m["category"],
            min_stock_level=m["min"]
        )
        db.add(mat)
        material_objs_lroe.append(mat)
    
    db.flush()

    # 4. Add Vendors for Lroe
    vendors_lroe = [
        {"name": "Southern Steel Corp", "phone": "9888811111", "email": "sales@southernsteel.com", "gstin": "33AAACS1234A1Z1"},
        {"name": "Elite Cement Distributors", "phone": "9777722222", "email": "info@elitecement.com", "gstin": "33BBACS5678B1Z2"},
        {"name": "City Brick & Sand", "phone": "9666633333", "email": "orders@citybricks.com", "gstin": "33CCACS9012C1Z3"},
    ]
    
    vendor_objs_lroe = []
    for v in vendors_lroe:
        ven = models.Vendor(
            organization_id=lroe.id,
            name=v["name"],
            phone=v["phone"],
            email=v["email"],
            gstin=v["gstin"],
            is_active=True
        )
        db.add(ven)
        vendor_objs_lroe.append(ven)
    
    db.flush()

    # 5. Add Vendor Prices (Benchmarking Data)
    # Steel prices comparison
    steel_12 = next(m for m in material_objs_lroe if "Steel (12mm)" in m.name)
    db.add(models.VendorPrice(vendor_id=vendor_objs_lroe[0].id, material_id=steel_12.id, price_per_unit=68.50))
    db.add(models.VendorPrice(vendor_id=vendor_objs_lroe[1].id, material_id=steel_12.id, price_per_unit=71.20))
    
    # Cement prices comparison
    cement = next(m for m in material_objs_lroe if "Cement" in m.name)
    db.add(models.VendorPrice(vendor_id=vendor_objs_lroe[1].id, material_id=cement.id, price_per_unit=420.00, notes="Bulk discount available"))
    db.add(models.VendorPrice(vendor_id=vendor_objs_lroe[2].id, material_id=cement.id, price_per_unit=445.00))

    # 6. Create Projects
    projects_lroe = [
        {"name": "Skyline Residency", "code": "SK-001"},
        {"name": "Green Valley Villa", "code": "GV-002"},
    ]
    
    proj_objs_lroe = []
    for p in projects_lroe:
        proj = models.Project(
            organization_id=lroe.id,
            name=p["name"],
            code=p["code"],
            status="active"
        )
        db.add(proj)
        proj_objs_lroe.append(proj)
    
    db.flush()

    # 7. Assign Supervisor Jeevan to Skyline
    if jeevan:
        db.add(models.ProjectUser(project_id=proj_objs_lroe[0].id, user_id=jeevan.id, role="supervisor"))

    # 8. Create some Material Requests (Pending for Portal Approval)
    if jeevan:
        requests = [
            {"material": cement, "qty": 100, "remarks": "Urgent for foundation work"},
            {"material": steel_12, "qty": 500, "remarks": "Required for slab casting"},
        ]
        for r in requests:
            db.add(models.MaterialRequest(
                project_id=proj_objs_lroe[0].id,
                material_id=r["material"].id,
                quantity=r["qty"],
                requested_by=jeevan.id,
                status="pending",
                remarks=r["remarks"]
            ))

    # 9. Stock Ledger Entries (Initial Stock)
    for mat in material_objs_lroe:
        # Give Skyline some initial stock
        db.add(models.StockLedger(
            project_id=proj_objs_lroe[0].id,
            material_id=mat.id,
            movement_type="inward",
            quantity=50.0,
            remarks="Initial Seed Stock",
            logged_by=suhail.id if suhail else None
        ))
        # Update Inventory
        db.add(models.ProjectInventory(
            project_id=proj_objs_lroe[0].id,
            material_id=mat.id,
            current_quantity=50.0
        ))

    db.commit()
    db.close()
    print("Sample data seeded successfully.")

if __name__ == "__main__":
    seed_data()

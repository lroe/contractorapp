from sqlalchemy.orm import Session
from . import models, schemas
import uuid
from datetime import date
from decimal import Decimal

# Organization CRUD
def create_organization(db: Session, organization: schemas.OrganizationCreate):
    db_org = models.Organization(**organization.dict())
    db.add(db_org)
    db.commit()
    db.refresh(db_org)
    return db_org

def get_organizations(db: Session):
    return db.query(models.Organization).all()

# User CRUD
def get_user(db: Session, user_id: uuid.UUID):
    return db.query(models.User).filter(models.User.id == user_id).first()

def get_user_by_phone(db: Session, phone: str):
    return db.query(models.User).filter(models.User.phone == phone).first()

def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()

def create_user(db: Session, user: schemas.UserCreate):
    import bcrypt
    hashed = bcrypt.hashpw(user.password.encode(), bcrypt.gensalt()).decode()
    db_user = models.User(
        organization_id=user.organization_id,
        name=user.name,
        phone=user.phone,
        email=user.email,
        password_hash=hashed,
        role=user.role,
        is_active=True
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def get_users(db: Session, organization_id: uuid.UUID, role: str = None):
    q = db.query(models.User).filter(models.User.organization_id == organization_id)
    if role:
        q = q.filter(models.User.role == role)
    return q.all()

# Project CRUD
def create_project(db: Session, project: schemas.ProjectCreate):
    db_project = models.Project(**project.dict())
    db.add(db_project)
    db.commit()
    db.refresh(db_project)
    return db_project

def get_projects(db: Session, organization_id: uuid.UUID):
    return db.query(models.Project).filter(models.Project.organization_id == organization_id).all()

def get_project_supervisors(db: Session, project_id: uuid.UUID):
    return db.query(models.User).join(models.ProjectUser).filter(
        models.ProjectUser.project_id == project_id
    ).all()

def assign_supervisor(db: Session, project_id: uuid.UUID, user_id: uuid.UUID):
    # Check if already assigned
    existing = db.query(models.ProjectUser).filter(
        models.ProjectUser.project_id == project_id,
        models.ProjectUser.user_id == user_id
    ).first()
    if not existing:
        db_pu = models.ProjectUser(project_id=project_id, user_id=user_id, role='supervisor')
        db.add(db_pu)
        db.commit()
    return True

def unassign_supervisor(db: Session, project_id: uuid.UUID, user_id: uuid.UUID):
    db.query(models.ProjectUser).filter(
        models.ProjectUser.project_id == project_id,
        models.ProjectUser.user_id == user_id
    ).delete()
    db.commit()
    return True

# DPR CRUD
def create_dpr_entry(db: Session, dpr: schemas.DPREntryCreate):
    db_dpr = models.DPREntry(**dpr.dict())
    db.add(db_dpr)
    db.commit()
    db.refresh(db_dpr)
    return db_dpr

def add_dpr_media(db: Session, media: schemas.DPRMediaCreate):
    db_media = models.DPRMedia(**media.dict())
    db.add(db_media)
    db.commit()
    db.refresh(db_media)
    return db_media

def get_dpr_entries(db: Session, project_id: uuid.UUID):
    return db.query(models.DPREntry).filter(models.DPREntry.project_id == project_id).all()

# Gang CRUD
def create_gang(db: Session, gang: schemas.GangCreate):
    db_gang = models.Gang(**gang.dict())
    db.add(db_gang)
    db.commit()
    db.refresh(db_gang)
    return db_gang

def get_project_gangs(db: Session, project_id: uuid.UUID):
    return db.query(models.Gang).filter(models.Gang.project_id == project_id).all()

# Worker CRUD
def create_worker(db: Session, worker: schemas.WorkerCreate):
    db_worker = models.Worker(**worker.dict())
    db.add(db_worker)
    db.commit()
    db.refresh(db_worker)
    return db_worker

def get_gang_workers(db: Session, gang_id: uuid.UUID):
    return db.query(models.Worker).filter(models.Worker.gang_id == gang_id).all()

# Attendance CRUD
def mark_attendance(db: Session, attendance: schemas.AttendanceCreate):
    db_att = db.query(models.Attendance).filter(
        models.Attendance.worker_id == attendance.worker_id,
        models.Attendance.entry_date == attendance.entry_date
    ).first()
    
    if db_att:
        db_att.status = attendance.status
        db_att.marked_by = attendance.marked_by
    else:
        db_att = models.Attendance(**attendance.dict())
        db.add(db_att)
    
    db.commit()
    db.refresh(db_att)
    return db_att

def get_gang_attendance(db: Session, gang_id: uuid.UUID, date_val: date):
    return db.query(models.Attendance).filter(
        models.Attendance.gang_id == gang_id,
        models.Attendance.entry_date == date_val
    ).all()

# Materials
def get_materials(db: Session, organization_id: uuid.UUID):
    return db.query(models.Material).filter(models.Material.organization_id == organization_id).all()

def create_material(db: Session, material: schemas.MaterialCreate):
    db_material = models.Material(**material.dict())
    db.add(db_material)
    db.commit()
    db.refresh(db_material)
    return db_material

# Inventory
def update_inventory(db: Session, project_id: uuid.UUID, material_id: uuid.UUID, delta: float):
    db_inventory = db.query(models.ProjectInventory).filter(
        models.ProjectInventory.project_id == project_id,
        models.ProjectInventory.material_id == material_id
    ).first()
    
    if not db_inventory:
        db_inventory = models.ProjectInventory(
            project_id=project_id,
            material_id=material_id,
            current_quantity=Decimal(str(delta))
        )
        db.add(db_inventory)
    else:
        db_inventory.current_quantity += Decimal(str(delta))
    
    db.commit()
    db.refresh(db_inventory)
    return db_inventory

def get_project_inventory(db: Session, project_id: uuid.UUID):
    return db.query(models.ProjectInventory).filter(models.ProjectInventory.project_id == project_id).all()

# Vendors
def create_vendor(db: Session, vendor: schemas.VendorCreate):
    db_vendor = models.Vendor(**vendor.dict())
    db.add(db_vendor)
    db.commit()
    db.refresh(db_vendor)
    return db_vendor

def get_vendors(db: Session, organization_id: uuid.UUID):
    return db.query(models.Vendor).filter(
        models.Vendor.organization_id == organization_id,
        models.Vendor.is_active == True
    ).all()

# Vendor Prices
def create_vendor_price(db: Session, price: schemas.VendorPriceCreate):
    db_price = models.VendorPrice(**price.dict())
    db.add(db_price)
    db.commit()
    db.refresh(db_price)
    return db_price

def get_vendor_prices(db: Session, material_id: uuid.UUID):
    return db.query(models.VendorPrice).filter(
        models.VendorPrice.material_id == material_id
    ).order_by(models.VendorPrice.price_per_unit).all()

# Purchase Orders
def create_purchase_order(db: Session, po: schemas.PurchaseOrderCreate):
    from datetime import date as date_type
    import random
    po_number = f"PO-{date_type.today().strftime('%Y%m')}-{random.randint(1000, 9999)}"
    items_data = po.items
    po_dict = po.dict(exclude={'items'})
    db_po = models.PurchaseOrder(**po_dict, po_number=po_number, status='draft')
    db.add(db_po)
    db.flush()

    total = 0
    for item in items_data:
        db_item = models.PurchaseOrderItem(po_id=db_po.id, **item.dict())
        db.add(db_item)
        total += float(item.quantity) * float(item.unit_price)

    db_po.total_amount = total
    db.commit()
    db.refresh(db_po)
    return db_po

def get_purchase_orders(db: Session, organization_id: uuid.UUID, project_id: uuid.UUID = None):
    q = db.query(models.PurchaseOrder).filter(models.PurchaseOrder.organization_id == organization_id)
    if project_id:
        q = q.filter(models.PurchaseOrder.project_id == project_id)
    return q.order_by(models.PurchaseOrder.created_at.desc()).all()

def update_po_status(db: Session, po_id: uuid.UUID, status: str, approved_by: uuid.UUID = None):
    db_po = db.query(models.PurchaseOrder).filter(models.PurchaseOrder.id == po_id).first()
    if db_po:
        db_po.status = status
        if approved_by:
            db_po.approved_by = approved_by
        db.commit()
        db.refresh(db_po)
    return db_po

# Stock Ledger
def log_stock_movement(db: Session, project_id: uuid.UUID, material_id: uuid.UUID,
                       movement_type: str, quantity: float, logged_by: uuid.UUID,
                       reference_type: str = None, reference_id: uuid.UUID = None,
                       remarks: str = None):
    from datetime import date as date_type
    entry = models.StockLedger(
        project_id=project_id,
        material_id=material_id,
        movement_type=movement_type,
        quantity=quantity,
        reference_type=reference_type,
        reference_id=reference_id,
        remarks=remarks,
        logged_by=logged_by,
        entry_date=date_type.today(),
    )
    db.add(entry)
    sign = 1 if movement_type in ('inward', 'transfer_in') else -1
    update_inventory(db, project_id, material_id, sign * quantity)
    db.commit()
    db.refresh(entry)
    return entry

def get_stock_ledger(db: Session, project_id: uuid.UUID, material_id: uuid.UUID = None):
    q = db.query(models.StockLedger).filter(models.StockLedger.project_id == project_id)
    if material_id:
        q = q.filter(models.StockLedger.material_id == material_id)
    return q.order_by(models.StockLedger.created_at.desc()).all()

# BOQ
def upsert_boq_item(db: Session, boq: schemas.BOQItemCreate):
    existing = db.query(models.BOQItem).filter(
        models.BOQItem.project_id == boq.project_id,
        models.BOQItem.material_id == boq.material_id
    ).first()
    if existing:
        existing.planned_quantity = boq.planned_quantity
        existing.estimated_unit_price = boq.estimated_unit_price
        existing.min_stock_level = boq.min_stock_level
        existing.description = boq.description
        db.commit()
        db.refresh(existing)
        return existing
    db_boq = models.BOQItem(**boq.dict())
    db.add(db_boq)
    db.commit()
    db.refresh(db_boq)
    return db_boq

def get_boq_with_actuals(db: Session, project_id: uuid.UUID):
    from sqlalchemy import func
    boq_items = db.query(models.BOQItem).filter(models.BOQItem.project_id == project_id).all()
    result = []
    for item in boq_items:
        actual = db.query(func.sum(models.StockLedger.quantity)).filter(
            models.StockLedger.project_id == project_id,
            models.StockLedger.material_id == item.material_id,
            models.StockLedger.movement_type.in_(['outward', 'wastage'])
        ).scalar() or 0
        planned = float(item.planned_quantity)
        price = float(item.estimated_unit_price or 0)
        actual_f = float(actual)
        
        planned_exp = planned * price
        actual_exp = actual_f * price
        
        variance_pct = ((actual_f - planned) / planned * 100) if planned > 0 else 0
        result.append({
            "id": str(item.id),
            "material_id": str(item.material_id),
            "material": item.material.name if item.material else "Unknown",
            "unit": item.material.unit if item.material else "",
            "planned": planned,
            "actual": actual_f,
            "estimated_unit_price": price,
            "min_stock_level": float(item.min_stock_level or 0),
            "planned_expenditure": round(planned_exp, 2),
            "actual_expenditure": round(actual_exp, 2),
            "variance_pct": round(variance_pct, 1),
            "over_budget": variance_pct > 0,
        })
    return result

# Transfers
def create_transfer_note(db: Session, transfer: schemas.TransferNoteCreate):
    db_transfer = models.TransferNote(**transfer.dict(), status='pending')
    db.add(db_transfer)
    db.commit()
    db.refresh(db_transfer)
    return db_transfer

def confirm_transfer_received(db: Session, transfer_id: uuid.UUID, received_by: uuid.UUID):
    db_transfer = db.query(models.TransferNote).filter(models.TransferNote.id == transfer_id).first()
    if db_transfer and db_transfer.status != 'received':
        db_transfer.status = 'received'
        log_stock_movement(db, db_transfer.from_project_id, db_transfer.material_id,
                           'transfer_out', float(db_transfer.quantity), received_by,
                           reference_type='transfer_note', reference_id=transfer_id)
        log_stock_movement(db, db_transfer.to_project_id, db_transfer.material_id,
                           'transfer_in', float(db_transfer.quantity), received_by,
                           reference_type='transfer_note', reference_id=transfer_id)
        db.commit()
        db.refresh(db_transfer)
    return db_transfer

def get_transfer_notes(db: Session, project_id: uuid.UUID):
    from sqlalchemy import or_
    return db.query(models.TransferNote).filter(
        or_(models.TransferNote.from_project_id == project_id,
            models.TransferNote.to_project_id == project_id)
    ).order_by(models.TransferNote.created_at.desc()).all()

# Waste Logs
def log_waste(db: Session, waste: schemas.WasteLogCreate):
    db_waste = models.WasteLog(**waste.dict())
    db.add(db_waste)
    log_stock_movement(db, waste.project_id, waste.material_id,
                       'wastage', float(waste.quantity), waste.logged_by,
                       reference_type='waste_log', remarks=waste.reason)
    db.commit()
    db.refresh(db_waste)
    return db_waste

def get_waste_logs(db: Session, project_id: uuid.UUID):
    return db.query(models.WasteLog).filter(models.WasteLog.project_id == project_id).order_by(models.WasteLog.created_at.desc()).all()

# Documents
def create_project_document(db: Session, document: schemas.ProjectDocumentCreate):
    data = document.dict()
    if not data.get('title') and data.get('file_name'):
        data['title'] = data['file_name']
    if not data.get('file_name') and data.get('title'):
        data['file_name'] = data['title']
    if not data.get('category'):
        data['category'] = 'other'
    db_doc = models.ProjectDocument(**data)
    db.add(db_doc)
    db.commit()
    db.refresh(db_doc)
    return db_doc

def get_project_documents(db: Session, project_id: uuid.UUID):
    return db.query(models.ProjectDocument).filter(models.ProjectDocument.project_id == project_id).order_by(models.ProjectDocument.uploaded_at.desc()).all()

# Material Requests
def create_material_request(db: Session, request: schemas.MaterialRequestCreate):
    data = request.dict()
    # Handle received_remarks if provided in create
    received_remarks = data.pop('received_remarks', None)
    db_req = models.MaterialRequest(**data)
    if received_remarks:
        db_req.received_remarks = received_remarks
    db.add(db_req)
    db.commit()
    db.refresh(db_req)
    return db_req

def get_material_requests(db: Session, project_id: uuid.UUID):
    return db.query(models.MaterialRequest).filter(models.MaterialRequest.project_id == project_id).order_by(models.MaterialRequest.created_at.desc()).all()

def update_material_request_status(db: Session, request_id: uuid.UUID, status: str, received_remarks: str = None):
    db_req = db.query(models.MaterialRequest).filter(models.MaterialRequest.id == request_id).first()
    if db_req:
        db_req.status = status
        if received_remarks:
            db_req.received_remarks = received_remarks
        
        # REMOVED: Auto-stock logic. Owner must now add to ledger manually.
            
        db.commit()
        db.refresh(db_req)
    return db_req

def add_material_request_media(db: Session, request_id: uuid.UUID, media_url: str):
    db_media = models.MaterialRequestMedia(request_id=request_id, media_url=media_url)
    db.add(db_media)
    db.commit()
    db.refresh(db_media)
    return db_media

# Material Usage
def log_material_usage(db: Session, usage: schemas.MaterialUsageCreate):
    from datetime import date as date_type
    db_usage = models.MaterialUsage(**usage.dict())
    db.add(db_usage)
    # Log outward movement in stock ledger
    log_stock_movement(
        db, usage.project_id, usage.material_id,
        'outward', float(usage.quantity), usage.logged_by,
        reference_type='material_usage',
        remarks=f"Logged via Material Usage"
    )
    
    # NEW: Automatically log expenditure in Transactions
    # 1. Try to find BOQ price for this material
    boq_item = db.query(models.BOQItem).filter(
        models.BOQItem.project_id == usage.project_id,
        models.BOQItem.material_id == usage.material_id
    ).first()
    
    price = 0
    if boq_item and boq_item.estimated_unit_price:
        price = float(boq_item.estimated_unit_price)
    
    if price > 0:
        amount = float(usage.quantity) * price
        mat_name = "Material"
        mat = db.query(models.Material).filter(models.Material.id == usage.material_id).first()
        if mat: mat_name = mat.name
        
        tx = models.Transaction(
            project_id=usage.project_id,
            type='EXPENSE',
            category='Materials',
            amount=Decimal(str(amount)),
            description=f"Auto-log: Usage of {usage.quantity} {mat.unit if mat else ''} {mat_name}",
            transaction_date=usage.usage_date or date_type.today(),
            created_by=usage.logged_by
        )
        db.add(tx)

    db.commit()
    db.refresh(db_usage)
    return db_usage

# Transactions
def create_transaction(db: Session, tx: schemas.TransactionCreate):
    from datetime import date as date_type
    db_tx = models.Transaction(**tx.dict())
    if not db_tx.transaction_date:
        db_tx.transaction_date = date_type.today()
    db.add(db_tx)
    db.commit()
    db.refresh(db_tx)
    return db_tx

def get_transactions(db: Session, project_id: uuid.UUID):
    return db.query(models.Transaction).filter(
        models.Transaction.project_id == project_id
    ).order_by(models.Transaction.transaction_date.desc()).all()

# Work Types
def create_work_type(db: Session, work_type: schemas.WorkTypeCreate):
    db_wt = models.WorkType(**work_type.dict())
    db.add(db_wt)
    db.commit()
    db.refresh(db_wt)
    return db_wt

def get_work_types(db: Session, organization_id: uuid.UUID):
    return db.query(models.WorkType).filter(models.WorkType.organization_id == organization_id).all()

# Low Stock Alerts
def get_low_stock_alerts(db: Session, organization_id: uuid.UUID):
    projects = db.query(models.Project).filter(models.Project.organization_id == organization_id).all()
    alerts = []
    for project in projects:
        inventory = db.query(models.ProjectInventory).filter(models.ProjectInventory.project_id == project.id).all()
        for item in inventory:
            material = item.material
            if material and float(item.current_quantity) < float(material.min_stock_level or 0):
                alerts.append({
                    "project_id": str(project.id),
                    "project_name": project.name,
                    "material_id": str(material.id),
                    "material_name": material.name,
                    "unit": material.unit,
                    "current_quantity": float(item.current_quantity),
                    "min_stock_level": float(material.min_stock_level or 0),
                })
    return alerts

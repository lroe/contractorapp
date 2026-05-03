from sqlalchemy.orm import Session
from . import models, schemas
import uuid
from datetime import date

# User CRUD
def get_user(db: Session, user_id: uuid.UUID):
    return db.query(models.User).filter(models.User.id == user_id).first()

def get_user_by_phone(db: Session, phone: str):
    return db.query(models.User).filter(models.User.phone == phone).first()

def create_user(db: Session, user: schemas.UserCreate):
    db_user = models.User(
        name=user.name,
        phone=user.phone,
        email=user.email,
        password_hash=user.password, # In a real app, hash this!
        role=user.role
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

# Project CRUD
def create_project(db: Session, project: schemas.ProjectCreate):
    db_project = models.Project(**project.dict())
    db.add(db_project)
    db.commit()
    db.refresh(db_project)
    return db_project

def get_projects(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Project).offset(skip).limit(limit).all()

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
def create_gang(db: Session, project_id: uuid.UUID, name: str, supervisor_id: uuid.UUID):
    db_gang = models.Gang(project_id=project_id, name=name, supervisor_id=supervisor_id)
    db.add(db_gang)
    db.commit()
    db.refresh(db_gang)
    return db_gang

def get_gangs(db: Session, project_id: uuid.UUID):
    return db.query(models.Gang).filter(models.Gang.project_id == project_id).all()

# Worker CRUD
def create_worker(db: Session, project_id: uuid.UUID, name: str, phone: str = None, skill_type: str = None):
    db_worker = models.Worker(project_id=project_id, name=name, phone=phone, skill_type=skill_type)
    db.add(db_worker)
    db.commit()
    db.refresh(db_worker)
    return db_worker

def assign_worker_to_gang(db: Session, worker_id: uuid.UUID, gang_id: uuid.UUID):
    db_worker = db.query(models.Worker).filter(models.Worker.id == worker_id).first()
    if db_worker:
        db_worker.gang_id = gang_id
        db.commit()
        db.refresh(db_worker)
    return db_worker

def get_workers_by_gang(db: Session, gang_id: uuid.UUID):
    return db.query(models.Worker).filter(models.Worker.gang_id == gang_id).all()

# Attendance CRUD
# Redundant function removed (replaced by schemas-based version)

# Project User CRUD
def assign_user_to_project(db: Session, project_id: uuid.UUID, user_id: uuid.UUID, role: str):
    db_project_user = models.ProjectUser(project_id=project_id, user_id=user_id, role=role)
    db.add(db_project_user)
    db.commit()
    db.refresh(db_project_user)
    return db_project_user

def get_project_supervisors(db: Session, project_id: uuid.UUID):
    return db.query(models.User).join(models.ProjectUser).filter(
        models.ProjectUser.project_id == project_id,
        models.ProjectUser.role == 'supervisor'
    ).all()

def unassign_user_from_project(db: Session, project_id: uuid.UUID, user_id: uuid.UUID):
    db_pu = db.query(models.ProjectUser).filter(
        models.ProjectUser.project_id == project_id,
        models.ProjectUser.user_id == user_id
    ).first()
    if db_pu:
        db.delete(db_pu)
        db.commit()
    return True

# Materials
def get_materials(db: Session):
    return db.query(models.Material).all()

def create_material(db: Session, material: schemas.MaterialCreate):
    db_material = models.Material(**material.dict())
    db.add(db_material)
    db.commit()
    db.refresh(db_material)
    return db_material

# Inventory
def get_project_inventory(db: Session, project_id: uuid.UUID):
    return db.query(models.ProjectInventory).filter(models.ProjectInventory.project_id == project_id).all()

def update_inventory(db: Session, project_id: uuid.UUID, material_id: uuid.UUID, delta: float):
    db_inventory = db.query(models.ProjectInventory).filter(
        models.ProjectInventory.project_id == project_id,
        models.ProjectInventory.material_id == material_id
    ).first()
    
    if not db_inventory:
        db_inventory = models.ProjectInventory(
            project_id=project_id,
            material_id=material_id,
            current_quantity=delta
        )
        db.add(db_inventory)
    else:
        db_inventory.current_quantity += Decimal(str(delta))
    
    db.commit()
    db.refresh(db_inventory)
    return db_inventory

# Requests
def create_material_request(db: Session, request: schemas.MaterialRequestCreate):
    db_request = models.MaterialRequest(**request.dict())
    db.add(db_request)
    db.commit()
    db.refresh(db_request)
    return db_request

def get_material_requests(db: Session, project_id: uuid.UUID):
    return db.query(models.MaterialRequest).filter(models.MaterialRequest.project_id == project_id).all()

def update_material_request_status(db: Session, request_id: uuid.UUID, status: str, received_remarks: str = None):
    db_request = db.query(models.MaterialRequest).filter(models.MaterialRequest.id == request_id).first()
    if db_request:
        # If approved or received, auto-update inventory (only if not already done)
        if status in ["approved", "received"] and db_request.status not in ["approved", "received"]:
            update_inventory(db, db_request.project_id, db_request.material_id, float(db_request.quantity))
        
        db_request.status = status
        if received_remarks:
            db_request.received_remarks = received_remarks
        db.commit()
        db.refresh(db_request)
    return db_request

def create_material_request_media(db: Session, request_id: uuid.UUID, media_url: str):
    db_media = models.MaterialRequestMedia(request_id=request_id, media_url=media_url)
    db.add(db_media)
    db.commit()
    db.refresh(db_media)
    return db_media

# Usage
def log_material_usage(db: Session, usage: schemas.MaterialUsageCreate):
    db_usage = models.MaterialUsage(**usage.dict())
    db.add(db_usage)
    # Deduct from inventory
    update_inventory(db, usage.project_id, usage.material_id, -float(usage.quantity))
    db.commit()
    db.refresh(db_usage)
    return db_usage

# Transactions
def create_transaction(db: Session, transaction: schemas.TransactionCreate):
    db_transaction = models.Transaction(**transaction.dict())
    db.add(db_transaction)
    db.commit()
    db.refresh(db_transaction)
    return db_transaction

def get_project_transactions(db: Session, project_id: uuid.UUID):
    return db.query(models.Transaction).filter(models.Transaction.project_id == project_id).order_by(models.Transaction.transaction_date.desc()).all()

# Workers & Gangs
def create_gang(db: Session, gang: schemas.GangCreate):
    db_gang = models.Gang(**gang.dict())
    db.add(db_gang)
    db.commit()
    db.refresh(db_gang)
    return db_gang

def get_project_gangs(db: Session, project_id: uuid.UUID):
    return db.query(models.Gang).filter(models.Gang.project_id == project_id).all()

def create_worker(db: Session, worker: schemas.WorkerCreate):
    db_worker = models.Worker(**worker.dict())
    db.add(db_worker)
    db.commit()
    db.refresh(db_worker)
    return db_worker

def get_gang_workers(db: Session, gang_id: uuid.UUID):
    return db.query(models.Worker).filter(models.Worker.gang_id == gang_id).all()

def mark_attendance(db: Session, attendance: schemas.AttendanceCreate):
    # Upsert logic (replace if already exists for that day)
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

def get_gang_attendance(db: Session, gang_id: uuid.UUID, date: date):
    return db.query(models.Attendance).filter(
        models.Attendance.gang_id == gang_id,
        models.Attendance.entry_date == date
    ).all()

# Project Document CRUD
def create_project_document(db: Session, document: schemas.ProjectDocumentCreate):
    db_doc = models.ProjectDocument(**document.dict())
    db.add(db_doc)
    db.commit()
    db.refresh(db_doc)
    return db_doc

def get_project_documents(db: Session, project_id: uuid.UUID):
    return db.query(models.ProjectDocument).filter(models.ProjectDocument.project_id == project_id).order_by(models.ProjectDocument.uploaded_at.desc()).all()

# ─── Stock Ledger ─────────────────────────────────────────────────────────────

def log_stock_movement(db: Session, project_id: uuid.UUID, material_id: uuid.UUID,
                       movement_type: str, quantity: float, logged_by: uuid.UUID,
                       reference_type: str = None, reference_id: uuid.UUID = None,
                       remarks: str = None):
    """Logs every stock movement and updates project_inventory accordingly."""
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
    # Update running inventory
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

# ─── Vendor CRUD ──────────────────────────────────────────────────────────────

def create_vendor(db: Session, vendor: schemas.VendorCreate):
    db_vendor = models.Vendor(**vendor.dict())
    db.add(db_vendor)
    db.commit()
    db.refresh(db_vendor)
    return db_vendor

def get_vendors(db: Session):
    return db.query(models.Vendor).filter(models.Vendor.is_active == True).all()

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

# ─── Purchase Order CRUD ──────────────────────────────────────────────────────

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

def get_purchase_orders(db: Session, project_id: uuid.UUID = None):
    q = db.query(models.PurchaseOrder)
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

# ─── BOQ CRUD ─────────────────────────────────────────────────────────────────

def upsert_boq_item(db: Session, boq: schemas.BOQItemCreate):
    existing = db.query(models.BOQItem).filter(
        models.BOQItem.project_id == boq.project_id,
        models.BOQItem.material_id == boq.material_id
    ).first()
    if existing:
        existing.planned_quantity = boq.planned_quantity
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
    """Returns BOQ items with actual used quantity and % variance."""
    from sqlalchemy import func
    boq_items = db.query(models.BOQItem).filter(
        models.BOQItem.project_id == project_id
    ).all()

    result = []
    for item in boq_items:
        actual = db.query(func.sum(models.StockLedger.quantity)).filter(
            models.StockLedger.project_id == project_id,
            models.StockLedger.material_id == item.material_id,
            models.StockLedger.movement_type.in_(['outward', 'wastage'])
        ).scalar() or 0

        planned = float(item.planned_quantity)
        actual_f = float(actual)
        variance_pct = ((actual_f - planned) / planned * 100) if planned > 0 else 0

        result.append({
            "id": str(item.id),
            "material_id": str(item.material_id),
            "material_name": item.material.name if item.material else "Unknown",
            "unit": item.material.unit if item.material else "",
            "planned_quantity": planned,
            "actual_quantity": actual_f,
            "variance_pct": round(variance_pct, 1),
            "over_budget": variance_pct > 0,
        })
    return result

# ─── Transfer Note CRUD ───────────────────────────────────────────────────────

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
        # Deduct from source project
        log_stock_movement(db, db_transfer.from_project_id, db_transfer.material_id,
                           'transfer_out', float(db_transfer.quantity), received_by,
                           reference_type='transfer_note', reference_id=transfer_id)
        # Add to destination project
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

# ─── Waste Log CRUD ───────────────────────────────────────────────────────────

def log_waste(db: Session, waste: schemas.WasteLogCreate):
    db_waste = models.WasteLog(**waste.dict())
    db.add(db_waste)
    db.commit()
    # Also log in stock ledger and deduct inventory
    log_stock_movement(db, waste.project_id, waste.material_id,
                       'wastage', float(waste.quantity), waste.logged_by,
                       reference_type='waste_log', remarks=waste.reason)
    db.refresh(db_waste)
    return db_waste

def get_waste_logs(db: Session, project_id: uuid.UUID):
    return db.query(models.WasteLog).filter(
        models.WasteLog.project_id == project_id
    ).order_by(models.WasteLog.created_at.desc()).all()

# ─── Low Stock Alerts ─────────────────────────────────────────────────────────

def get_low_stock_alerts(db: Session, owner_id: uuid.UUID):
    """Returns all project-material combos where stock is below min_stock_level."""
    projects = db.query(models.Project).filter(models.Project.owner_id == owner_id).all()
    alerts = []
    for project in projects:
        inventory = db.query(models.ProjectInventory).filter(
            models.ProjectInventory.project_id == project.id
        ).all()
        for item in inventory:
            material = db.query(models.Material).filter(
                models.Material.id == item.material_id
            ).first()
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

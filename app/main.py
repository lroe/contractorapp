from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import func, case
from typing import List, Optional
import uuid
import os
import shutil
from datetime import date
from fastapi import WebSocket, WebSocketDisconnect
import bcrypt

from . import crud, models, schemas
from .database import SessionLocal, engine, get_db

from fastapi.middleware.cors import CORSMiddleware

# Create tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Contractor DB API")

# Ensure uploads directory exists
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# WebSocket Manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except:
                pass

manager = ConnectionManager()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@app.get("/")
def read_root():
    return {"message": "Welcome to Contractor DB API"}

def verify_password(plain_password, hashed_password):
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

# Organizations
@app.post("/organizations/", response_model=schemas.Organization)
def create_organization(org: schemas.OrganizationCreate, db: Session = Depends(get_db)):
    return crud.create_organization(db, org)

@app.get("/organizations/", response_model=List[schemas.Organization])
def list_organizations(db: Session = Depends(get_db)):
    return crud.get_organizations(db)

# Login
@app.post("/login/")
def login(phone: str, password: str, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_phone(db, phone=phone)
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if not verify_password(password, db_user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect password")
        
    return {
        "id": db_user.id,
        "name": db_user.name,
        "role": db_user.role,
        "phone": db_user.phone,
        "organization_id": db_user.organization_id
    }

# Users
@app.post("/users/", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_phone(db, phone=user.phone)
    if db_user:
        raise HTTPException(status_code=400, detail="Phone already registered")
    return crud.create_user(db=db, user=user)

@app.get("/users/", response_model=List[schemas.User])
def list_users(organization_id: uuid.UUID, role: Optional[str] = None, db: Session = Depends(get_db)):
    return crud.get_users(db, organization_id, role)

# Projects
@app.post("/projects/", response_model=schemas.Project)
def create_project(project: schemas.ProjectCreate, db: Session = Depends(get_db)):
    return crud.create_project(db=db, project=project)

@app.get("/projects/", response_model=List[schemas.Project])
def read_projects(
    organization_id: uuid.UUID,
    user_id: Optional[uuid.UUID] = None,
    db: Session = Depends(get_db)
):
    if user_id:
        user = crud.get_user(db, user_id)
        if user and user.role == 'owner':
            return db.query(models.Project).filter(
                models.Project.organization_id == organization_id
            ).all()
        elif user and user.role == 'supervisor':
            return db.query(models.Project).join(models.ProjectUser).filter(
                models.ProjectUser.user_id == user_id
            ).all()
    return crud.get_projects(db, organization_id)

@app.get("/projects/{project_id}/supervisors/", response_model=List[schemas.User])
def get_project_supervisors(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_project_supervisors(db, project_id)

@app.post("/projects/{project_id}/assign/")
def assign_supervisor(project_id: uuid.UUID, user_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.assign_supervisor(db, project_id, user_id)

@app.delete("/projects/{project_id}/unassign/{user_id}")
def unassign_supervisor(project_id: uuid.UUID, user_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.unassign_supervisor(db, project_id, user_id)

# DPR Entries
@app.post("/dpr/", response_model=schemas.DPREntry)
async def create_dpr_entry(dpr: schemas.DPREntryCreate, db: Session = Depends(get_db)):
    db_dpr = crud.create_dpr_entry(db=db, dpr=dpr)
    await manager.broadcast({"type": "NEW_DPR", "project_id": str(db_dpr.project_id)})
    return db_dpr

@app.get("/projects/{project_id}/dpr/", response_model=List[schemas.DPREntry])
def get_project_dpr(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_dpr_entries(db, project_id)

@app.post("/dpr/{dpr_id}/media/")
async def upload_dpr_media(
    dpr_id: uuid.UUID,
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db)
):
    upload_dir = f"uploads/dpr/{dpr_id}"
    os.makedirs(upload_dir, exist_ok=True)
    media_records = []
    for file in files:
        safe_name = f"{uuid.uuid4()}_{file.filename.replace(' ', '_')}"
        file_path = os.path.join(upload_dir, safe_name)
        with open(file_path, "wb") as f:
            shutil.copyfileobj(file.file, f)
        file_url = f"/uploads/dpr/{dpr_id}/{safe_name}"
        media_type = "video" if (file.content_type or "").startswith("video") else "photo"
        db_media = crud.add_dpr_media(db, schemas.DPRMediaCreate(
            dpr_entry_id=dpr_id,
            media_url=file_url,
            media_type=media_type
        ))
        media_records.append(db_media)
    return media_records

# Attendance
@app.post("/attendance/", response_model=schemas.Attendance)
def mark_attendance(attendance: schemas.AttendanceCreate, db: Session = Depends(get_db)):
    return crud.mark_attendance(db, attendance)

@app.get("/projects/{project_id}/attendance-summary/")
def get_attendance_summary(project_id: uuid.UUID, db: Session = Depends(get_db)):
    from sqlalchemy import case
    summary = db.query(
        models.Attendance.entry_date,
        func.sum(case(
            (models.Attendance.status == "present", 1.0),
            (models.Attendance.status == "half_day", 0.5),
            else_=0.0
        )).label("total_man_days"),
        func.sum(case(
            (models.Attendance.status == "present", models.Worker.daily_rate),
            (models.Attendance.status == "half_day", models.Worker.daily_rate * 0.5),
            else_=0.0
        )).label("total_cost")
    ).join(
        models.Worker, models.Attendance.worker_id == models.Worker.id
    ).filter(
        models.Attendance.project_id == project_id
    ).group_by(models.Attendance.entry_date).order_by(models.Attendance.entry_date.desc()).all()
    
    return [
        {
            "date": s.entry_date, 
            "count": float(s.total_man_days),
            "cost": float(s.total_cost or 0)
        } for s in summary
    ]

@app.get("/projects/{project_id}/attendance-details/")
def get_attendance_details(project_id: uuid.UUID, entry_date: date, db: Session = Depends(get_db)):
    details = db.query(
        models.Worker.name,
        models.Worker.daily_rate,
        models.Attendance.status,
        models.Gang.name.label("gang_name")
    ).join(
        models.Attendance, models.Worker.id == models.Attendance.worker_id
    ).outerjoin(
        models.Gang, models.Worker.gang_id == models.Gang.id
    ).filter(
        models.Attendance.project_id == project_id,
        models.Attendance.entry_date == entry_date
    ).all()
    
    return [
        {
            "worker_name": d.name,
            "rate": float(d.daily_rate or 0),
            "status": d.status,
            "gang": d.gang_name
        } for d in details
    ]

@app.get("/gangs/{gang_id}/attendance/")
def get_gang_attendance(gang_id: uuid.UUID, entry_date: date, db: Session = Depends(get_db)):
    return db.query(models.Attendance).filter(
        models.Attendance.gang_id == gang_id,
        models.Attendance.entry_date == entry_date
    ).all()
@app.get("/materials/", response_model=List[schemas.Material])
def read_materials(organization_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_materials(db, organization_id)

@app.post("/materials/", response_model=schemas.Material)
def create_material(material: schemas.MaterialCreate, db: Session = Depends(get_db)):
    return crud.create_material(db, material)

# Inventory
@app.get("/projects/{project_id}/inventory/", response_model=List[schemas.ProjectInventory])
def read_project_inventory(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_project_inventory(db, project_id)

# Vendors
@app.post("/vendors/", response_model=schemas.Vendor)
def create_vendor(vendor: schemas.VendorCreate, db: Session = Depends(get_db)):
    return crud.create_vendor(db, vendor)

@app.get("/vendors/", response_model=List[schemas.Vendor])
def list_vendors(organization_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_vendors(db, organization_id)

@app.post("/vendor-prices/", response_model=schemas.VendorPrice)
def create_vendor_price(price: schemas.VendorPriceCreate, db: Session = Depends(get_db)):
    return crud.create_vendor_price(db, price)

@app.get("/vendor-prices/")
def list_vendor_prices(material_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_vendor_prices(db, material_id)

# Purchase Orders
@app.post("/purchase-orders/", response_model=schemas.PurchaseOrder)
async def create_purchase_order(po: schemas.PurchaseOrderCreate, db: Session = Depends(get_db)):
    db_po = crud.create_purchase_order(db, po)
    await manager.broadcast({"type": "NEW_PO", "project_id": str(db_po.project_id)})
    return db_po

@app.get("/purchase-orders/")
def list_purchase_orders(organization_id: uuid.UUID, project_id: Optional[uuid.UUID] = None, db: Session = Depends(get_db)):
    return crud.get_purchase_orders(db, organization_id, project_id)

@app.patch("/purchase-orders/{po_id}/status")
async def update_po_status(po_id: uuid.UUID, update: schemas.PurchaseOrderStatusUpdate, db: Session = Depends(get_db)):
    db_po = crud.update_po_status(db, po_id, update.status, update.approved_by)
    await manager.broadcast({"type": "PO_UPDATED", "project_id": str(db_po.project_id)})
    return db_po

# BOQ
@app.post("/boq/", response_model=schemas.BOQItem)
def upsert_boq(boq: schemas.BOQItemCreate, db: Session = Depends(get_db)):
    return crud.upsert_boq_item(db, boq)

@app.get("/projects/{project_id}/boq/")
def get_boq(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_boq_with_actuals(db, project_id)

# Stock Ledger
@app.get("/projects/{project_id}/stock-ledger/", response_model=List[schemas.StockLedgerEntry])
def get_stock_ledger(project_id: uuid.UUID, material_id: Optional[uuid.UUID] = None, db: Session = Depends(get_db)):
    return crud.get_stock_ledger(db, project_id, material_id)

# Transfers
@app.post("/transfer-notes/", response_model=schemas.TransferNote)
async def create_transfer_note(transfer: schemas.TransferNoteCreate, db: Session = Depends(get_db)):
    db_t = crud.create_transfer_note(db, transfer)
    await manager.broadcast({"type": "NEW_TRANSFER", "project_id": str(db_t.to_project_id)})
    return db_t

@app.get("/projects/{project_id}/transfer-notes/")
def get_transfer_notes(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_transfer_notes(db, project_id)

@app.patch("/transfer-notes/{transfer_id}/receive")
def receive_transfer(transfer_id: uuid.UUID, received_by: uuid.UUID, db: Session = Depends(get_db)):
    return crud.confirm_transfer_received(db, transfer_id, received_by)

# Waste Logs
@app.post("/waste-logs/", response_model=schemas.WasteLog)
def log_waste(waste: schemas.WasteLogCreate, db: Session = Depends(get_db)):
    return crud.log_waste(db, waste)

@app.get("/projects/{project_id}/waste-logs/")
def get_waste_logs(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_waste_logs(db, project_id)

# Recent Activity
@app.get("/recent-activity/")
def get_recent_activity(
    organization_id: uuid.UUID,
    user_id: Optional[uuid.UUID] = None,
    project_id: Optional[uuid.UUID] = None, 
    limit: int = 15, 
    db: Session = Depends(get_db)
):
    if project_id:
        allowed_project_ids = [project_id]
    elif user_id:
        user = crud.get_user(db, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        if user.role == 'owner':
            projects = crud.get_projects(db, organization_id)
            allowed_project_ids = [p.id for p in projects]
        else:
            projects = db.query(models.Project).join(models.ProjectUser).filter(
                models.ProjectUser.user_id == user_id
            ).all()
            allowed_project_ids = [p.id for p in projects]
    else:
        projects = crud.get_projects(db, organization_id)
        allowed_project_ids = [p.id for p in projects]

    if not allowed_project_ids:
        return []

    dprs = db.query(models.DPREntry).filter(models.DPREntry.project_id.in_(allowed_project_ids)).order_by(models.DPREntry.created_at.desc()).limit(limit).all()
    pos = db.query(models.PurchaseOrder).filter(models.PurchaseOrder.project_id.in_(allowed_project_ids)).order_by(models.PurchaseOrder.created_at.desc()).limit(limit).all()
    
    activity = []
    for d in dprs:
        activity.append({
            "type": "dpr",
            "timestamp": d.created_at,
            "data": {
                "id": str(d.id),
                "project_id": str(d.project_id),
                "entry_date": d.entry_date.isoformat(),
                "remarks": d.remarks,
                "media": [{"media_url": m.media_url} for m in d.media]
            }
        })
    for p in pos:
        activity.append({
            "type": "purchase_order",
            "timestamp": p.created_at,
            "data": {
                "id": str(p.id),
                "po_number": p.po_number,
                "status": p.status,
                "total_amount": float(p.total_amount)
            }
        })
    
    activity.sort(key=lambda x: x["timestamp"], reverse=True)
    return activity[:limit]

# Dashboard Stats
@app.get("/dashboard-stats/")
def get_dashboard_stats(
    organization_id: uuid.UUID,
    user_id: uuid.UUID,
    project_id: Optional[uuid.UUID] = None,
    db: Session = Depends(get_db)
):
    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.role == 'owner':
        active_projects = db.query(models.Project).filter(
            models.Project.organization_id == organization_id,
            models.Project.status == 'active'
        ).count()
        total_revenue = db.query(func.sum(models.Transaction.amount)).join(models.Project).filter(
            models.Project.organization_id == organization_id,
            models.Transaction.type == 'INCOME'
        ).scalar() or 0
        return {
            "stat1_label": "Active Projects",
            "stat1_value": str(active_projects).zfill(2),
            "stat2_label": "Total Revenue",
            "stat2_value": f"₹{float(total_revenue)}"
        }
    else:
        if not project_id:
            return {"stat1_label": "Tasks", "stat1_value": "00", "stat2_label": "Active", "stat2_value": "00"}
        pending = db.query(models.Task).filter(models.Task.project_id == project_id, models.Task.status == 'pending').count()
        active = db.query(models.Task).filter(models.Task.project_id == project_id, models.Task.status == 'in_progress').count()
        return {"stat1_label": "Pending Tasks", "stat1_value": str(pending).zfill(2), "stat2_label": "Active Tasks", "stat2_value": str(active).zfill(2)}

# Low Stock Alerts
@app.get("/low-stock-alerts/")
def get_low_stock_alerts(organization_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_low_stock_alerts(db, organization_id)

# Material Manager Stats
@app.get("/material-manager/dashboard/")
def material_manager_dashboard(organization_id: uuid.UUID, db: Session = Depends(get_db)):
    total_pos = db.query(models.PurchaseOrder).filter(
        models.PurchaseOrder.organization_id == organization_id,
        models.PurchaseOrder.status == 'draft'
    ).count()
    total_vendors = db.query(models.Vendor).filter(
        models.Vendor.organization_id == organization_id,
        models.Vendor.is_active == True
    ).count()
    total_materials = db.query(models.Material).filter(
        models.Material.organization_id == organization_id
    ).count()
    pending_transfers = db.query(models.TransferNote).join(models.Project, models.TransferNote.to_project_id == models.Project.id).filter(
        models.Project.organization_id == organization_id,
        models.TransferNote.status == 'pending'
    ).count()
    return {
        "pending_pos": total_pos,
        "active_vendors": total_vendors,
        "total_materials": total_materials,
        "pending_transfers": pending_transfers,
    }

# Workers & Gangs
@app.post("/gangs/", response_model=schemas.Gang)
def create_gang(gang: schemas.GangCreate, db: Session = Depends(get_db)):
    return crud.create_gang(db, gang)

@app.get("/projects/{project_id}/gangs/", response_model=List[schemas.Gang])
def read_gangs(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_project_gangs(db, project_id)

@app.post("/workers/", response_model=schemas.Worker)
def create_worker(worker: schemas.WorkerCreate, db: Session = Depends(get_db)):
    return crud.create_worker(db, worker)

@app.get("/gangs/{gang_id}/workers/", response_model=List[schemas.Worker])
def read_workers(gang_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_gang_workers(db, gang_id)

# Work Types
@app.get("/work-types/", response_model=List[schemas.WorkType])
def list_work_types(organization_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_work_types(db, organization_id)

@app.post("/work-types/", response_model=schemas.WorkType)
def create_work_type(wt: schemas.WorkTypeCreate, db: Session = Depends(get_db)):
    return crud.create_work_type(db, wt)

# Tasks
@app.post("/tasks/", response_model=schemas.Task)
def create_task(task: schemas.TaskCreate, db: Session = Depends(get_db)):
    db_task = models.Task(**task.dict())
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    return db_task

@app.get("/projects/{project_id}/tasks/", response_model=List[schemas.Task])
def get_project_tasks(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return db.query(models.Task).filter(models.Task.project_id == project_id).order_by(models.Task.created_at.desc()).all()

@app.patch("/tasks/{task_id}/status/")
async def update_task_status(task_id: uuid.UUID, status: str, db: Session = Depends(get_db)):
    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if not task: raise HTTPException(status_code=404, detail="Task not found")
    task.status = status
    db.commit()
    db.refresh(task)
    await manager.broadcast({"type": "TASK_UPDATED", "project_id": str(task.project_id)})
    return task

# Documents
@app.post("/projects/{project_id}/documents/", response_model=List[schemas.ProjectDocument])
async def upload_project_documents(
    project_id: uuid.UUID,
    uploaded_by: uuid.UUID = Form(...),
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db)
):
    upload_dir = f"uploads/projects/{project_id}/documents"
    os.makedirs(upload_dir, exist_ok=True)
    docs = []
    for file in files:
        safe_name = f"{uuid.uuid4()}_{file.filename.replace(' ', '_')}"
        file_path = os.path.join(upload_dir, safe_name)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        db_doc = crud.create_project_document(db, schemas.ProjectDocumentCreate(
            project_id=project_id, file_name=file.filename, file_url=f"/uploads/projects/{project_id}/documents/{safe_name}", uploaded_by=uploaded_by
        ))
        docs.append(db_doc)
    await manager.broadcast({"type": "NEW_DOCUMENT", "project_id": str(project_id)})
    return docs

@app.get("/projects/{project_id}/documents/", response_model=List[schemas.ProjectDocument])
def get_project_documents(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_project_documents(db, project_id)

# Material Requests
@app.get("/projects/{project_id}/material-requests/", response_model=List[schemas.MaterialRequest])
def get_material_requests(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_material_requests(db, project_id)

@app.post("/material-requests/", response_model=schemas.MaterialRequest)
async def create_material_request(req: schemas.MaterialRequestCreate, db: Session = Depends(get_db)):
    db_req = crud.create_material_request(db, req)
    await manager.broadcast({"type": "NEW_MATERIAL_REQUEST", "project_id": str(db_req.project_id)})
    return db_req

@app.patch("/material-requests/{request_id}/status/", response_model=schemas.MaterialRequest)
async def update_material_request_status(
    request_id: uuid.UUID, 
    status: str, 
    received_remarks: Optional[str] = None, 
    db: Session = Depends(get_db)
):
    db_req = crud.update_material_request_status(db, request_id, status, received_remarks)
    await manager.broadcast({"type": "MATERIAL_REQUEST_UPDATED", "project_id": str(db_req.project_id)})
    return db_req

@app.post("/material-requests/{request_id}/media/")
async def upload_material_request_media(
    request_id: uuid.UUID,
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db)
):
    upload_dir = f"uploads/material_requests/{request_id}"
    os.makedirs(upload_dir, exist_ok=True)
    media_records = []
    for file in files:
        safe_name = f"{uuid.uuid4()}_{file.filename.replace(' ', '_')}"
        file_path = os.path.join(upload_dir, safe_name)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        file_url = f"/uploads/material_requests/{request_id}/{safe_name}"
        db_media = crud.add_material_request_media(db, request_id, file_url)
        media_records.append(db_media)
    return media_records

# Material Usage (Consumption)
@app.post("/material-usage/", response_model=schemas.MaterialUsage)
async def log_material_usage(usage: schemas.MaterialUsageCreate, db: Session = Depends(get_db)):
    db_usage = crud.log_material_usage(db, usage)
    await manager.broadcast({"type": "MATERIAL_CONSUMED", "project_id": str(db_usage.project_id)})
    await manager.broadcast({"type": "NEW_TRANSACTION", "project_id": str(db_usage.project_id)})
    return db_usage

# Transactions
@app.get("/projects/{project_id}/transactions/", response_model=List[schemas.Transaction])
def get_transactions(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_transactions(db, project_id)

@app.post("/transactions/", response_model=schemas.Transaction)
async def create_transaction(tx: schemas.TransactionCreate, db: Session = Depends(get_db)):
    db_tx = crud.create_transaction(db, tx)
    await manager.broadcast({"type": "NEW_TRANSACTION", "project_id": str(db_tx.project_id)})
    return db_tx

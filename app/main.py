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

# Users
@app.post("/users/", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_phone(db, phone=user.phone)
    if db_user:
        raise HTTPException(status_code=400, detail="Phone already registered")
    return crud.create_user(db=db, user=user)

@app.get("/supervisors/", response_model=List[schemas.User])
def list_supervisors(db: Session = Depends(get_db)):
    return db.query(models.User).filter(models.User.role == 'supervisor').all()

# Projects
@app.post("/projects/", response_model=schemas.Project)
def create_project(project: schemas.ProjectCreate, db: Session = Depends(get_db)):
    return crud.create_project(db=db, project=project)

@app.get("/projects/", response_model=List[schemas.Project])
def read_projects(
    user_id: Optional[uuid.UUID] = None,
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db)
):
    query = db.query(models.Project)
    if user_id:
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if user and user.role == 'owner':
            query = query.filter(models.Project.owner_id == user_id)
        elif user and user.role == 'supervisor':
            query = query.join(models.ProjectUser).filter(models.ProjectUser.user_id == user_id)
    return query.offset(skip).limit(limit).all()

# DPR Entries
@app.post("/dpr/", response_model=schemas.DPREntry)
async def create_dpr_entry(dpr: schemas.DPREntryCreate, db: Session = Depends(get_db)):
    db_dpr = crud.create_dpr_entry(db=db, dpr=dpr)
    await manager.broadcast({"type": "NEW_DPR", "project_id": str(db_dpr.project_id)})
    return db_dpr

# Multi-media Upload for DPR
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
        safe_name = file.filename.replace(" ", "_")
        file_path = f"{upload_dir}/{safe_name}"
        with open(file_path, "wb") as f:
            shutil.copyfileobj(file.file, f)
        file_url = f"/uploads/dpr/{dpr_id}/{safe_name}"
        media_type = "video" if (file.content_type or "").startswith("video") else "photo"
        db_media = crud.add_dpr_media(db, schemas.DPRMediaCreate(
            dpr_entry_id=dpr_id,
            media_url=file_url,
            media_type=media_type
        ))
        media_records.append({"id": str(db_media.id), "media_url": db_media.media_url, "media_type": db_media.media_type})
    return {"message": f"Uploaded {len(files)} files", "media": media_records}

@app.get("/dpr/{dpr_id}/media/")
def get_dpr_media(dpr_id: uuid.UUID, db: Session = Depends(get_db)):
    return db.query(models.DPRMedia).filter(models.DPRMedia.dpr_entry_id == dpr_id).all()

# Login (Managed below)

import bcrypt

def verify_password(plain_password, hashed_password):
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

# Login
@app.post("/login/")
def login(phone: str, password: str, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_phone(db, phone=phone)
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if not verify_password(password, db_user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect password")
        
    return {"id": db_user.id, "name": db_user.name, "role": db_user.role, "phone": db_user.phone}

# Project Assignment
@app.post("/projects/{project_id}/assign/")
def assign_supervisor(project_id: uuid.UUID, user_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.assign_user_to_project(db, project_id, user_id, role='supervisor')

@app.get("/projects/{project_id}/supervisors/")
def get_supervisors(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_project_supervisors(db, project_id)

@app.delete("/projects/{project_id}/unassign/{user_id}")
def unassign_supervisor(project_id: uuid.UUID, user_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.unassign_user_from_project(db, project_id, user_id)

@app.get("/users/{user_id}/projects/")
def get_user_projects(user_id: uuid.UUID, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.role == 'owner':
        return db.query(models.Project).filter(models.Project.owner_id == user_id).all()
    else:
        return db.query(models.Project).join(models.ProjectUser).filter(
            models.ProjectUser.user_id == user_id
        ).all()

@app.get("/projects/{project_id}/dpr/")
def get_project_dpr(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return db.query(models.DPREntry).filter(models.DPREntry.project_id == project_id).order_by(models.DPREntry.entry_date.desc()).all()

@app.get("/projects/{project_id}/attendance-summary/")
def get_attendance_summary(project_id: uuid.UUID, db: Session = Depends(get_db)):
    summary = db.query(
        models.Attendance.entry_date,
        func.sum(case(
            (models.Attendance.status == "present", 1.0),
            (models.Attendance.status == "half_day", 0.5),
            else_=0.0
        )).label("total_man_days")
    ).filter(
        models.Attendance.project_id == project_id
    ).group_by(models.Attendance.entry_date).order_by(models.Attendance.entry_date.desc()).all()
    
    return [{"date": s.entry_date, "count": float(s.total_man_days)} for s in summary]

@app.get("/projects/{project_id}/attendance-detail/")
def get_attendance_detail(project_id: uuid.UUID, date: date, db: Session = Depends(get_db)):
    attendance = db.query(models.Attendance, models.Worker).join(
        models.Worker, models.Attendance.worker_id == models.Worker.id
    ).filter(
        models.Attendance.project_id == project_id,
        models.Attendance.entry_date == date
    ).all()
    
    return [
        {
            "worker_name": w.name,
            "status": a.status,
            "skill_type": w.skill_type
        } for a, w in attendance
    ]

@app.get("/gangs/{gang_id}/attendance/{date}")
def get_gang_attendance(gang_id: uuid.UUID, date: date, db: Session = Depends(get_db)):
    return crud.get_gang_attendance(db, gang_id, date)

@app.get("/dpr/recent/")
def get_recent_dpr(limit: int = 5, db: Session = Depends(get_db)):
    return db.query(models.DPREntry).order_by(models.DPREntry.created_at.desc()).limit(limit).all()

@app.get("/recent-activity/")
def get_recent_activity(
    user_id: Optional[uuid.UUID] = None,
    project_id: Optional[uuid.UUID] = None, 
    limit: int = 15, 
    db: Session = Depends(get_db)
):
    # Determine allowed project IDs
    if project_id:
        allowed_project_ids = [project_id]
    elif user_id:
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
            
        if user.role == 'owner':
            projects = db.query(models.Project).filter(models.Project.owner_id == user_id).all()
            if not projects:
                return [] # No projects, so no activity
            allowed_project_ids = [p.id for p in projects]
        else:
            # Supervisor: Only see projects they are assigned to
            assigned_projects = db.query(models.Project).join(models.ProjectUser).filter(
                models.ProjectUser.user_id == user_id
            ).all()
            if not assigned_projects:
                return []
            allowed_project_ids = [p.id for p in assigned_projects]
    else:
        allowed_project_ids = []

    # Fetch DPRs
    dpr_query = db.query(models.DPREntry)
    if allowed_project_ids:
        dpr_query = dpr_query.filter(models.DPREntry.project_id.in_(allowed_project_ids))
    elif user_id and user.role == 'owner':
        # This case is handled by return [] above, but for safety:
        return []
        
    dprs = dpr_query.order_by(models.DPREntry.created_at.desc()).limit(limit).all()
    
    # Fetch Material Requests
    mr_query = db.query(models.MaterialRequest)
    if allowed_project_ids:
        mr_query = mr_query.filter(models.MaterialRequest.project_id.in_(allowed_project_ids))
    mrs = mr_query.order_by(models.MaterialRequest.created_at.desc()).limit(limit).all()
    
    # Fetch Recent Attendance
    att_query = db.query(models.Attendance)
    if allowed_project_ids:
        att_query = att_query.filter(models.Attendance.project_id.in_(allowed_project_ids))
    atts = att_query.order_by(models.Attendance.created_at.desc()).limit(limit).all()
    
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
    
    for m in mrs:
        material = db.query(models.Material).filter(models.Material.id == m.material_id).first()
        project = db.query(models.Project).filter(models.Project.id == m.project_id).first()
        activity.append({
            "type": "material_request",
            "timestamp": m.created_at,
            "data": {
                "id": str(m.id),
                "project_id": str(m.project_id),
                "project_name": project.name if project else "Project",
                "material_name": material.name if material else "Material",
                "quantity": float(m.quantity),
                "unit": material.unit if material else "",
                "status": m.status,
                "created_at": m.created_at.isoformat()
            }
        })
        
    for a in atts:
        project = db.query(models.Project).filter(models.Project.id == a.project_id).first()
        worker = db.query(models.Worker).filter(models.Worker.id == a.worker_id).first()
        activity.append({
            "type": "attendance",
            "timestamp": a.created_at,
            "data": {
                "id": str(a.id),
                "project_name": project.name if project else "Project",
                "worker_name": worker.name if worker else "Worker",
                "status": a.status,
                "entry_date": a.entry_date.isoformat()
            }
        })
        
    activity.sort(key=lambda x: x["timestamp"], reverse=True)
    return activity[:limit]

# Work Types
@app.get("/work-types/", response_model=List[schemas.WorkType])
def list_work_types(db: Session = Depends(get_db)):
    return db.query(models.WorkType).all()

@app.post("/work-types/", response_model=schemas.WorkType)
def create_work_type(wt: schemas.WorkTypeCreate, db: Session = Depends(get_db)):
    db_wt = models.WorkType(**wt.dict())
    db.add(db_wt)
    db.commit()
    db.refresh(db_wt)
    return db_wt

# Tasks
@app.post("/projects/{project_id}/tasks/", response_model=schemas.Task)
def create_task(project_id: uuid.UUID, task: schemas.TaskCreate, db: Session = Depends(get_db)):
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
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    if status not in ['pending', 'in_progress', 'completed']:
        raise HTTPException(status_code=400, detail="Invalid status")
    task.status = status
    db.commit()
    db.refresh(task)
    await manager.broadcast({"type": "TASK_UPDATED", "project_id": str(task.project_id)})
    return task

@app.get("/tasks/{task_id}/dpr/")
def get_task_dpr(task_id: uuid.UUID, db: Session = Depends(get_db)):
    return db.query(models.DPREntry).filter(
        models.DPREntry.linked_task_id == task_id
    ).order_by(models.DPREntry.entry_date.desc()).all()

# Material Master
@app.get("/materials/", response_model=List[schemas.Material])
def read_materials(db: Session = Depends(get_db)):
    return crud.get_materials(db)

@app.post("/materials/", response_model=schemas.Material)
def create_material(material: schemas.MaterialCreate, db: Session = Depends(get_db)):
    return crud.create_material(db, material)

# Inventory
@app.get("/projects/{project_id}/inventory/", response_model=List[schemas.ProjectInventory])
def read_project_inventory(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return db.query(models.ProjectInventory).filter(models.ProjectInventory.project_id == project_id).all()

# Requests (Indents)
@app.get("/projects/{project_id}/material-requests/", response_model=List[schemas.MaterialRequest])
def read_material_requests(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_material_requests(db, project_id)

@app.post("/material-requests/", response_model=schemas.MaterialRequest)
async def create_material_request(request: schemas.MaterialRequestCreate, db: Session = Depends(get_db)):
    db_request = crud.create_material_request(db, request)
    await manager.broadcast({"type": "NEW_MATERIAL_REQUEST", "project_id": str(db_request.project_id)})
    return db_request

@app.patch("/material-requests/{request_id}/", response_model=schemas.MaterialRequest)
async def update_material_request_status(request_id: uuid.UUID, update: schemas.MaterialRequestUpdate, db: Session = Depends(get_db)):
    db_request = crud.update_material_request_status(db, request_id, update.status, update.received_remarks)
    await manager.broadcast({"type": "MATERIAL_REQUEST_UPDATED", "project_id": str(db_request.project_id)})
    return db_request

@app.post("/material-requests/{request_id}/media/")
async def upload_material_request_media(request_id: uuid.UUID, files: List[UploadFile] = File(...), db: Session = Depends(get_db)):
    uploaded_files = []
    for file in files:
        file_extension = os.path.splitext(file.filename)[1]
        unique_filename = f"req_{request_id}_{uuid.uuid4()}{file_extension}"
        file_path = f"uploads/{unique_filename}"
        
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        media_url = f"/uploads/{unique_filename}"
        db_media = crud.create_material_request_media(db, request_id, media_url)
        uploaded_files.append(db_media)
    
    return uploaded_files

# Usage
@app.post("/material-usage/", response_model=schemas.MaterialUsage)
async def log_material_usage(usage: schemas.MaterialUsageCreate, db: Session = Depends(get_db)):
    db_usage = crud.log_material_usage(db, usage)
    await manager.broadcast({"type": "MATERIAL_USAGE_LOGGED", "project_id": str(db_usage.project_id)})
    return db_usage

@app.get("/projects/{project_id}/material-usage/", response_model=List[schemas.MaterialUsage])
def read_material_usage(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return db.query(models.MaterialUsage).filter(models.MaterialUsage.project_id == project_id).all()

# Transactions
@app.post("/transactions/", response_model=schemas.Transaction)
def create_transaction(transaction: schemas.TransactionCreate, db: Session = Depends(get_db)):
    return crud.create_transaction(db, transaction)

@app.get("/projects/{project_id}/transactions/", response_model=List[schemas.Transaction])
def read_transactions(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_project_transactions(db, project_id)

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

@app.post("/attendance/", response_model=schemas.Attendance)
def mark_attendance(attendance: schemas.AttendanceCreate, db: Session = Depends(get_db)):
    return crud.mark_attendance(db, attendance)

# Project Documents
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
            
        file_url = f"/uploads/projects/{project_id}/documents/{safe_name}"
        file_type = file.filename.split('.')[-1] if '.' in file.filename else "unknown"
        
        doc_create = schemas.ProjectDocumentCreate(
            project_id=project_id,
            name=file.filename, # Use original filename as the document name
            file_url=file_url,
            file_type=file_type,
            uploaded_by=uploaded_by
        )
        
        db_doc = crud.create_project_document(db, doc_create)
        docs.append(db_doc)
    
    await manager.broadcast({"type": "NEW_DOCUMENT", "project_id": str(project_id)})
    return docs

@app.get("/projects/{project_id}/documents/", response_model=List[schemas.ProjectDocument])
def get_project_documents(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_project_documents(db, project_id)

# Dashboard Stats
@app.get("/dashboard-stats/")
def get_dashboard_stats(
    user_id: uuid.UUID,
    project_id: Optional[uuid.UUID] = None,
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.role == 'owner':
        active_projects = db.query(models.Project).filter(
            models.Project.status == 'active',
            models.Project.owner_id == user_id
        ).count()
        
        # Sum revenue for projects owned by this user
        total_revenue = db.query(func.sum(models.Transaction.amount)).join(models.Project).filter(
            models.Transaction.type == 'INCOME',
            models.Project.owner_id == user_id
        ).scalar() or 0
        
        return {
            "stat1_label": "Active Projects",
            "stat1_value": str(active_projects).zfill(2),
            "stat2_label": "Total Revenue",
            "stat2_value": f"₹{float(total_revenue)/1000:.1f}k" if total_revenue >= 1000 else f"₹{float(total_revenue)}"
        }
    else:
        # Supervisor
        if not project_id:
            return {
                "stat1_label": "Pending Tasks",
                "stat1_value": "00",
                "stat2_label": "Active Tasks",
                "stat2_value": "00"
            }
        
        pending_tasks = db.query(models.Task).filter(
            models.Task.project_id == project_id,
            models.Task.status == 'pending'
        ).count()
        
        in_progress_tasks = db.query(models.Task).filter(
            models.Task.project_id == project_id,
            models.Task.status == 'in_progress'
        ).count()
        
        return {
            "stat1_label": "Pending Tasks",
            "stat1_value": str(pending_tasks).zfill(2),
            "stat2_label": "Active Tasks",
            "stat2_value": str(in_progress_tasks).zfill(2)
        }

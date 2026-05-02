from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import func, case
from typing import List, Optional
import uuid
import os
import shutil

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
def read_projects(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return crud.get_projects(db, skip=skip, limit=limit)

# DPR Entries
@app.post("/dpr/", response_model=schemas.DPREntry)
def create_dpr_entry(dpr: schemas.DPREntryCreate, db: Session = Depends(get_db)):
    return crud.create_dpr_entry(db=db, dpr=dpr)

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

@app.get("/users/{user_id}/projects/")
def get_user_projects(user_id: uuid.UUID, db: Session = Depends(get_db)):
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

@app.get("/dpr/recent/")
def get_recent_dpr(limit: int = 5, db: Session = Depends(get_db)):
    return db.query(models.DPREntry).order_by(models.DPREntry.created_at.desc()).limit(limit).all()

@app.get("/recent-activity/")
def get_recent_activity(project_id: Optional[uuid.UUID] = None, limit: int = 15, db: Session = Depends(get_db)):
    # Fetch DPRs
    dpr_query = db.query(models.DPREntry)
    if project_id:
        dpr_query = dpr_query.filter(models.DPREntry.project_id == project_id)
    dprs = dpr_query.order_by(models.DPREntry.created_at.desc()).limit(limit).all()
    
    # Fetch Material Requests
    mr_query = db.query(models.MaterialRequest)
    if project_id:
        mr_query = mr_query.filter(models.MaterialRequest.project_id == project_id)
    mrs = mr_query.order_by(models.MaterialRequest.created_at.desc()).limit(limit).all()
    
    # Fetch Recent Attendance
    att_query = db.query(models.Attendance)
    if project_id:
        att_query = att_query.filter(models.Attendance.project_id == project_id)
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
def update_task_status(task_id: uuid.UUID, status: str, db: Session = Depends(get_db)):
    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    if status not in ['pending', 'in_progress', 'completed']:
        raise HTTPException(status_code=400, detail="Invalid status")
    task.status = status
    db.commit()
    db.refresh(task)
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
def create_material_request(request: schemas.MaterialRequestCreate, db: Session = Depends(get_db)):
    return crud.create_material_request(db, request)

@app.patch("/material-requests/{request_id}/", response_model=schemas.MaterialRequest)
def update_material_request_status(request_id: uuid.UUID, update: schemas.MaterialRequestUpdate, db: Session = Depends(get_db)):
    return crud.update_material_request_status(db, request_id, update.status)

# Usage
@app.post("/material-usage/", response_model=schemas.MaterialUsage)
def log_material_usage(usage: schemas.MaterialUsageCreate, db: Session = Depends(get_db)):
    return crud.log_material_usage(db, usage)

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

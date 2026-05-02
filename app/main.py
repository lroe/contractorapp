from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
import uuid

from . import crud, models, schemas
from .database import SessionLocal, engine, get_db

from fastapi.middleware.cors import CORSMiddleware

# Create tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Contractor DB API")

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
    # This is a placeholder for file storage logic (e.g. S3 or local disk)
    # For now, we'll just save the names to the DB
    media_records = []
    for file in files:
        # In a real app: save file to storage, get URL
        file_url = f"/media/{dpr_id}/{file.filename}"
        media_type = "video" if file.content_type.startswith("video") else "photo"
        
        db_media = crud.add_dpr_media(db, schemas.DPRMediaCreate(
            dpr_entry_id=dpr_id,
            media_url=file_url,
            media_type=media_type
        ))
        media_records.append(db_media)
    
    return {"message": f"Uploaded {len(files)} files", "media": media_records}

# Gangs
@app.post("/gangs/")
def create_gang(project_id: uuid.UUID, name: str, supervisor_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.create_gang(db, project_id, name, supervisor_id)

@app.get("/projects/{project_id}/gangs/")
def get_gangs(project_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_gangs(db, project_id)

# Workers
@app.post("/workers/")
def create_worker(project_id: uuid.UUID, name: str, phone: str = None, skill_type: str = None, db: Session = Depends(get_db)):
    return crud.create_worker(db, project_id, name, phone, skill_type)

@app.post("/workers/{worker_id}/assign-gang/{gang_id}")
def assign_worker_to_gang(worker_id: uuid.UUID, gang_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.assign_worker_to_gang(db, worker_id, gang_id)

@app.get("/gangs/{gang_id}/workers/")
def get_gang_workers(gang_id: uuid.UUID, db: Session = Depends(get_db)):
    return crud.get_workers_by_gang(db, gang_id)

# Attendance
@app.post("/attendance/", response_model=schemas.Attendance)
def mark_attendance(attendance: schemas.AttendanceCreate, db: Session = Depends(get_db)):
    return crud.mark_attendance(
        db, 
        attendance.project_id, 
        attendance.worker_id, 
        attendance.gang_id, 
        attendance.entry_date, 
        attendance.status, 
        attendance.marked_by
    )

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

@app.get("/dpr/recent/")
def get_recent_dpr(limit: int = 5, db: Session = Depends(get_db)):
    return db.query(models.DPREntry).order_by(models.DPREntry.created_at.desc()).limit(limit).all()

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

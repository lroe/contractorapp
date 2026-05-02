from sqlalchemy.orm import Session
from . import models, schemas
import uuid

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
def mark_attendance(db: Session, project_id: uuid.UUID, worker_id: uuid.UUID, gang_id: uuid.UUID, entry_date: any, status: str, marked_by: uuid.UUID):
    db_attendance = models.Attendance(
        project_id=project_id,
        worker_id=worker_id,
        gang_id=gang_id,
        entry_date=entry_date,
        status=status,
        marked_by=marked_by
    )
    db.add(db_attendance)
    db.commit()
    db.refresh(db_attendance)
    return db_attendance

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

def update_material_request_status(db: Session, request_id: uuid.UUID, status: str):
    db_request = db.query(models.MaterialRequest).filter(models.MaterialRequest.id == request_id).first()
    if db_request:
        db_request.status = status
        # If received, auto-update inventory
        if status == "received":
            update_inventory(db, db_request.project_id, db_request.material_id, float(db_request.quantity))
        db.commit()
        db.refresh(db_request)
    return db_request

# Usage
def log_material_usage(db: Session, usage: schemas.MaterialUsageCreate):
    db_usage = models.MaterialUsage(**usage.dict())
    db.add(db_usage)
    # Deduct from inventory
    update_inventory(db, usage.project_id, usage.material_id, -float(usage.quantity))
    db.commit()
    db.refresh(db_usage)
    return db_usage

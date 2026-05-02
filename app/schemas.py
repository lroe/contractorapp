from pydantic import BaseModel, EmailStr, Field
from uuid import UUID
from datetime import datetime, date
from typing import Optional, List
from decimal import Decimal

# User Schemas
class UserBase(BaseModel):
    name: str
    phone: str
    email: Optional[EmailStr] = None
    role: str

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: UUID
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

# Project Schemas
class ProjectBase(BaseModel):
    name: str
    code: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    status: str = "active"

class ProjectCreate(ProjectBase):
    owner_id: UUID

class Project(ProjectBase):
    id: UUID
    owner_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# WorkType Schemas
class WorkTypeBase(BaseModel):
    name: str
    unit: Optional[str] = None

class WorkTypeCreate(WorkTypeBase):
    pass

class WorkType(WorkTypeBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# Task Schemas
class TaskBase(BaseModel):
    project_id: UUID
    work_type_id: UUID
    block_id: Optional[UUID] = None
    floor_id: Optional[UUID] = None
    area_id: Optional[UUID] = None
    target_quantity: Decimal
    unit: Optional[str] = None
    deadline: Optional[date] = None
    status: str = "pending"

class TaskCreate(TaskBase):
    created_by: UUID

class Task(TaskBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# DPR Media Schemas
class DPRMediaBase(BaseModel):
    media_url: str
    media_type: str = "photo"

class DPRMediaCreate(DPRMediaBase):
    dpr_entry_id: UUID

class DPRMedia(DPRMediaBase):
    id: UUID
    uploaded_at: datetime

    class Config:
        from_attributes = True

# DPR Entry Schemas
class DPREntryBase(BaseModel):
    project_id: UUID
    supervisor_id: UUID
    entry_date: date
    work_type_id: Optional[UUID] = None
    block_id: Optional[UUID] = None
    floor_id: Optional[UUID] = None
    area_id: Optional[UUID] = None
    quantity: Optional[Decimal] = 0
    remarks: Optional[str] = None
    linked_task_id: Optional[UUID] = None

class DPREntryCreate(DPREntryBase):
    pass

class DPREntry(DPREntryBase):
    id: UUID
    created_at: datetime
    media: List[DPRMedia] = []

    class Config:
        from_attributes = True

# Attendance Schemas
class AttendanceBase(BaseModel):
    project_id: UUID
    worker_id: UUID
    gang_id: Optional[UUID] = None
    entry_date: date
    status: str

class AttendanceCreate(AttendanceBase):
    marked_by: UUID

class Attendance(AttendanceBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# Material Schemas
class MaterialBase(BaseModel):
    name: str
    unit: str
    category: Optional[str] = None

class MaterialCreate(MaterialBase):
    pass

class Material(MaterialBase):
    id: UUID
    class Config:
        from_attributes = True

class ProjectInventoryBase(BaseModel):
    project_id: UUID
    material_id: UUID
    current_quantity: Decimal

class ProjectInventory(ProjectInventoryBase):
    id: UUID
    last_updated: datetime
    material: Optional[Material] = None # For joined responses
    class Config:
        from_attributes = True

class MaterialRequestBase(BaseModel):
    project_id: UUID
    material_id: UUID
    quantity: Decimal
    remarks: Optional[str] = None

class MaterialRequestCreate(MaterialRequestBase):
    requested_by: UUID

class MaterialRequestUpdate(BaseModel):
    status: str # approved, rejected, received
    remarks: Optional[str] = None

class MaterialRequest(MaterialRequestBase):
    id: UUID
    requested_by: UUID
    status: str
    created_at: datetime
    material: Optional[Material] = None # For joined responses
    class Config:
        from_attributes = True

class MaterialUsageBase(BaseModel):
    project_id: UUID
    material_id: UUID
    quantity: Decimal
    dpr_entry_id: Optional[UUID] = None
    usage_date: Optional[date] = None

class MaterialUsageCreate(MaterialUsageBase):
    logged_by: UUID

class MaterialUsage(MaterialUsageBase):
    id: UUID
    created_at: datetime
    class Config:
        from_attributes = True

class TransactionBase(BaseModel):
    project_id: UUID
    type: str
    category: str
    amount: Decimal
    remarks: Optional[str] = None
    transaction_date: Optional[date] = None

class TransactionCreate(TransactionBase):
    created_by: UUID

class Transaction(TransactionBase):
    id: UUID
    receipt_url: Optional[str] = None
    created_at: datetime
    class Config:
        from_attributes = True

# Worker & Gang Schemas
class WorkerBase(BaseModel):
    project_id: UUID
    name: str
    phone: Optional[str] = None
    skill_type: Optional[str] = None
    gang_id: Optional[UUID] = None

class WorkerCreate(WorkerBase):
    pass

class Worker(WorkerBase):
    id: UUID
    is_active: bool
    created_at: datetime
    class Config:
        from_attributes = True

class GangBase(BaseModel):
    project_id: UUID
    name: str
    supervisor_id: Optional[UUID] = None

class GangCreate(GangBase):
    pass

class Gang(GangBase):
    id: UUID
    created_at: datetime
    class Config:
        from_attributes = True

class AttendanceBase(BaseModel):
    project_id: UUID
    worker_id: UUID
    gang_id: Optional[UUID] = None
    entry_date: date
    status: str # present, absent, half_day

class AttendanceCreate(AttendanceBase):
    marked_by: UUID

class Attendance(AttendanceBase):
    id: UUID
    created_at: datetime
    class Config:
        from_attributes = True

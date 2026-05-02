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
    work_type_id: UUID
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

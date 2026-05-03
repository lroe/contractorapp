from pydantic import BaseModel, EmailStr, Field
from uuid import UUID
from datetime import datetime, date
from typing import Optional, List
from decimal import Decimal

# Organization Schemas
class OrganizationBase(BaseModel):
    name: str
    subscription_status: str = "active"

class OrganizationCreate(OrganizationBase):
    pass

class Organization(OrganizationBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# User Schemas
class UserBase(BaseModel):
    organization_id: UUID
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
    organization: Optional[Organization] = None

    class Config:
        from_attributes = True

# Project Schemas
class ProjectBase(BaseModel):
    organization_id: UUID
    name: str
    code: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    status: str = "active"

class ProjectCreate(ProjectBase):
    pass

class Project(ProjectBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# WorkType Schemas
class WorkTypeBase(BaseModel):
    organization_id: UUID
    name: str
    unit: Optional[str] = None
    rate_per_unit: Optional[Decimal] = 0

class WorkTypeCreate(WorkTypeBase):
    pass

class WorkType(WorkTypeBase):
    id: UUID
    class Config:
        from_attributes = True

# Task Schemas
class TaskBase(BaseModel):
    project_id: UUID
    name: str
    work_type_id: Optional[UUID] = None
    block_id: Optional[UUID] = None
    floor_id: Optional[UUID] = None
    area_id: Optional[UUID] = None
    target_quantity: Optional[Decimal] = 0
    unit: Optional[str] = None
    deadline: Optional[date] = None
    status: str = "pending"

class TaskCreate(TaskBase):
    created_by: UUID

class Task(TaskBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# DPR Entry Schemas
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

class AttendancePhoto(BaseModel):
    id: UUID
    gang_id: UUID
    entry_date: date
    photo_url: str
    uploaded_at: datetime
    class Config:
        from_attributes = True

# Worker & Gang Schemas
class WorkerBase(BaseModel):
    organization_id: UUID
    project_id: UUID
    name: str
    phone: Optional[str] = None
    skill_type: Optional[str] = None
    gang_id: Optional[UUID] = None
    daily_rate: Decimal = 0

class WorkerCreate(WorkerBase):
    pass

class Worker(WorkerBase):
    id: UUID
    is_active: bool
    created_at: datetime
    class Config:
        from_attributes = True

class GangBase(BaseModel):
    organization_id: UUID
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

# Material Management Schemas
class MaterialBase(BaseModel):
    organization_id: UUID
    name: str
    unit: str
    category: Optional[str] = None
    min_stock_level: Optional[Decimal] = 0

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
    material: Optional[Material] = None
    class Config:
        from_attributes = True

class VendorBase(BaseModel):
    organization_id: UUID
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    gstin: Optional[str] = None

class VendorCreate(VendorBase):
    pass

class Vendor(VendorBase):
    id: UUID
    is_active: bool
    created_at: datetime
    class Config:
        from_attributes = True

class VendorPriceBase(BaseModel):
    vendor_id: UUID
    material_id: UUID
    price_per_unit: Decimal
    effective_date: Optional[date] = None
    notes: Optional[str] = None

class VendorPriceCreate(VendorPriceBase):
    pass

class VendorPrice(VendorPriceBase):
    id: UUID
    vendor: Optional[Vendor] = None
    material: Optional[Material] = None
    class Config:
        from_attributes = True

class PurchaseOrderItemBase(BaseModel):
    material_id: UUID
    quantity: Decimal
    unit_price: Decimal = 0

class PurchaseOrderItemCreate(PurchaseOrderItemBase):
    pass

class PurchaseOrderItem(PurchaseOrderItemBase):
    id: UUID
    received_quantity: Decimal = 0
    material: Optional[Material] = None
    class Config:
        from_attributes = True

class PurchaseOrderBase(BaseModel):
    organization_id: UUID
    project_id: UUID
    vendor_id: UUID
    expected_delivery: Optional[date] = None
    remarks: Optional[str] = None

class PurchaseOrderCreate(PurchaseOrderBase):
    raised_by: UUID
    items: List[PurchaseOrderItemCreate]

class PurchaseOrder(PurchaseOrderBase):
    id: UUID
    po_number: Optional[str] = None
    status: str
    total_amount: Decimal
    raised_by: UUID
    approved_by: Optional[UUID] = None
    created_at: datetime
    items: List[PurchaseOrderItem] = []
    vendor: Optional[Vendor] = None
    class Config:
        from_attributes = True

class PurchaseOrderStatusUpdate(BaseModel):
    status: str
    approved_by: Optional[UUID] = None

class StockLedgerEntry(BaseModel):
    id: UUID
    project_id: UUID
    material_id: UUID
    movement_type: str
    quantity: Decimal
    reference_type: Optional[str] = None
    remarks: Optional[str] = None
    entry_date: date
    material: Optional[Material] = None
    class Config:
        from_attributes = True

class TransferNoteBase(BaseModel):
    from_project_id: UUID
    to_project_id: UUID
    material_id: UUID
    quantity: Decimal
    remarks: Optional[str] = None

class TransferNoteCreate(TransferNoteBase):
    raised_by: UUID

class TransferNote(TransferNoteBase):
    id: UUID
    status: str
    raised_by: UUID
    created_at: datetime
    material: Optional[Material] = None
    class Config:
        from_attributes = True

class BOQItemBase(BaseModel):
    project_id: UUID
    material_id: UUID
    planned_quantity: Decimal
    estimated_unit_price: Decimal = 0
    min_stock_level: Decimal = 0
    description: Optional[str] = None

class BOQItemCreate(BOQItemBase):
    pass

class BOQItem(BOQItemBase):
    id: UUID
    material: Optional[Material] = None
    class Config:
        from_attributes = True

# Transaction Schemas
class TransactionBase(BaseModel):
    project_id: UUID
    type: str  # INCOME / EXPENSE
    category: str
    amount: Decimal
    description: Optional[str] = None
    transaction_date: Optional[date] = None

class TransactionCreate(TransactionBase):
    created_by: UUID

class Transaction(TransactionBase):
    id: UUID
    created_by: UUID
    created_at: datetime
    class Config:
        from_attributes = True

class WasteLogBase(BaseModel):
    project_id: UUID
    material_id: UUID
    quantity: Decimal
    reason: Optional[str] = None
    entry_date: Optional[date] = None

class WasteLogCreate(WasteLogBase):
    logged_by: UUID

class WasteLog(WasteLogBase):
    id: UUID
    created_at: datetime
    material: Optional[Material] = None
    class Config:
        from_attributes = True

class ProjectDocumentBase(BaseModel):
    project_id: UUID
    file_name: str
    file_url: str

class ProjectDocumentCreate(ProjectDocumentBase):
    uploaded_by: UUID

class ProjectDocument(ProjectDocumentBase):
    id: UUID
    uploaded_by: UUID
    uploaded_at: datetime

    class Config:
        from_attributes = True

# Material Request Schemas
class MaterialRequestMediaBase(BaseModel):
    media_url: str

class MaterialRequestMedia(MaterialRequestMediaBase):
    id: UUID
    uploaded_at: datetime
    class Config:
        from_attributes = True

class MaterialRequestBase(BaseModel):
    project_id: UUID
    material_id: UUID
    quantity: Decimal
    remarks: Optional[str] = None
    status: str = "pending"

class MaterialRequestCreate(MaterialRequestBase):
    requested_by: UUID
    received_remarks: Optional[str] = None

class MaterialRequest(MaterialRequestBase):
    id: UUID
    requested_by: UUID
    received_remarks: Optional[str] = None
    created_at: datetime
    media: List[MaterialRequestMedia] = []
    material: Optional[Material] = None
    class Config:
        from_attributes = True

# Material Usage Schemas
class MaterialUsageBase(BaseModel):
    project_id: UUID
    material_id: UUID
    quantity: Decimal
    usage_date: Optional[date] = None

class MaterialUsageCreate(MaterialUsageBase):
    logged_by: UUID
    dpr_entry_id: Optional[UUID] = None

class MaterialUsage(MaterialUsageBase):
    id: UUID
    logged_by: UUID
    created_at: datetime
    class Config:
        from_attributes = True

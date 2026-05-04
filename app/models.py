from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Date, Numeric, Text, UniqueConstraint, CheckConstraint, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime
from .database import Base

class Organization(Base):
    __tablename__ = "organizations"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(150), nullable=False)
    subscription_status = Column(String(20), default="active")
    created_at = Column(DateTime, default=datetime.utcnow)

class User(Base):
    __tablename__ = "users"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), index=True)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), unique=True, nullable=True)
    email = Column(String(100), unique=True)
    password_hash = Column(Text)
    auth_provider = Column(String(20), default="local")
    google_id = Column(String(100), unique=True)
    role = Column(String(20))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    organization = relationship("Organization")

    __table_args__ = (
        CheckConstraint(role.in_(['owner', 'supervisor', 'material_manager', 'super_admin']), name='user_role_check'),
    )

class Project(Base):
    __tablename__ = "projects"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), index=True)
    name = Column(String(150), nullable=False)
    code = Column(String(50))
    start_date = Column(Date)
    end_date = Column(Date)
    status = Column(String(20), default="active")
    created_at = Column(DateTime, default=datetime.utcnow)

    organization = relationship("Organization")

    __table_args__ = (
        UniqueConstraint('organization_id', 'code', name='_org_project_code_uc'),
    )

class ProjectUser(Base):
    __tablename__ = "project_users"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role = Column(String(20))

    __table_args__ = (
        UniqueConstraint('project_id', 'user_id', name='_project_user_uc'),
    )

class WorkType(Base):
    __tablename__ = "work_types"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), index=True)
    name = Column(String(100), nullable=False)
    unit = Column(String(20))
    rate_per_unit = Column(Numeric(10, 2))

    organization = relationship("Organization")

class Block(Base):
    __tablename__ = "blocks"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"))
    name = Column(String(100), nullable=False)

class Floor(Base):
    __tablename__ = "floors"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    block_id = Column(UUID(as_uuid=True), ForeignKey("blocks.id", ondelete="CASCADE"))
    name = Column(String(100), nullable=False)

class Area(Base):
    __tablename__ = "areas"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    floor_id = Column(UUID(as_uuid=True), ForeignKey("floors.id", ondelete="CASCADE"))
    name = Column(String(100), nullable=False)

class Task(Base):
    __tablename__ = "tasks"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    name = Column(String(200), nullable=False)
    work_type_id = Column(UUID(as_uuid=True), ForeignKey("work_types.id"), nullable=True)
    block_id = Column(UUID(as_uuid=True), ForeignKey("blocks.id"), nullable=True)
    floor_id = Column(UUID(as_uuid=True), ForeignKey("floors.id"), nullable=True)
    area_id = Column(UUID(as_uuid=True), ForeignKey("areas.id"), nullable=True)
    target_quantity = Column(Numeric(12, 2), default=0)
    unit = Column(String(20))
    deadline = Column(Date)
    status = Column(String(20), default="pending")
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

class Worker(Base):
    __tablename__ = "workers"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), index=True)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    name = Column(String(100), nullable=False)
    phone = Column(String(20))
    skill_type = Column(String(50))
    gang_id = Column(UUID(as_uuid=True))
    daily_rate = Column(Numeric(10, 2), default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    organization = relationship("Organization")

class Gang(Base):
    __tablename__ = "gangs"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), index=True)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"))
    name = Column(String(100), nullable=False)
    supervisor_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

    organization = relationship("Organization")

class DPREntry(Base):
    __tablename__ = "dpr_entries"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    supervisor_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    entry_date = Column(Date, nullable=False, index=True)
    work_type_id = Column(UUID(as_uuid=True), ForeignKey("work_types.id"))
    block_id = Column(UUID(as_uuid=True), ForeignKey("blocks.id"))
    floor_id = Column(UUID(as_uuid=True), ForeignKey("floors.id"))
    area_id = Column(UUID(as_uuid=True), ForeignKey("areas.id"))
    quantity = Column(Numeric(12, 2), nullable=True)
    remarks = Column(Text)
    linked_task_id = Column(UUID(as_uuid=True), ForeignKey("tasks.id"), index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    media = relationship("DPRMedia", backref="entry", cascade="all, delete-orphan", lazy="joined")

class DPRMedia(Base):
    __tablename__ = "dpr_media"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    dpr_entry_id = Column(UUID(as_uuid=True), ForeignKey("dpr_entries.id", ondelete="CASCADE"))
    media_url = Column(Text, nullable=False)
    media_type = Column(String(20), default="photo")
    uploaded_at = Column(DateTime, default=datetime.utcnow)

class Attendance(Base):
    __tablename__ = "attendance"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    worker_id = Column(UUID(as_uuid=True), ForeignKey("workers.id", ondelete="CASCADE"), index=True)
    gang_id = Column(UUID(as_uuid=True), ForeignKey("gangs.id"), index=True)
    entry_date = Column(Date, nullable=False, index=True)
    status = Column(String(20))
    marked_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint('worker_id', 'entry_date', name='_worker_attendance_uc'),
        CheckConstraint(status.in_(['present', 'absent', 'half_day']), name='attendance_status_check'),
    )

class AttendancePhoto(Base):
    __tablename__ = "attendance_photos"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    gang_id = Column(UUID(as_uuid=True), ForeignKey("gangs.id", ondelete="CASCADE"), index=True)
    entry_date = Column(Date, nullable=False, index=True)
    photo_url = Column(Text, nullable=False)
    uploaded_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint('gang_id', 'entry_date', name='_gang_attendance_photo_uc'),
    )

# ─── Material Management ──────────────────────────────────────────────────────

class Material(Base):
    __tablename__ = "materials"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), index=True)
    name = Column(String(100), nullable=False)
    unit = Column(String(20), nullable=False)
    category = Column(String(50))
    min_stock_level = Column(Numeric(12, 2), default=0)

    organization = relationship("Organization")

    __table_args__ = (
        UniqueConstraint('organization_id', 'name', name='_org_material_name_uc'),
    )

class Vendor(Base):
    __tablename__ = "vendors"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), index=True)
    name = Column(String(150), nullable=False)
    phone = Column(String(20))
    email = Column(String(100))
    address = Column(Text)
    gstin = Column(String(20))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    organization = relationship("Organization")

class VendorPrice(Base):
    __tablename__ = "vendor_prices"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vendor_id = Column(UUID(as_uuid=True), ForeignKey("vendors.id", ondelete="CASCADE"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id", ondelete="CASCADE"), index=True)
    price_per_unit = Column(Numeric(12, 2), nullable=False)
    effective_date = Column(Date, default=datetime.utcnow)
    notes = Column(Text)

    vendor = relationship("Vendor")
    material = relationship("Material")

class PurchaseOrder(Base):
    __tablename__ = "purchase_orders"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), index=True)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    vendor_id = Column(UUID(as_uuid=True), ForeignKey("vendors.id"), index=True)
    po_number = Column(String(50))
    status = Column(String(20), default="draft")
    total_amount = Column(Numeric(14, 2), default=0)
    raised_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    approved_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    expected_delivery = Column(Date, nullable=True)
    remarks = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    organization = relationship("Organization")
    items = relationship("PurchaseOrderItem", backref="purchase_order", cascade="all, delete-orphan")
    vendor = relationship("Vendor")

    __table_args__ = (
        UniqueConstraint('organization_id', 'po_number', name='_org_po_number_uc'),
    )

class PurchaseOrderItem(Base):
    __tablename__ = "purchase_order_items"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    po_id = Column(UUID(as_uuid=True), ForeignKey("purchase_orders.id", ondelete="CASCADE"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id"), index=True)
    quantity = Column(Numeric(12, 2), nullable=False)
    unit_price = Column(Numeric(12, 2), default=0)
    received_quantity = Column(Numeric(12, 2), default=0)

    material = relationship("Material")

class ProjectInventory(Base):
    __tablename__ = "project_inventory"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id", ondelete="CASCADE"), index=True)
    current_quantity = Column(Numeric(12, 2), default=0)
    last_updated = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    material = relationship("Material")

    __table_args__ = (
        UniqueConstraint('project_id', 'material_id', name='_project_material_inventory_uc'),
    )

class StockLedger(Base):
    __tablename__ = "stock_ledger"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id"), index=True)
    movement_type = Column(String(20), nullable=False)
    quantity = Column(Numeric(12, 2), nullable=False)
    reference_type = Column(String(30))
    reference_id = Column(UUID(as_uuid=True), nullable=True)
    remarks = Column(Text)
    logged_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    entry_date = Column(Date, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

    material = relationship("Material")

class MaterialRequest(Base):
    __tablename__ = "material_requests"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id"), index=True)
    quantity = Column(Numeric(12, 2), nullable=False)
    requested_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    status = Column(String(20), default="pending")
    remarks = Column(Text)
    received_remarks = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    media = relationship("MaterialRequestMedia", backref="request", cascade="all, delete-orphan")
    
    project = relationship("Project")
    material = relationship("Material")
    requested_by_user = relationship("User", foreign_keys=[requested_by])

class MaterialRequestMedia(Base):
    __tablename__ = "material_request_media"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    request_id = Column(UUID(as_uuid=True), ForeignKey("material_requests.id", ondelete="CASCADE"))
    media_url = Column(Text, nullable=False)
    uploaded_at = Column(DateTime, default=datetime.utcnow)

class TransferNote(Base):
    __tablename__ = "transfer_notes"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    from_project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id"), index=True)
    to_project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id"), index=True)
    quantity = Column(Numeric(12, 2), nullable=False)
    status = Column(String(20), default="pending")
    raised_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    remarks = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    material = relationship("Material")
    from_project = relationship("Project", foreign_keys=[from_project_id])
    to_project = relationship("Project", foreign_keys=[to_project_id])

class BOQItem(Base):
    __tablename__ = "boq_items"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id"), index=True)
    planned_quantity = Column(Numeric(12, 2), nullable=False)
    estimated_unit_price = Column(Numeric(12, 2), default=0)
    min_stock_level = Column(Numeric(12, 2), default=0)
    description = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    material = relationship("Material")
    project = relationship("Project")

    __table_args__ = (
        UniqueConstraint('project_id', 'material_id', name='_project_boq_material_uc'),
    )

class WasteLog(Base):
    __tablename__ = "waste_logs"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id"), index=True)
    quantity = Column(Numeric(12, 2), nullable=False)
    reason = Column(Text)
    logged_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    entry_date = Column(Date, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

    material = relationship("Material")

class MaterialUsage(Base):
    __tablename__ = "material_usage"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    dpr_entry_id = Column(UUID(as_uuid=True), ForeignKey("dpr_entries.id", ondelete="CASCADE"), nullable=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id"), index=True)
    quantity = Column(Numeric(12, 2), nullable=False)
    logged_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    usage_date = Column(Date, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id"))
    type = Column(String)
    category = Column(String)
    amount = Column(Numeric(14, 2), nullable=False)
    description = Column(Text)
    transaction_date = Column(Date, default=datetime.utcnow)

class Document(Base):
    __tablename__ = "documents"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    title = Column(String(200), nullable=False)
    category = Column(String(50))
    file_url = Column(Text, nullable=False)
    uploaded_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

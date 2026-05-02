from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Date, Numeric, Text, UniqueConstraint, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime
from .database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), unique=True, nullable=False)
    email = Column(String(100))
    password_hash = Column(Text)
    role = Column(String(20))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(role.in_(['owner', 'supervisor']), name='user_role_check'),
    )

class Project(Base):
    __tablename__ = "projects"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(150), nullable=False)
    code = Column(String(50), unique=True)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    start_date = Column(Date)
    end_date = Column(Date)
    status = Column(String(20), default="active")
    created_at = Column(DateTime, default=datetime.utcnow)

class ProjectUser(Base):
    __tablename__ = "project_users"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role = Column(String(20))

    __table_args__ = (
        UniqueConstraint('project_id', 'user_id', name='_project_user_uc'),
        CheckConstraint(role.in_(['owner', 'supervisor']), name='project_user_role_check'),
    )

class WorkType(Base):
    __tablename__ = "work_types"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    unit = Column(String(20))
    created_at = Column(DateTime, default=datetime.utcnow)

class Block(Base):
    __tablename__ = "blocks"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    name = Column(String(50), nullable=False)
    __table_args__ = (UniqueConstraint('project_id', 'name', name='_block_project_uc'),)

class Floor(Base):
    __tablename__ = "floors"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    block_id = Column(UUID(as_uuid=True), ForeignKey("blocks.id", ondelete="CASCADE"))
    name = Column(String(50), nullable=False)
    __table_args__ = (UniqueConstraint('block_id', 'name', name='_floor_block_uc'),)

class Area(Base):
    __tablename__ = "areas"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    floor_id = Column(UUID(as_uuid=True), ForeignKey("floors.id", ondelete="CASCADE"))
    name = Column(String(100), nullable=False)
    __table_args__ = (UniqueConstraint('floor_id', 'name', name='_area_floor_uc'),)

class Task(Base):
    __tablename__ = "tasks"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    work_type_id = Column(UUID(as_uuid=True), ForeignKey("work_types.id"), index=True)
    block_id = Column(UUID(as_uuid=True), ForeignKey("blocks.id"), index=True)
    floor_id = Column(UUID(as_uuid=True), ForeignKey("floors.id"), index=True)
    area_id = Column(UUID(as_uuid=True), ForeignKey("areas.id"), index=True)
    target_quantity = Column(Numeric(12, 2), nullable=False)
    unit = Column(String(20))
    deadline = Column(Date)
    status = Column(String(20), default="pending")
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(status.in_(['pending', 'in_progress', 'completed']), name='task_status_check'),
    )

class Worker(Base):
    __tablename__ = "workers"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"))
    name = Column(String(100), nullable=False)
    phone = Column(String(20))
    skill_type = Column(String(50))
    gang_id = Column(UUID(as_uuid=True)) # ForeignKey added below after Gang is defined
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Gang(Base):
    __tablename__ = "gangs"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"))
    name = Column(String(100), nullable=False)
    supervisor_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

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
    media_type = Column(String(20), default="photo") # photo, video
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

class Material(Base):
    __tablename__ = "materials"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False, unique=True)
    unit = Column(String(20), nullable=False) # Bags, Tons, Cum, Units
    category = Column(String(50)) # e.g. Structural, Finishing, Plumbing

class ProjectInventory(Base):
    __tablename__ = "project_inventory"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id", ondelete="CASCADE"), index=True)
    current_quantity = Column(Numeric(12, 2), default=0)
    last_updated = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint('project_id', 'material_id', name='_project_material_inventory_uc'),
    )

class MaterialRequest(Base):
    __tablename__ = "material_requests"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True)
    material_id = Column(UUID(as_uuid=True), ForeignKey("materials.id"), index=True)
    quantity = Column(Numeric(12, 2), nullable=False)
    requested_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    status = Column(String(20), default="pending") # pending, approved, rejected, received
    remarks = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

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
    type = Column(String)  # INCOME or EXPENSE
    category = Column(String)  # Materials, Wages, Fuel, Transport, Food, Other
    amount = Column(Numeric(10, 2))
    remarks = Column(Text, nullable=True)
    receipt_url = Column(String, nullable=True)
    transaction_date = Column(Date, default=datetime.utcnow)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

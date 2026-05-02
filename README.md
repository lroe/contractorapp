# Contractor DB - FastAPI & PostgreSQL Backend

This project provides a robust backend for a Construction Management System, built with FastAPI and SQLAlchemy, using PostgreSQL as the database.

## Features
- **User Management**: Support for Owners and Supervisors.
- **Project Tracking**: Manage multiple projects, blocks, floors, and areas.
- **Task Management**: Define tasks and track progress.
- **Daily Progress Reports (DPR)**: Submit daily progress with **multiple photos and videos**.
- **Attendance**: Track worker attendance and gang assignments.
- **Automated Schema**: Database tables are automatically created on startup.

## Prerequisites
- Python 3.9+
- Docker & Docker Compose (optional, for easy PostgreSQL setup)

## Setup Instructions

### 1. Database Setup (using Docker)
If you have Docker installed, run:
```bash
docker-compose up -d
```
This will start a PostgreSQL instance on `localhost:5432`.

### 2. Python Environment
Create a virtual environment and install dependencies:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Run the API
```bash
uvicorn app.main:app --reload
```
The API will be available at `http://localhost:8000`.
Documentation can be found at `http://localhost:8000/docs`.

## Key Endpoints
- `POST /users/`: Register a new user.
- `POST /projects/`: Create a project.
- `POST /dpr/`: Submit a Daily Progress Report.
- `POST /dpr/{dpr_id}/media/`: Upload multiple photos/videos for a specific DPR entry.
- `POST /attendance/`: Mark worker attendance.

## Project Structure
- `app/models.py`: SQLAlchemy database models.
- `app/schemas.py`: Pydantic validation schemas.
- `app/crud.py`: Database helper functions.
- `app/main.py`: FastAPI routes and application logic.

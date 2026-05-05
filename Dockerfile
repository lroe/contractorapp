FROM python:3.12-slim

WORKDIR /app

# Install system dependencies for psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev postgresql-client && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

COPY app/ ./app/
COPY web_portal/ ./web_portal/
COPY seed_users.py ./seed_users.py
COPY seed_materials.py ./seed_materials.py
COPY scratch/ ./scratch/

# Shared uploads volume will be mounted here
RUN mkdir -p /app/uploads

EXPOSE 8000 5050

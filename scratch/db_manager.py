#!/usr/bin/env python3
"""
Database management script - reset, backup, restore, etc.
Usage:
    python3 scratch/db_manager.py reset          - Reset database (DANGEROUS!)
    python3 scratch/db_manager.py backup         - Create database backup
    python3 scratch/db_manager.py restore <file> - Restore from backup
    python3 scratch/db_manager.py list-backups   - List available backups
    python3 scratch/db_manager.py clear <table>  - Clear specific table
"""

import sys
import os
import subprocess
from datetime import datetime
from pathlib import Path

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal, engine
from app import models

def get_db_url():
    """Get database URL from environment or config."""
    from app.database import DATABASE_URL
    return DATABASE_URL

def backup_database():
    """Create a backup of the database."""
    db_url = get_db_url()
    
    # Extract connection details
    if "postgresql" in db_url:
        # postgresql://user:password@host:port/dbname
        parts = db_url.replace("postgresql://", "").split("@")
        creds = parts[0].split(":")
        host_port = parts[1].split("/")
        
        user = creds[0]
        password = creds[1]
        host = host_port[0].split(":")[0]
        port = host_port[0].split(":")[1] if ":" in host_port[0] else "5432"
        dbname = host_port[1]
        
        backup_dir = Path("uploads/backups")
        backup_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = backup_dir / f"db_backup_{timestamp}.sql"
        
        try:
            # Use pg_dump to create backup
            cmd = [
                "pg_dump",
                f"--host={host}",
                f"--port={port}",
                f"--username={user}",
                f"--dbname={dbname}",
                f"--file={backup_file}"
            ]
            
            env = os.environ.copy()
            env["PGPASSWORD"] = password
            
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            
            if result.returncode == 0:
                file_size = backup_file.stat().st_size / (1024 * 1024)  # Size in MB
                print(f"✅ Database backed up successfully!")
                print(f"   File: {backup_file}")
                print(f"   Size: {file_size:.2f} MB")
                return True
            else:
                print(f"❌ Backup failed: {result.stderr}")
                return False
                
        except FileNotFoundError:
            print("❌ pg_dump not found. Install PostgreSQL client tools.")
            return False
        except Exception as e:
            print(f"❌ Backup error: {e}")
            return False
    else:
        print("❌ Only PostgreSQL is supported for backup.")
        return False

def restore_database(backup_file):
    """Restore database from backup file."""
    db_url = get_db_url()
    
    backup_path = Path(backup_file)
    if not backup_path.exists():
        print(f"❌ Backup file not found: {backup_file}")
        return False
    
    if "postgresql" in db_url:
        parts = db_url.replace("postgresql://", "").split("@")
        creds = parts[0].split(":")
        host_port = parts[1].split("/")
        
        user = creds[0]
        password = creds[1]
        host = host_port[0].split(":")[0]
        port = host_port[0].split(":")[1] if ":" in host_port[0] else "5432"
        dbname = host_port[1]
        
        try:
            print("⚠️  WARNING: This will overwrite the current database!")
            response = input("Are you sure? Type 'yes' to confirm: ")
            
            if response.lower() != "yes":
                print("❌ Restore cancelled.")
                return False
            
            # Drop and recreate database
            cmd_drop = [
                "psql",
                f"--host={host}",
                f"--port={port}",
                f"--username={user}",
                f"--dbname=postgres",
                "-c", f"DROP DATABASE IF EXISTS {dbname};"
            ]
            
            cmd_create = [
                "psql",
                f"--host={host}",
                f"--port={port}",
                f"--username={user}",
                f"--dbname=postgres",
                "-c", f"CREATE DATABASE {dbname};"
            ]
            
            cmd_restore = [
                "psql",
                f"--host={host}",
                f"--port={port}",
                f"--username={user}",
                f"--dbname={dbname}",
            ]
            
            env = os.environ.copy()
            env["PGPASSWORD"] = password
            
            # Drop database
            print("Dropping existing database...")
            result = subprocess.run(cmd_drop, env=env, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"⚠️  Drop warning: {result.stderr}")
            
            # Create database
            print("Creating new database...")
            result = subprocess.run(cmd_create, env=env, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"❌ Create failed: {result.stderr}")
                return False
            
            # Restore backup
            print(f"Restoring from {backup_file}...")
            with open(backup_path, 'r') as f:
                result = subprocess.run(cmd_restore, stdin=f, env=env, capture_output=True, text=True)
            
            if result.returncode == 0:
                print("✅ Database restored successfully!")
                return True
            else:
                print(f"❌ Restore failed: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"❌ Restore error: {e}")
            return False
    else:
        print("❌ Only PostgreSQL is supported for restore.")
        return False

def list_backups():
    """List all available backups."""
    backup_dir = Path("uploads/backups")
    
    if not backup_dir.exists():
        print("No backups found.")
        return
    
    backups = sorted(backup_dir.glob("db_backup_*.sql"))
    
    if not backups:
        print("No backups found.")
        return
    
    print(f"Found {len(backups)} backup(s):")
    for backup in backups:
        size = backup.stat().st_size / (1024 * 1024)  # MB
        mtime = datetime.fromtimestamp(backup.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")
        print(f"  📦 {backup.name} ({size:.2f} MB) - {mtime}")

def reset_database():
    """Reset the entire database (DANGEROUS!)."""
    print("⚠️  WARNING: This will DELETE ALL DATA!")
    print("⚠️  This operation cannot be undone.")
    response = input("Type 'reset-all' to confirm: ")
    
    if response != "reset-all":
        print("❌ Reset cancelled.")
        return False
    
    try:
        db = SessionLocal()
        
        # Drop all tables
        print("Dropping all tables...")
        models.Base.metadata.drop_all(bind=engine)
        
        # Create all tables
        print("Creating all tables...")
        models.Base.metadata.create_all(bind=engine)
        
        db.close()
        
        print("✅ Database reset successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Reset failed: {e}")
        return False

def clear_table(table_name):
    """Clear all records from a specific table."""
    db = SessionLocal()
    
    # Map table names to models
    table_map = {
        'users': models.User,
        'organizations': models.Organization,
        'projects': models.Project,
        'materials': models.Material,
        'transactions': models.Transaction,
        'transfers': models.TransferNote,
        'sites': models.Site,
        'inventory': models.Inventory,
        'purchase_orders': models.PurchaseOrder,
        'documents': models.ProjectDocument,
    }
    
    if table_name.lower() not in table_map:
        print(f"❌ Unknown table: {table_name}")
        print(f"Available tables: {', '.join(table_map.keys())}")
        return False
    
    model = table_map[table_name.lower()]
    
    print(f"⚠️  WARNING: This will DELETE ALL records from '{table_name}'!")
    response = input(f"Type '{table_name}' to confirm: ")
    
    if response != table_name:
        print("❌ Clear cancelled.")
        return False
    
    try:
        count = db.query(model).delete()
        db.commit()
        db.close()
        
        print(f"✅ Cleared {count} records from '{table_name}'")
        return True
        
    except Exception as e:
        db.rollback()
        db.close()
        print(f"❌ Clear failed: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    command = sys.argv[1].lower()
    
    if command == "backup":
        backup_database()
    elif command == "restore":
        if len(sys.argv) < 3:
            print("Usage: python3 scratch/db_manager.py restore <backup_file>")
            print("Example: python3 scratch/db_manager.py restore uploads/backups/db_backup_20260505_120000.sql")
            sys.exit(1)
        restore_database(sys.argv[2])
    elif command == "list-backups":
        list_backups()
    elif command == "reset":
        reset_database()
    elif command == "clear":
        if len(sys.argv) < 3:
            print("Usage: python3 scratch/db_manager.py clear <table_name>")
            sys.exit(1)
        clear_table(sys.argv[2])
    else:
        print(f"❌ Unknown command: {command}")
        print(__doc__)
        sys.exit(1)

if __name__ == "__main__":
    main()
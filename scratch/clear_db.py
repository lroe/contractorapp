from sqlalchemy import text
from app.database import engine

def clear_data():
    tables_to_clear = [
        'attendance',
        'workers',
        'gangs',
        'transactions',
        'material_usage',
        'material_requests',
        'project_inventory',
        'dpr_media',
        'dpr_entries',
        'tasks',
        'areas',
        'floors',
        'blocks',
        'project_users',
        'projects'
    ]
    
    with engine.connect() as conn:
        print("Clearing data from tables...")
        for table in tables_to_clear:
            try:
                # Using TRUNCATE with CASCADE to handle foreign key dependencies
                # but we are NOT including 'users', 'materials', or 'work_types' in the list.
                # CASCADE here will ensure dependent child records are cleared.
                conn.execute(text(f"TRUNCATE TABLE {table} CASCADE;"))
                conn.commit()
                print(f"  - {table} cleared.")
            except Exception as e:
                print(f"  ! Error clearing {table}: {e}")
                conn.rollback()

    print("\nDatabase cleanup complete. Users and master data (Materials/Work Types) preserved.")

if __name__ == "__main__":
    clear_data()

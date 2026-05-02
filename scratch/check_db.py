from app.database import engine
from sqlalchemy import inspect

inspector = inspect(engine)
for table in ['gangs', 'workers', 'attendance']:
    print(f"\nTable: {table}")
    columns = inspector.get_columns(table)
    for c in columns:
        print(f"  - {c['name']} ({c['type']})")

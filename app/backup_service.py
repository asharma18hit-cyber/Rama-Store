"""
app/backup_service.py - Production Database Backup Engine for Samaur Mart.
Creates safe, hot SQLite backups using the SQLite Online Backup API.
"""

import os
import time
import sqlite3
import shutil

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
BACKUP_DIR = os.path.join(BASE_DIR, 'backups')

def create_database_backup(db_path: str = None) -> dict:
    """
    Performs a non-blocking hot backup of the SQLite database while the server is running.
    Returns: { "success": bool, "backup_file": str, "timestamp": str, "size_bytes": int }
    """
    db_path = db_path or os.path.join(BASE_DIR, 'rama_store.db')
    if not os.path.exists(db_path):
        return {"success": False, "error": f"Database file not found: {db_path}"}

    os.makedirs(BACKUP_DIR, exist_ok=True)
    timestamp = time.strftime('%Y%m%d_%H%M%S')
    backup_filename = f"rama_store_backup_{timestamp}.db"
    backup_path = os.path.join(BACKUP_DIR, backup_filename)

    try:
        # Use SQLite's safe online backup API to prevent partial writes
        src_conn = sqlite3.connect(db_path)
        dst_conn = sqlite3.connect(backup_path)
        with dst_conn:
            src_conn.backup(dst_conn)
        dst_conn.close()
        src_conn.close()

        size_bytes = os.path.getsize(backup_path)

        # Retain only last 10 backups to preserve disk space
        backups = sorted([os.path.join(BACKUP_DIR, f) for f in os.listdir(BACKUP_DIR) if f.startswith('rama_store_backup_')])
        if len(backups) > 10:
            for old in backups[:-10]:
                try:
                    os.remove(old)
                except Exception:
                    pass

        return {
            "success": True,
            "backup_file": backup_filename,
            "backup_path": backup_path,
            "timestamp": timestamp,
            "size_bytes": size_bytes
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

if __name__ == '__main__':
    result = create_database_backup()
    print("Database backup result:", result)

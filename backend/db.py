# backend/db.py
import sqlite3
import secrets
import json
import threading
import os
from pathlib import Path
from typing import Optional, List, Dict, Any

_DB_PATH = Path(__file__).parent / "cipherx.db"
_LOCK = threading.Lock()


def _conn():
    # allow usage from FastAPI BackgroundTasks threads
    return sqlite3.connect(str(_DB_PATH), check_same_thread=False)


def _ensure_columns(cx: sqlite3.Connection):
    cur = cx.execute("PRAGMA table_info(jobs)")
    cols = {row[1] for row in cur.fetchall()}
    if "file_size" not in cols:
        cx.execute("ALTER TABLE jobs ADD COLUMN file_size INTEGER DEFAULT 0")
    if "prediction" not in cols:
        cx.execute("ALTER TABLE jobs ADD COLUMN prediction TEXT")


def init_db():
    with _LOCK, _conn() as cx:
        cx.execute(
            """
        CREATE TABLE IF NOT EXISTS users (
            api_key TEXT PRIMARY KEY,
            username TEXT NOT NULL UNIQUE,
            role TEXT NOT NULL DEFAULT 'user'
        );
        """
        )
        # Ensure role column exists for existing databases
        cur = cx.execute("PRAGMA table_info(users)")
        cols = {row[1] for row in cur.fetchall()}
        if "role" not in cols:
            cx.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user'")
        # Admins table
        cx.execute(
            """
        CREATE TABLE IF NOT EXISTS admins (
            email TEXT PRIMARY KEY NOT NULL
        );
        """
        )
        # Activity log table
        cx.execute(
            """
        CREATE TABLE IF NOT EXISTS activity_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            username TEXT NOT NULL,
            action TEXT NOT NULL,
            details TEXT
        );
        """
        )
        cx.execute(
            """
        CREATE TABLE IF NOT EXISTS jobs (
            job_id TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            app_name TEXT NOT NULL,
            status TEXT NOT NULL,
            options_json TEXT,
            result_json TEXT,
            gemini_report TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
        )
        _ensure_columns(cx)
        
        # Seed default users
        admin_key = os.environ.get("ADMIN_API_KEY", "your-secure-admin-key")
        
        # Create admin user if not exists
        cur = cx.execute("SELECT api_key FROM users WHERE username=?", ("admin@cipherx.com",))
        if not cur.fetchone():
            cx.execute(
                "INSERT INTO users(api_key, username, role) VALUES(?, ?, ?)",
                (admin_key, "admin@cipherx.com", "admin")
            )
        
        # Create test user if not exists
        cur = cx.execute("SELECT api_key FROM users WHERE username=?", ("testuser@cipherx.com",))
        if not cur.fetchone():
            cx.execute(
                "INSERT INTO users(api_key, username, role) VALUES(?, ?, ?)",
                ("test-user-api-key", "testuser@cipherx.com", "user")
            )
        
        cx.commit()


def create_user(username: str, api_key: Optional[str] = None, role: str = "user") -> str:
    with _LOCK, _conn() as cx:
        # If user already exists, return the existing api_key (idempotent behavior)
        cur = cx.execute("SELECT api_key FROM users WHERE username=?", (username,))
        row = cur.fetchone()
        if row and row[0]:
            return row[0]

        # Use provided api_key if supplied, otherwise generate one
        final_key = api_key or secrets.token_urlsafe(32)
        # Validate role
        if role not in ("user", "admin"):
            role = "user"
        cx.execute("INSERT INTO users(api_key, username, role) VALUES(?, ?, ?)", (final_key, username, role))
        cx.commit()
        return final_key


def get_username_for_api_key(api_key: str) -> Optional[str]:
    with _LOCK, _conn() as cx:
        cur = cx.execute("SELECT username FROM users WHERE api_key=?", (api_key,))
        row = cur.fetchone()
        return row[0] if row else None


def get_user_by_credentials(username: str, api_key: str) -> Optional[Dict[str, str]]:
    """Validate credentials and return user info including role"""
    with _LOCK, _conn() as cx:
        cur = cx.execute(
            "SELECT username, role FROM users WHERE username=? AND api_key=?",
            (username, api_key)
        )
        row = cur.fetchone()
        if row:
            return {"username": row[0], "role": row[1]}
        return None


def get_user_role(username: str) -> Optional[str]:
    """Get the role for a given username"""
    with _LOCK, _conn() as cx:
        cur = cx.execute("SELECT role FROM users WHERE username=?", (username,))
        row = cur.fetchone()
        return row[0] if row else None


def create_job(
    username: str,
    job_id: str,
    app_name: str,
    status: str,
    options: Dict[str, Any],
    *,
    file_size: int = 0,
):
    with _LOCK, _conn() as cx:
        cx.execute(
            """
            INSERT INTO jobs(job_id, username, app_name, status, options_json, file_size)
            VALUES (?, ?, ?, ?, ?, ?)
        """,
            (job_id, username, app_name, status, json.dumps(options or {}), int(file_size or 0)),
        )
        cx.commit()


def update_job_status(job_id: str, status: str):
    with _LOCK, _conn() as cx:
        cx.execute("UPDATE jobs SET status=? WHERE job_id=?", (status, job_id))
        cx.commit()


def save_job_result(job_id: str, result: Dict[str, Any]):
    with _LOCK, _conn() as cx:
        cx.execute("UPDATE jobs SET result_json=? WHERE job_id=?", (json.dumps(result or {}), job_id))
        cx.commit()


def set_job_prediction(job_id: str, prediction: Optional[str]):
    with _LOCK, _conn() as cx:
        cx.execute("UPDATE jobs SET prediction=? WHERE job_id=?", (prediction, job_id))
        cx.commit()


def save_gemini_report(job_id: str, report_md: str):
    with _LOCK, _conn() as cx:
        cx.execute("UPDATE jobs SET gemini_report=? WHERE job_id=?", (report_md, job_id))
        cx.commit()


def get_user_job(username: str, job_id: str) -> Optional[Dict[str, Any]]:
    with _LOCK, _conn() as cx:
        cur = cx.execute(
            """
            SELECT job_id, username, app_name, status, options_json, result_json, gemini_report, file_size, prediction, created_at
            FROM jobs WHERE job_id=? AND username=?
        """,
            (job_id, username),
        )
        row = cur.fetchone()
        if not row:
            return None
        return {
            "job_id": row[0],
            "username": row[1],
            "app_name": row[2],
            "status": row[3],
            "options": json.loads(row[4]) if row[4] else {},
            "result": json.loads(row[5]) if row[5] else None,
            "gemini_report": row[6],
            "file_size": row[7] or 0,
            "prediction": row[8],
            "created_at": row[9],
        }


def get_history(username: str) -> List[Dict[str, Any]]:
    with _LOCK, _conn() as cx:
        cur = cx.execute(
            """
            SELECT job_id, app_name, status, file_size, prediction, created_at, result_json FROM jobs
            WHERE username=?
            ORDER BY datetime(created_at) DESC
        """,
            (username,),
        )
        rows = cur.fetchall()
        history = []
        for r in rows:
            item = {
                "job_id": r[0],
                "app_name": r[1],
                "status": r[2],
                "file_size": r[3] or 0,
                "prediction": r[4],
                "created_at": r[5],
            }
            # Extract confidence from result_json if available
            if r[6]:
                try:
                    result = json.loads(r[6])
                    confidence = result.get('confidence_score') or result.get('confidence')
                    if confidence is not None:
                        item['confidence'] = float(confidence) * 100 if confidence <= 1.0 else float(confidence)
                except Exception:
                    pass
            history.append(item)
        return history


# ----- Admins helpers -----
def add_admin(email: str):
    with _LOCK, _conn() as cx:
        cx.execute("INSERT OR IGNORE INTO admins(email) VALUES(?)", (email,))
        cx.commit()


def remove_admin(email: str):
    with _LOCK, _conn() as cx:
        cx.execute("DELETE FROM admins WHERE email=?", (email,))
        cx.commit()


def get_all_admins() -> List[str]:
    with _LOCK, _conn() as cx:
        cur = cx.execute("SELECT email FROM admins ORDER BY email ASC")
        return [r[0] for r in cur.fetchall()]


def is_admin_user(email: str) -> bool:
    with _LOCK, _conn() as cx:
        cur = cx.execute("SELECT 1 FROM admins WHERE email=?", (email,))
        return cur.fetchone() is not None


# ----- Activity log helpers -----
def log_activity(username: str, action: str, details: Optional[str] = None):
    with _LOCK, _conn() as cx:
        cx.execute(
            "INSERT INTO activity_log(username, action, details) VALUES(?, ?, ?)",
            (username, action, details),
        )
        cx.commit()


def get_activity_log() -> List[Dict[str, Any]]:
    with _LOCK, _conn() as cx:
        cur = cx.execute(
            """
            SELECT id, timestamp, username, action, details
            FROM activity_log
            ORDER BY datetime(timestamp) DESC
            """
        )
        rows = cur.fetchall()
        return [
            {
                "id": r[0],
                "timestamp": r[1],
                "username": r[2],
                "action": r[3],
                "details": r[4],
            }
            for r in rows
        ]


def get_user_stats(username: str) -> Dict[str, Any]:
    """Get statistics for a user's scans"""
    with _LOCK, _conn() as cx:
        # Total scans
        cur = cx.execute("SELECT COUNT(*) FROM jobs WHERE username=?", (username,))
        total_scans = cur.fetchone()[0]
        
        # Threats detected (malicious predictions)
        cur = cx.execute(
            "SELECT COUNT(*) FROM jobs WHERE username=? AND prediction=?", 
            (username, "malicious")
        )
        threats_detected = cur.fetchone()[0]
        
        # Average confidence (from completed jobs)
        cur = cx.execute(
            """
            SELECT AVG(CAST(json_extract(result_json, '$.confidence') AS REAL)) 
            FROM jobs 
            WHERE username=? AND result_json IS NOT NULL 
            AND json_extract(result_json, '$.confidence') IS NOT NULL
            """,
            (username,)
        )
        avg_confidence = cur.fetchone()[0] or 0.0
        
        # Average processing time (approximation based on file size)
        cur = cx.execute(
            "SELECT AVG(file_size) FROM jobs WHERE username=? AND file_size > 0", 
            (username,)
        )
        avg_file_size = cur.fetchone()[0] or 0
        # Rough estimate: 1MB = ~1 second processing time
        avg_processing_time = max(5, min(60, avg_file_size / (1024 * 1024)))
        
        return {
            "total_scans": total_scans,
            "threats_detected": threats_detected,
            "avg_confidence": round(avg_confidence, 1),
            "avg_processing_time": f"{int(avg_processing_time)}s"
        }
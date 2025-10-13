# backend/service.py
import os
import shutil
import random
import json
import sys
import uuid
from pathlib import Path
from typing import Dict, Any, Optional
from ml_worker.apk_analyzer import analyze_apk, get_vulnerability_explanation
import joblib

from backend.db import (
    create_job,
    update_job_status,
    save_job_result,
    save_gemini_report,
    get_user_job,
    set_job_prediction,
    get_history as db_get_history,
)

ML_WORKER_DIR = Path(__file__).parent.parent / "ml_worker"
MODEL_PATH = ML_WORKER_DIR / "apk_random_forest_model.joblib"
VECTORIZER_PATH = ML_WORKER_DIR / "apk_feature_vectorizer.joblib"
TOP_FEATURES_PATH = ML_WORKER_DIR / "top_malware_features.json"

try:
    model = joblib.load(MODEL_PATH)
    vectorizer = joblib.load(VECTORIZER_PATH)
    with open(TOP_FEATURES_PATH, "r") as f:
        top_features = json.load(f)
except Exception as e:
    print(f"Error loading model artifacts: {e}", file=sys.stderr)
    model = None
    vectorizer = None
    top_features = {}

# Storage directory — use capital S consistently
STORAGE_DIR = Path(__file__).parent.parent / "Storage"
STORAGE_DIR.mkdir(exist_ok=True)

def _new_job_id(original_filename: str) -> str:
    base_name = original_filename.rsplit(".", 1)[0].replace(" ", "_").replace("-", "_")
    # Use UUID4 for guaranteed uniqueness
    unique_id = str(uuid.uuid4())[:8]  # Use first 8 characters for shorter IDs
    return f"{base_name}_{unique_id}"

def submit_scan(file, options: dict, username: str) -> Dict[str, str]:
    """
    Synchronous 'enqueue': we persist job and file; actual analysis should be run
    by a background task calling process_scan().
    """
    if model is None or vectorizer is None:
        raise RuntimeError("Model artifacts are not loaded.")

    # sanitize and produce job_id
    original_filename = file.filename.rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
    job_id = _new_job_id(original_filename)
    app_name = original_filename.rsplit(".", 1)[0]

    # Save APK to Storage
    apk_path = STORAGE_DIR / f"{job_id}.apk"
    with open(apk_path, "wb") as out_file:
        shutil.copyfileobj(file.file, out_file)
    try:
        file_size = apk_path.stat().st_size
    except Exception:
        file_size = 0

    # Persist job in DB as 'processing' (synchronous scan flow)
    create_job(
        username=username,
        job_id=job_id,
        app_name=app_name,
        status="processing",
        options=options,
        file_size=int(file_size or 0),
    )

    return {"job_id": job_id, "app_name": app_name}



def process_scan(username: str, job_id: str):
    """
    Background task: performs analysis, writes result JSON, optionally Gemini, updates DB.
    """
    update_job_status(job_id, "processing")
    apk_path = STORAGE_DIR / f"{job_id}.apk"
    json_path = STORAGE_DIR / f"{job_id}.json"

    try:
        # Get options from DB (and validate ownership)
        job = get_user_job(username, job_id)
        if not job:
            update_job_status(job_id, "failed")
            return
        options = job.get("options", {}) or {}

        # Direct analysis without timeout - let it complete naturally
        result = analyze_apk(
            str(apk_path),
            model=model,
            vectorizer=vectorizer,
            top_malware_features=top_features,
            run_pentest=options.get("run_pentest", True),
            run_anomaly=options.get("run_anomaly", True),
        )

        # Save result to DB & disk
        save_job_result(job_id, result)
        try:
            set_job_prediction(job_id, result.get("prediction"))
        except Exception:
            pass
        with json_path.open("w", encoding="utf-8") as f:
            json.dump(result, f, indent=4)

        # Optional Gemini inline
        if options.get("use_gemini") and options.get("gemini_api_key"):
            vulns = result.get("vulnerabilities_found", [])
            report = get_vulnerability_explanation(options["gemini_api_key"], vulns)
            save_gemini_report(job_id, report)

        update_job_status(job_id, "done")

    except Exception as e:
        update_job_status(job_id, "failed")
        save_job_result(job_id, {"error": str(e)})
    finally:
        # Remove APK after analysis attempt
        try:
            if apk_path.exists():
                apk_path.unlink()
        except Exception:
            pass

def get_result(username: str, job_id: str) -> Optional[Dict[str, Any]]:
    job = get_user_job(username, job_id)
    return job.get("result") if job else None

def get_status(username: str, job_id: str) -> str:
    job = get_user_job(username, job_id)
    return job["status"] if job else "not_found"

def get_history(username: str):
    return db_get_history(username)

def get_download_path(job_id: str):
    json_path = STORAGE_DIR / f"{job_id}.json"
    return json_path if json_path.exists() else None

def get_gemini_report(username: str, job_id: str):
    job = get_user_job(username, job_id)
    if not job:
        return None
    return job.get("gemini_report")

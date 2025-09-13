import os
import shutil
import random
import json
import sys
from pathlib import Path
from ml_worker.apk_analyzer import analyze_apk, get_vulnerability_explanation
import joblib

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

# Per-user job storage: username -> {job_id: job_data}
USER_JOBS = {}

STORAGE_DIR = Path(__file__).parent.parent / "storage"
STORAGE_DIR.mkdir(exist_ok=True)


def submit_scan(file, options: dict, username: str):
    original_filename = file.filename.rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
    base_name = original_filename.rsplit(".", 1)[0].replace(" ", "_")
    suffix = random.randint(1000, 9999)
    job_id = f"{base_name}_{suffix}"

    apk_path = STORAGE_DIR / f"{job_id}.apk"
    with open(apk_path, "wb") as out_file:
        shutil.copyfileobj(file.file, out_file)

    USER_JOBS.setdefault(username, {})
    USER_JOBS[username][job_id] = {
        "status": "queued",
        "result": None,
        "options": options,
        "app_name": base_name  # Store APK name here
    }
    try:
        USER_JOBS[username][job_id]["status"] = "processing"
        result = analyze_apk(
            str(apk_path),
            model=model,
            vectorizer=vectorizer,
            top_malware_features=top_features,
            run_pentest=options.get("run_pentest", True),
            run_anomaly=options.get("run_anomaly", True)
        )
        USER_JOBS[username][job_id]["status"] = "done"
        USER_JOBS[username][job_id]["result"] = result

        json_path = STORAGE_DIR / f"{job_id}.json"
        with json_path.open("w") as f:
            json.dump(result, f, indent=4)

        apk_path.unlink()
    except Exception as e:
        USER_JOBS[username][job_id]["status"] = "failed"
        USER_JOBS[username][job_id]["result"] = {"error": str(e)}
        if apk_path.exists():
            apk_path.unlink()

    return job_id


def get_result(username: str, job_id: str):
    user_jobs = USER_JOBS.get(username, {})
    job = user_jobs.get(job_id)
    if not job or job.get("result") is None:
        return None
    return job["result"]


def get_status(username: str, job_id: str):
    user_jobs = USER_JOBS.get(username, {})
    job = user_jobs.get(job_id)
    if not job:
        return "not_found"
    return job["status"]


def get_history(username: str):
    user_jobs = USER_JOBS.get(username, {})
    history = []
    for job_id, job_data in user_jobs.items():
        history.append({
            "job_id": job_id,
            "status": job_data["status"],
            "app_name": job_data.get("app_name", "unknown")
        })
    return history


def get_download_path(job_id: str):
    json_path = STORAGE_DIR / f"{job_id}.json"
    if json_path.exists():
        return json_path
    return None


def generate_gemini_report(username: str, job_id: str, api_key: str):
    user_jobs = USER_JOBS.get(username, {})
    job = user_jobs.get(job_id)
    if not job:
        return None
    result = job.get("result")
    if not result:
        return None
    vulnerabilities = result.get("vulnerabilities_found", [])
    try:
        report = get_vulnerability_explanation(api_key, vulnerabilities)
        USER_JOBS[username][job_id]["gemini_report"] = report
        return report
    except Exception as e:
        return f"Error generating Gemini report: {e}"

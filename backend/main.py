# backend/main.py
from fastapi import (
    FastAPI,
    Depends,
    UploadFile,
    File,
    HTTPException,
    Query,
    Header,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.openapi.utils import get_openapi
import secrets
import os

from backend.db import init_db, create_user
from backend.auth import validate_api_key, is_admin, ADMIN_API_KEY
from backend.models import (
    ScanResponse,
    JobStatus,
    FullReport,
    PentestResult,
    AnomalyResult,
    GeminiReport,
    JobHistory,
    JobHistoryItem,
)
from backend.service import (
    submit_scan,
    process_scan,
    get_result,
    get_status,
    get_history,
    get_download_path,
    get_gemini_report,
)

app = FastAPI(title="CipherX APK Security Analysis Backend")

# ----- init DB on startup -----
init_db()

# ----- (optional) CORS for local UI -----
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.environ.get("CORS_ALLOW_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------ Admin ------------------

@app.post("/admin/create-user", tags=["Admin"])
async def create_user_endpoint(
    username: str,
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
):
    if not is_admin(x_admin_key):
        raise HTTPException(403, "Forbidden: Invalid admin key")
    try:
        api_key = create_user(username)
        return {"username": username, "api_key": api_key}
    except ValueError:
        raise HTTPException(400, "Username already exists")

# ------------------ User ------------------

@app.post("/scan", response_model=ScanResponse, tags=["User"])
async def scan_apk(
    file: UploadFile = File(...),
    current_username: str = Depends(validate_api_key),
    run_pentest: bool = Query(True),
    run_anomaly: bool = Query(True),
    use_gemini: bool = Query(False),
    gemini_api_key: str = Query(None),
):
    # simple guard: only .apk
    if not (file.filename or "").lower().endswith(".apk"):
        raise HTTPException(400, "Only .apk files are accepted")

    options = {
        "run_pentest": run_pentest,
        "run_anomaly": run_anomaly,
        "use_gemini": use_gemini,
        "gemini_api_key": gemini_api_key,
    }

    job = submit_scan(file, options, current_username)
    # synchronous processing
    process_scan(current_username, job["job_id"])
    return ScanResponse(job_id=job["job_id"], job_name=job["app_name"], status="done")

@app.get("/status/{job_id}", response_model=JobStatus, tags=["User"])
async def status(job_id: str, current_username: str = Depends(validate_api_key)):
    status_value = get_status(current_username, job_id)
    if status_value == "not_found":
        raise HTTPException(404, "Job ID not found")
    # App name from history (cheap fetch)
    hist = get_history(current_username)
    app_name = next((h["app_name"] for h in hist if h["job_id"] == job_id), "")
    return JobStatus(job_id=job_id, job_name=app_name, status=status_value, progress=100 if status_value == "done" else 0)

@app.get("/result/{job_id}", response_model=FullReport, tags=["User"])
async def full_report(job_id: str, current_username: str = Depends(validate_api_key)):
    result = get_result(current_username, job_id)
    if not result:
        raise HTTPException(404, "Result not found or job incomplete")
    hist = get_history(current_username)
    app_name = next((h["app_name"] for h in hist if h["job_id"] == job_id), "")
    return FullReport(job_id=job_id, job_name=app_name, result=result)

@app.get("/pentest/{job_id}", response_model=PentestResult, tags=["User"])
async def pentest_only(job_id: str, current_username: str = Depends(validate_api_key)):
    result = get_result(current_username, job_id)
    if not result or "pentest_findings" not in result:
        raise HTTPException(404, "Pentest results not found")
    hist = get_history(current_username)
    app_name = next((h["app_name"] for h in hist if h["job_id"] == job_id), "")
    return PentestResult(job_id=job_id, job_name=app_name, pentest_findings=result["pentest_findings"])

@app.get("/anomaly/{job_id}", response_model=AnomalyResult, tags=["User"])
async def anomaly_only(job_id: str, current_username: str = Depends(validate_api_key)):
    result = get_result(current_username, job_id)
    if not result or "anomaly_detection" not in result:
        raise HTTPException(404, "Anomaly detection results not found")
    hist = get_history(current_username)
    app_name = next((h["app_name"] for h in hist if h["job_id"] == job_id), "")
    return AnomalyResult(job_id=job_id, job_name=app_name, anomaly_detection=result["anomaly_detection"])

@app.get("/gemini/{job_id}", response_model=GeminiReport, tags=["User"])
async def gemini_report(job_id: str, current_username: str = Depends(validate_api_key)):
    report = get_gemini_report(current_username, job_id)
    if report is None:
        raise HTTPException(404, "Gemini report not available for this job")
    hist = get_history(current_username)
    app_name = next((h["app_name"] for h in hist if h["job_id"] == job_id), "")
    return GeminiReport(job_id=job_id, job_name=app_name, gemini_report=report)

@app.get("/history", response_model=JobHistory, tags=["User"])
async def job_history(current_username: str = Depends(validate_api_key)):
    raw = get_history(current_username)
    items = []
    for item in raw:
        items.append(
            JobHistoryItem(
                name=item["app_name"],
                prediction=item.get("prediction"),
                file_size=int(item.get("file_size") or 0),
                id=item["job_id"],
                date_time=str(item.get("created_at")),
                download=f"/download/{item['job_id']}",
            )
        )
    return JobHistory(items=items)

@app.get("/download/{job_id}", tags=["User"])
async def download_report(job_id: str, current_username: str = Depends(validate_api_key)):
    path = get_download_path(job_id)
    if not path:
        raise HTTPException(404, "Download file not found")
    return FileResponse(str(path), filename=f"{job_id}.json", media_type="application/json")

@app.get("/", tags=["Root"])
async def root():
    return {"message": "CipherX backend is up and running"}

# ----- Swagger API-key hint -----
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    openapi_schema["components"]["securitySchemes"] = {
        "ApiKeyAuth": {
            "type": "apiKey",
            "in": "header",
            "name": "Authorization",
            "description": "API key only in the Authorization header",
        }
    }
    openapi_schema["security"] = [{"ApiKeyAuth": []}]
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi

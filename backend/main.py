from fastapi import (
    FastAPI,
    Depends,
    UploadFile,
    File,
    HTTPException,
    Query,
    Header,
)
from fastapi.responses import FileResponse
from fastapi.openapi.utils import get_openapi
import secrets

from backend.auth import validate_api_key, is_admin, VALID_API_KEYS, ADMIN_API_KEY
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
    get_result,
    get_status,
    get_history,
    get_download_path,
    generate_gemini_report,
    USER_JOBS,
)

app = FastAPI(title="CipherX APK Security Analysis Backend")

@app.post("/admin/create-user", tags=["Admin"])
async def create_user(
    username: str,
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
):
    if not is_admin(x_admin_key):
        raise HTTPException(403, "Forbidden: Invalid admin key")
    if username in USER_JOBS:
        raise HTTPException(400, "Username already exists")
    api_key = secrets.token_urlsafe(32)
    VALID_API_KEYS[api_key] = username
    USER_JOBS[username] = {}
    return {"username": username, "api_key": api_key}


@app.post("/scan", response_model=ScanResponse, tags=["User"])
async def scan_apk(
    file: UploadFile = File(...),
    current_username: str = Depends(validate_api_key),
    run_pentest: bool = Query(True),
    run_anomaly: bool = Query(True),
    use_gemini: bool = Query(False),
    gemini_api_key: str = Query(None),
):
    options = {
        "run_pentest": run_pentest,
        "run_anomaly": run_anomaly,
        "use_gemini": use_gemini,
        "gemini_api_key": gemini_api_key,
    }
    job_id = submit_scan(file, options, current_username)
    app_name = USER_JOBS[current_username][job_id]["app_name"]
    return ScanResponse(job_id=job_id, job_name=app_name, status="queued")


@app.get("/status/{job_id}", response_model=JobStatus, tags=["User"])
async def status(job_id: str, current_username: str = Depends(validate_api_key)):
    status_value = get_status(current_username, job_id)
    if status_value == "not_found":
        raise HTTPException(404, "Job ID not found")
    app_name = USER_JOBS[current_username][job_id].get("app_name", "") if status_value != "not_found" else ""
    return JobStatus(job_id=job_id, job_name=app_name, status=status_value, progress=100 if status_value == "done" else 0)


@app.get("/result/{job_id}", response_model=FullReport, tags=["User"])
async def full_report(job_id: str, current_username: str = Depends(validate_api_key)):
    user_jobs = USER_JOBS.get(current_username, {})
    job = user_jobs.get(job_id)
    if not job or job.get("result") is None:
        raise HTTPException(404, "Result not found or job incomplete")
    return FullReport(job_id=job_id, job_name=job.get("app_name", ""), result=job["result"])


@app.get("/pentest/{job_id}", response_model=PentestResult, tags=["User"])
async def pentest_only(job_id: str, current_username: str = Depends(validate_api_key)):
    result = get_result(current_username, job_id)
    if not result or "pentest_findings" not in result:
        raise HTTPException(404, "Pentest results not found")
    app_name = USER_JOBS[current_username][job_id].get("app_name", "")
    return PentestResult(job_id=job_id, job_name=app_name, pentest_findings=result["pentest_findings"])


@app.get("/anomaly/{job_id}", response_model=AnomalyResult, tags=["User"])
async def anomaly_only(job_id: str, current_username: str = Depends(validate_api_key)):
    result = get_result(current_username, job_id)
    if not result or "anomaly_detection" not in result:
        raise HTTPException(404, "Anomaly detection results not found")
    app_name = USER_JOBS[current_username][job_id].get("app_name", "")
    return AnomalyResult(job_id=job_id, job_name=app_name, anomaly_detection=result["anomaly_detection"])


@app.get("/gemini/{job_id}", response_model=GeminiReport, tags=["User"])
async def gemini_report(
    job_id: str, current_username: str = Depends(validate_api_key), gemini_api_key: str = Query(None)
):
    if not gemini_api_key:
        raise HTTPException(400, "Gemini API key is required")
    report = generate_gemini_report(current_username, job_id, gemini_api_key)
    if report is None:
        raise HTTPException(404, "Gemini report could not be generated")
    app_name = USER_JOBS[current_username][job_id].get("app_name", "")
    return GeminiReport(job_id=job_id, job_name=app_name, gemini_report=report)


@app.get("/history", response_model=JobHistory, tags=["User"])
async def job_history(current_username: str = Depends(validate_api_key)):
    user_jobs = USER_JOBS.get(current_username, {})
    history = [
        JobHistoryItem(
            job_id=job_id,
            job_name=data.get("app_name", ""),
            status=data.get("status", "unknown"),
        )
        for job_id, data in user_jobs.items()
    ]
    return JobHistory(jobs=history)


@app.get("/download/{job_id}", tags=["User"])
async def download_report(job_id: str, current_username: str = Depends(validate_api_key)):
    path = get_download_path(job_id)
    if not path:
        raise HTTPException(404, "Download file not found")
    return FileResponse(str(path), filename=f"{job_id}.json", media_type="application/json")


@app.get("/", tags=["Root"])
async def root():
    return {"message": "CipherX backend is up and running"}


# OpenAPI schema customization to show API key auth in Swagger UI

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

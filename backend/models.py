from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any

class JobHistoryItem(BaseModel):
    name: str
    prediction: Optional[str] = None
    file_size: int
    id: str
    date_time: str
    download: str

class JobHistory(BaseModel):
    items: List[JobHistoryItem]

class ScanOptions(BaseModel):
    run_pentest: bool = True
    run_anomaly: bool = True
    use_gemini: bool = False
    gemini_api_key: Optional[str] = None

class ScanResponse(BaseModel):
    job_id: str
    job_name: str
    status: str

class JobStatus(BaseModel):
    job_id: str
    job_name: str
    status: str
    progress: int = 0
    detail: Optional[str] = None

class PentestResult(BaseModel):
    job_id: str
    job_name: str
    pentest_findings: List[Dict]

class AnomalyResult(BaseModel):
    job_id: str
    job_name: str
    anomaly_detection: Dict

class FullReport(BaseModel):
    job_id: str
    job_name: str
    result: Dict

class GeminiReport(BaseModel):
    job_id: str
    job_name: str
    gemini_report: str

class LoginRequest(BaseModel):
    username: str
    api_key: str

class LoginResponse(BaseModel):
    ok: bool
    role: Optional[str] = None
    username: Optional[str] = None
    message: Optional[str] = None

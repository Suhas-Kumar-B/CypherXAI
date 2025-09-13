from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any

class JobHistoryItem(BaseModel):
    job_id: str = Field(..., description="Unique job identifier")
    job_name: str = Field(..., description="APK file base name (app name)")
    status: str = Field(..., description="Current job status (queued, processing, done, failed)")

class JobHistory(BaseModel):
    jobs: List[JobHistoryItem]

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

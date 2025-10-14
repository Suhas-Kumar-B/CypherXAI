<!-- .github/copilot-instructions.md for CypherXAI -->
# Copilot instructions — CypherXAI (concise)

This file helps automated coding agents get productive quickly in the CypherXAI repository. Keep entries specific and code-referenced; follow the examples.

1) High-level architecture (what to know first)
- Backend: FastAPI app in `backend/main.py` exposing user and admin endpoints. Key flow: `/scan` -> `backend.service.submit_scan()` -> `backend.service.process_scan()` -> `ml_worker` analysis -> results persisted in SQLite (`backend/cipherx.db`) via `backend/db.py`.
- Frontend: Flutter app under `cipherx_frontend/` — entry `lib/main.dart`. Network layer: `lib/services/api_client.dart` talks to backend using REST endpoints in `backend/main.py`.
- ML worker: Python scripts in `ml_worker/` (`apk_analyzer.py`, `apk_feature_extractor.py`, `worker.py`) contain the analysis logic and model artifacts (`*.joblib`, `top_malware_features.json`). Backend imports these directly (synchronous flow).

2) Primary service boundaries and data flows
- File upload flow: Frontend -> `ApiClient.scanApkWithFile()` -> POST `/scan` (FastAPI). Backend writes APK to `Storage/`, creates DB job row, then calls `process_scan()` which uses `ml_worker` code and writes a `{job_id}.json` in `Storage/` and updates DB.
- Admin surface: routes under `/admin/*` in `backend/main.py` are protected by a legacy `ADMIN_API_KEY` header (`X-Admin-Key`) and optional email checks against `admins` table. `ApiClient` uses `ApiEndpoints.adminKeyHeader` to set this header.
- Auth: simple API-key based auth. The Authorization header contains the user's API key. Look at `backend/auth.py` and `backend/db.py` for validation and seeded test credentials.

3) Key conventions and project-specific patterns
- Single-file storage: job artifacts are persisted under `Storage/` with predictable names: `{job_id}.apk` and `{job_id}.json` (see `backend/service.py` STORAGE_DIR constant). Code expects these filenames.
- SQLite DB: `backend/db.py` is the source of truth for jobs/users/admins. Use its helper functions (`create_job`, `get_user_job`, `save_job_result`, etc.) when changing persistence logic.
- Environment-configured admin key: `ADMIN_API_KEY` environment variable is used both to seed the initial admin user and to protect admin endpoints. Local defaults exist (`your-secure-admin-key`) — prefer setting env vars in dev/test.
- ML artifacts loaded at import: `backend/service.py` attempts to load joblib files at import time and will set `model=None` if missing; many functions guard against missing artifacts by raising RuntimeError. Don't change import-time loading without updating error handling.

4) Developer workflows (how to run, test, debug)
- Backend dev server (expected): run FastAPI with uvicorn targeting `backend.main:app`. Example (PowerShell):
```
python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```
- Frontend dev (Flutter): open `cipherx_frontend/` and use Flutter tooling as usual. The Flutter app expects a `BASE_URL` compile-time var to target the backend; defaults to `http://127.0.0.1:8000` in `ApiClient`.
- ML artifacts: Ensure `ml_worker/*.joblib` and `top_malware_features.json` are present under `ml_worker/` before starting the backend. Missing artifacts will print errors to stderr and the backend will not accept scans.
- Tests: There are a few Python tests at repository root (`test_admin.py`, `test_api.py`) and helper PowerShell scripts (`test_complete.ps1`, `e2e.ps1`). Run unit tests using the Python environment that satisfies `backend/requirements.txt` and `ml_worker/requirements.txt` if present.

5) Common fixes and gotchas (explicit patterns seen in code)
- When adding new endpoints, update `backend/main.py`'s OpenAPI security schema if the endpoint requires API-key auth (see `custom_openapi()` override).
- Job IDs: created via `_new_job_id()` in `backend/service.py` and are used to name files in `Storage/`. Avoid changing job ID format without migrating existing artifact lookups.
- Concurrency: DB connection uses `check_same_thread=False` and a module-level `_LOCK` to coordinate writes. Keep using `_LOCK` when adding DB mutations to avoid races.
- Removing APKs: `process_scan()` deletes the `.apk` after analysis. If you want to persist APKs, update both the deletion logic and any downstream consumers.

6) Code patterns and examples (copyable guidance)
- Read job result example (backend):
  - Use `from backend.db import get_user_job` and then `job = get_user_job(username, job_id); result = job.get('result')`
- Create admin via frontend ApiClient (example already in `api_client.dart`):
  - `await apiClient.createUserWithKey(username: 'alice', apiKey: 'provided-key')` which calls `/admin/create-user` with header `X-Admin-Key`.
- Trigger a scan from Flutter (example): use `ApiClient.scanApkWithFile(apiKey: userKey, file: pickedFile)` — the URL and query params are constructed in `api_client.dart`.

7) Integration points & external dependencies
- Gemini/LLM integration: optional Gemini report generation is performed if `use_gemini` and `gemini_api_key` are supplied. The call path is `ml_worker.apk_analyzer.get_vulnerability_explanation(...)` → `backend.db.save_gemini_report()`.
- Model artifacts: `ml_worker/*.joblib` (scikit-learn or similar) and `top_malware_features.json` — editing feature names requires coordinating backend `vectorizer` usage and ML code in `ml_worker/`.

8) Safety & environment notes for agents
- Do not hardcode production secrets. Use `ADMIN_API_KEY` and other secrets via environment variables.
- Avoid changing the SQLite schema without adding migration steps: `backend/db.py` contains ad-hoc column checks used to upgrade older DBs.

9) Where to look next (key files)
- `backend/main.py` — API surface and routing
- `backend/service.py` — job lifecycle, Storage dir, model loading
- `backend/db.py` — DB schema and helper functions
- `backend/auth.py` — auth rules and header names
- `cipherx_frontend/lib/services/api_client.dart` — client conventions and header usage
- `ml_worker/` — analysis pipeline and model loading

If anything above is unclear or you'd like more examples (curl, Flutter widget usage, or test commands), say which area to expand and I will iterate.

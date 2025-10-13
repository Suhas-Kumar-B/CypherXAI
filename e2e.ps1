$ErrorActionPreference = 'Stop'

$admin = 'your-secure-admin-key'

# Create unique username to avoid conflict on reruns
$uname = 'alice-' + [guid]::NewGuid().ToString('N').Substring(0,6)

try {
  $resp = Invoke-RestMethod -Method POST "http://127.0.0.1:8000/admin/create-user?username=$uname" -Headers @{ 'X-Admin-Key' = $admin }
} catch {
  Write-Host "Admin create-user failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

$API = $resp.api_key
Write-Host ("API=" + ($API.Substring(0,6) + '***'))
Write-Host ("username=" + $uname)

# APK path provided by user
$APK = "C:\Users\VISHNU P\Downloads\small_universal.apk"
if (-not (Test-Path $APK)) {
  Write-Host ("APK not found: " + $APK) -ForegroundColor Red
  exit 1
}

# Scan options - user-controllable flags
$run_pentest = $false
$run_anomaly = $false
$use_gemini = $false
$gemini_key = ''

$qs = "run_pentest=$($run_pentest.ToString().ToLower())&run_anomaly=$($run_anomaly.ToString().ToLower())&use_gemini=$($use_gemini.ToString().ToLower())"
if ($gemini_key) { $qs += "&gemini_api_key=$gemini_key" }

# Use curl for multipart form upload on Windows PowerShell 5.1
$scanJson = curl.exe -s -X POST "http://127.0.0.1:8000/scan?$qs" -H "Authorization: $API" -F "file=@$APK"
if (-not $scanJson) { Write-Host "Scan request failed (no response)." -ForegroundColor Red; exit 1 }
$scan = $scanJson | ConvertFrom-Json

Write-Host ("JOB=" + $scan.job_id)
$job = $scan.job_id

# Poll status
$tries = 120
for ($i=0; $i -lt $tries; $i++) {
  $st = Invoke-RestMethod "http://127.0.0.1:8000/status/$job" -Headers @{ Authorization = $API }
  Write-Host ("status: " + $st.status)
  if ($st.status -eq 'done' -or $st.status -eq 'failed') { break }
  Start-Sleep -Seconds 5
}

# Fetch result
try {
  $result = Invoke-RestMethod "http://127.0.0.1:8000/result/$job" -Headers @{ Authorization = $API }
  $result | ConvertTo-Json -Depth 6 | Write-Host
} catch {
  Write-Host "Result fetch failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Fetch history
$hist = Invoke-RestMethod "http://127.0.0.1:8000/history" -Headers @{ Authorization = $API }
$hist | ConvertTo-Json -Depth 6 | Write-Host

# Download report
$out = Join-Path $env:TEMP ($job + '.json')
Invoke-WebRequest "http://127.0.0.1:8000/download/$job" -Headers @{ Authorization = $API } -OutFile $out
Write-Host ("Downloaded: " + $out)



$ErrorActionPreference = 'Continue'

Write-Host "Starting comprehensive API test..." -ForegroundColor Cyan

$BASE_URL = "http://127.0.0.1:8000"
$ADMIN_KEY = "your-secure-admin-key"
$APK_PATH = "C:\Users\VISHNU P\Downloads\small_universal.apk"
$API_KEY = $null
$JOB_ID = $null

# 1. Test root endpoint
Write-Host "`n1. Testing root endpoint..." -ForegroundColor Yellow
try {
  $root_response = Invoke-RestMethod $BASE_URL
  Write-Host "✓ Root endpoint working: $($root_response.message)" -ForegroundColor Green
} 
catch {
  Write-Host "✗ Root endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Create admin user
Write-Host "`n2. Creating user via admin..." -ForegroundColor Yellow
try {
  $username = "test_user_$(Get-Date -Format 'HHmmss')"
  $create_response = Invoke-RestMethod -Method POST "$BASE_URL/admin/create-user?username=$username" -Headers @{ "X-Admin-Key" = $ADMIN_KEY }
  $API_KEY = $create_response.api_key
  Write-Host "✓ User created: $username" -ForegroundColor Green
  Write-Host "✓ API Key: $($API_KEY.Substring(0, 10))..." -ForegroundColor Green
} 
catch {
  Write-Host "✗ User creation failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Exiting..." -ForegroundColor Red
  return
}

# 3. Verify APK file exists
Write-Host "`n3. Checking APK file..." -ForegroundColor Yellow
if (-not (Test-Path $APK_PATH)) {
  Write-Host "✗ APK file not found: $APK_PATH" -ForegroundColor Red
  Write-Host "Exiting..." -ForegroundColor Red
  return
} 
else {
  Write-Host "✓ APK file found: $APK_PATH" -ForegroundColor Green
}

# 4. Test scan with multipart upload
Write-Host "`n4. Testing scan with multipart upload..." -ForegroundColor Yellow
try {
  Write-Host "Starting scan with pentest=true, anomaly=true, gemini=false..."
  
  # Use curl for proper multipart form upload
  $curlCmd = "curl.exe -s -X POST `"$BASE_URL/scan?run_pentest=true&run_anomaly=true&use_gemini=false`" -H `"Authorization: $API_KEY`" -F `"file=@$APK_PATH`""
  
  Write-Host "Running: curl multipart upload..."
  $scanJson = & cmd.exe /c $curlCmd
  
  if ($scanJson) {
    $scan_response = $scanJson | ConvertFrom-Json
    $JOB_ID = $scan_response.job_id
    Write-Host "✓ Scan completed: $JOB_ID" -ForegroundColor Green
    Write-Host "Response: $(ConvertTo-Json $scan_response -Depth 3)" -ForegroundColor Cyan
  } 
  else {
    Write-Host "✗ No response from scan" -ForegroundColor Red
  }
} 
catch {
  Write-Host "✗ Scan failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Check status if scan succeeded
if ($JOB_ID) {
  Write-Host "`n5. Checking status..." -ForegroundColor Yellow
  try {
    $status_response = Invoke-RestMethod "$BASE_URL/status/$JOB_ID" -Headers @{ "Authorization" = $API_KEY }
    Write-Host "✓ Status check:" -ForegroundColor Green
    Write-Host $(ConvertTo-Json $status_response -Depth 3) -ForegroundColor Cyan
  } 
  catch {
    Write-Host "✗ Status check failed: $($_.Exception.Message)" -ForegroundColor Red
  }
}

# 6. Fetch result
if ($JOB_ID) {
  Write-Host "`n6. Fetching result..." -ForegroundColor Yellow
  try {
    $result_response = Invoke-RestMethod "$BASE_URL/result/$JOB_ID" -Headers @{ "Authorization" = $API_KEY }
    Write-Host "✓ Result obtained:" -ForegroundColor Green
    Write-Host $(ConvertTo-Json $result_response -Depth 6) -ForegroundColor Cyan
  } 
  catch {
    Write-Host "✗ Result failed: $($_.Exception.Message)" -ForegroundColor Red
  }
}

# 7. Test download
if ($JOB_ID) {
  Write-Host "`n7. Testing download..." -ForegroundColor Yellow
  try {
    $download_path = "$env:TEMP\apk_report_$JOB_ID.json"
    Invoke-WebRequest "$BASE_URL/download/$JOB_ID" -Headers @{ "Authorization" = $API_KEY } -OutFile $download_path
    if (Test-Path $download_path) {
      Write-Host "✓ Download successful: $download_path" -ForegroundColor Green
      Write-Host "File size: $((Get-Item $download_path).Length) bytes" -ForegroundColor Green
    } 
    else {
      Write-Host "✗ Download file not created" -ForegroundColor Red
    }
  } 
  catch {
    Write-Host "✗ Download failed: $($_.Exception.Message)" -ForegroundColor Red
  }
}

# 8. Check history
Write-Host "`n8. Checking history..." -ForegroundColor Yellow
try {
  $history_response = Invoke-RestMethod "$BASE_URL/history" -Headers @{ "Authorization" = $API_KEY }
  Write-Host "✓ History obtained:" -ForegroundColor Green
  Write-Host $(ConvertTo-Json $history_response -Depth 6) -ForegroundColor Cyan
  
  # Verify required fields
  if ($history_response.items.Count -gt 0) {
    $first_item = $history_response.items[0]
    Write-Host "First item fields: $($first_item.PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
    
    $required_fields = @("name", "prediction", "file_size", "id", "date_time", "download")
    $available_fields = $first_item.PSObject.Properties.Name
    $missing_fields = $required_fields | Where-Object { $_ -notin $available_fields }
    
    if ($missing_fields.Count -eq 0) {
      Write-Host "✓ All required fields present: $($required_fields -join ', ')" -ForegroundColor Green
    } 
    else {
      Write-Host "✗ Missing required fields: $($missing_fields -join ', ')" -ForegroundColor Red
    }
    
    # Show values
    Write-Host "Sample values:" -ForegroundColor Yellow
    foreach ($field in $required_fields) {
      Write-Host "  $field = $($first_item.$field)" -ForegroundColor Cyan
    }
  } 
  else {
    Write-Host "✗ No items in history" -ForegroundColor Red
  }
} 
catch {
  Write-Host "✗ History check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest completed!" -ForegroundColor Green
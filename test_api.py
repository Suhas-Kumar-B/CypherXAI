import requests
import json
import os
import sys
from pathlib import Path

BASE_URL = "http://127.0.0.1:8000"
ADMIN_KEY = "your-secure-admin-key"
APK_PATH = r"C:\Users\VISHNU P\Downloads\small_universal.apk"

print("Starting comprehensive API test...")

# 1. Test root endpoint
print("\n1. Testing root endpoint...")
try:
    resp = requests.get(BASE_URL)
    if resp.status_code == 200:
        print(f"✓ Root endpoint working: {resp.json()}")
    else:
        print(f"✗ Root endpoint failed: {resp.status_code}")
except Exception as e:
    print(f"✗ Root endpoint failed: {e}")

# 2. Create admin user
print("\n2. Creating user via admin...")
try:
    username = f"test_user_{hash('time_salt') % 10000}"
    resp = requests.post(f"{BASE_URL}/admin/create-user?username={username}", 
                         headers={"X-Admin-Key": ADMIN_KEY})
    if resp.status_code == 200:
        user_data = resp.json()
        api_key = user_data["api_key"]
        print(f"✓ User created: {username}")
        print(f"✓ API Key: {api_key[:10]}...")
    else:
        print(f"✗ User creation failed: {resp.status_code} - {resp.text}")
        sys.exit(1)
except Exception as e:
    print(f"✗ User creation failed: {e}")
    sys.exit(1)

# 3. Verify APK file exists
print("\n3. Checking APK file...")
if not os.path.exists(APK_PATH):
    print(f"✗ APK file not found: {APK_PATH}")
    sys.exit(1)
else:
    print(f"✓ APK file found: {APK_PATH}")

# 4. Test scan
print("\n4. Testing scan...")
try:
    with open(APK_PATH, 'rb') as apk_file:
        files = {"file": apk_file}
        data = {
            "run_pentest": "true",
            "run_anomaly": "true", 
            "use_gemini": "false"
        }
        resp = requests.post(f"{BASE_URL}/scan", 
                            headers={"Authorization": api_key},
                            files=files,
                            data=data)
    
    if resp.status_code == 200:
        scan_data = resp.json()
        job_id = scan_data["job_id"]
        print(f"✓ Scan completed: {job_id}")
        print(f"Response: {json.dumps(scan_data, indent=2)}")
    else:
        print(f"✗ Scan failed: {resp.status_code} - {resp.text}")
        job_id = None
except Exception as e:
    print(f"✗ Scan failed: {e}")
    job_id = None

# 5. Check status
if job_id:
    print("\n5. Checking status...")
    try:
        resp = requests.get(f"{BASE_URL}/status/{job_id}",
                           headers={"Authorization": api_key})
        if resp.status_code == 200:
            status_data = resp.json()
            print(f"✓ Status check: {json.dumps(status_data, indent=2)}")
        else:
            print(f"✗ Status check failed: {resp.status_code}")
    except Exception as e:
        print(f"✗ Status check failed: {e}")

# 6. Fetch result  
if job_id:
    print("\n6. Fetching result...")
    try:
        resp = requests.get(f"{BASE_URL}/result/{job_id}",
                          headers={"Authorization": api_key})
        if resp.status_code == 200:
            result_data = resp.json()
            print(f"✓ Result obtained: {json.dumps(result_data, indent=2)}")
        else:
            print(f"✗ Result failed: {resp.status_code}")
    except Exception as e:
        print(f"✗ Result failed: {e}")

# 7. Test download
if job_id:
    print("\n7. Testing download...")
    try:
        resp = requests.get(f"{BASE_URL}/download/{job_id}",
                         headers={"Authorization": api_key})
        if resp.status_code == 200:
            download_path = f"C:\\temp\\apk_report_{job_id}.json"
            os.makedirs(os.path.dirname(download_path), exist_ok=True)
            with open(download_path, 'wb') as f:
                f.write(resp.content)
            print(f"✓ Download successful: {download_path}")
            print(f"Size: {len(resp.content)} bytes")
        else:
            print(f"✗ Download failed: {resp.status_code}")
    except Exception as e:
        print(f"✗ Download failed: {e}")

# 8. Check history
print("\n8. Checking history...")
try:
    resp = requests.get(f"{BASE_URL}/history",
                       headers={"Authorization": api_key})
    if resp.status_code == 200:
        history_data = resp.json()
        print(f"✓ History obtained: {json.dumps(history_data, indent=2)}")
        
        # Check required fields
        if history_data.get("items") and len(history_data["items"]) > 0:
            first_item = history_data["items"][0]
            required_fields = ["name", "prediction", "file_size", "id", "date_time", "download"]
            available_fields = list(first_item.keys())
            missing = [f for f in required_fields if f not in available_fields]
            
            if not missing:
                print(f"✓ All required fields present: {required_fields}")
            else:
                print(f"✗ Missing required fields: {missing}")
                
            # Show values
            print("Sample values:")
            for field in required_fields:
                if field in first_item:
                    print(f"  {field} = {first_item[field]}")
        else:
            print("✗ No items in history")
    else:
        print(f"✗ History check failed: {resp.status_code}")
except Exception as e:
    print(f"✗ History check failed: {e}")

print("\nTest completed!")


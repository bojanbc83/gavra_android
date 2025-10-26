@echo off
echo 🔥 FIREBASE FCM SETUP SCRIPT
echo ================================

echo.
echo 🔑 Step 1: Login to Google Cloud...
gcloud auth login

echo.
echo 📋 Step 2: Set project...
gcloud config set project gavra-notif-20250920162521

echo.
echo 🚀 Step 3: Enable Firebase Cloud Messaging API...
gcloud services enable fcm.googleapis.com

echo.
echo 🔧 Step 4: Enable Legacy Cloud Messaging (fallback)...
gcloud services enable googlecloudmessaging.googleapis.com

echo.
echo 📊 Step 5: Check enabled services...
gcloud services list --enabled | findstr messaging

echo.
echo 🔑 Step 6: Generate access token...
echo Getting access token for FCM V1 API...
for /f "tokens=*" %%i in ('gcloud auth application-default print-access-token') do set ACCESS_TOKEN=%%i

echo.
echo ✅ ACCESS TOKEN: %ACCESS_TOKEN%

echo.
echo 📨 Step 7: Send test notification...
curl -X POST "https://fcm.googleapis.com/v1/projects/gavra-notif-20250920162521/messages:send" ^
  -H "Authorization: Bearer %ACCESS_TOKEN%" ^
  -H "Content-Type: application/json" ^
  -d "{\"message\":{\"topic\":\"gavra_all_drivers\",\"data\":{\"type\":\"dodat\",\"datum\":\"2025-10-27\",\"putnik\":\"{\\\"ime\\\": \\\"Test Putnik\\\", \\\"id\\\": \\\"123\\\"}\"},\"notification\":{\"title\":\"✅ Test Putnik Dodat\",\"body\":\"Test notifikacija iz Google Cloud SDK - Trebao bi da čuješ zvuk!\"}}}"

echo.
echo 🎯 ZAVRŠENO! Proveri telefon za notifikaciju!
echo.
pause
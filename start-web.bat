@echo off
setlocal
cd /d "%~dp0"

where node >nul 2>&1 || (
  echo [ERROR] Node.js 22 or newer is required.
  pause
  exit /b 1
)

if not exist .env (
  node video_engine_backend\scripts\init-env.cjs
  if errorlevel 1 (echo [ERROR] Could not initialize the runtime environment.& pause & exit /b 1)
  echo [SETUP] Created .env. Configure PostgreSQL, Redis, and the admin login, then run this launcher again.
  pause
  exit /b 0
)
node video_engine_backend\scripts\init-env.cjs
if errorlevel 1 (echo [ERROR] Could not initialize the runtime environment.& pause & exit /b 1)

rem Reuse a healthy local server instead of starting a second copy on port 8080.
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8080/health' -TimeoutSec 2; if ($r.StatusCode -eq 200) { Start-Process 'http://127.0.0.1:8080'; exit 0 } } catch {}; exit 1"
if not errorlevel 1 (
  echo [OK] An MK School server is already running at http://127.0.0.1:8080
  echo If you changed code, stop its backend window with Ctrl+C and run this launcher again to load the new build.
  endlocal
  exit /b 0
)

if not exist video_engine_backend\node_modules\.bin\tsc.cmd (
  echo [*] Installing backend dependencies...
  pushd video_engine_backend
  if exist package-lock.json (call npm ci) else (call npm install)
  if errorlevel 1 (popd & echo [ERROR] Dependency installation failed.& pause & exit /b 1)
  popd
)

echo [*] Building the school backend...
pushd video_engine_backend
call npm run build
if errorlevel 1 (popd & echo [ERROR] Backend build failed.& pause & exit /b 1)
popd

echo [*] Starting the backend. Its console will show startup errors and server logs.
start "MK School Backend" /D "%~dp0" "%ComSpec%" /k node --env-file=.env video_engine_backend\dist\main.js

echo [*] Waiting for PostgreSQL, Redis, and the school server...
powershell -NoProfile -Command "$deadline=(Get-Date).AddSeconds(60); do { try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8080/health' -TimeoutSec 2; if ($r.StatusCode -eq 200) { Start-Process 'http://127.0.0.1:8080'; exit 0 } } catch {}; Start-Sleep -Milliseconds 500 } while ((Get-Date) -lt $deadline); exit 1"
if errorlevel 1 (
  echo [ERROR] The server did not become healthy within 60 seconds.
  echo Check the backend window and configure PostgreSQL, Redis, and .env.
  pause
  exit /b 1
)

echo [OK] MK School is running at http://127.0.0.1:8080
endlocal

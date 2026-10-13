@echo off
cd /d "%~dp0"
where node >nul 2>&1 || (echo [ERROR] Node.js 22+ is required.& pause & exit /b 1)
if not exist .env (
  node video_engine_backend\scripts\init-env.cjs
  if errorlevel 1 (echo [ERROR] Could not initialize environment.& pause & exit /b 1)
  echo [SETUP] Created .env. Configure PostgreSQL, Redis, and the admin login, then run this launcher again.
  pause
  exit /b 0
)
node video_engine_backend\scripts\init-env.cjs
if errorlevel 1 (echo [ERROR] Could not initialize environment.& pause & exit /b 1)
pushd video_engine_backend
call npm run build
if errorlevel 1 (popd & echo [ERROR] Backend build failed.& pause & exit /b 1)
popd
if not exist node_modules\electron (call npm install electron --silent)
echo [*] Starting MK School Ultra Desktop App (Electron)...
node --env-file=.env node_modules\electron\cli.js .
pause

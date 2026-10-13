@echo off
setlocal enabledelayedexpansion
title MK School V50 Enterprise Launcher
color 0b
echo ========================================================
echo        MK School V50 Ultra Enterprise System
echo      Desktop (Electron) + High-Scale Web Architecture
echo ========================================================
echo.

cd /d "%~dp0"

where node >nul 2>&1 || (
    echo [ERROR] Node.js is not installed!
    echo Please install Node.js 22 or newer from https://nodejs.org/
    pause
    exit /b 1
)

if not exist .env (
    node video_engine_backend\scripts\init-env.cjs
    if errorlevel 1 ( echo [ERROR] Could not initialize secure environment. & pause & exit /b 1 )
    echo [SETUP] Created .env. Configure PostgreSQL, Redis, and the admin login, then run this launcher again.
    pause
    exit /b 0
)
node video_engine_backend\scripts\init-env.cjs
if errorlevel 1 ( echo [ERROR] Could not initialize secure environment. & pause & exit /b 1 )

echo [*] Checking Backend Dependencies...
if not exist video_engine_backend\node_modules\.bin\tsc.cmd (
    echo [*] Installing backend modules...
    pushd video_engine_backend
    if exist package-lock.json (call npm ci) else (call npm install)
    if errorlevel 1 (popd & echo [ERROR] Backend dependency installation failed.& pause & exit /b 1)
    popd
)

echo [*] Compiling TypeScript backend...
pushd video_engine_backend
call npm run build
if errorlevel 1 (popd & echo [ERROR] Backend build failed.& pause & exit /b 1)
popd

echo.
echo ========================================================
echo [1] Launch Web Edition (Local Browser http://localhost:8080)
echo [2] Launch Desktop Edition (Electron Standalone App)
echo ========================================================
set /p choice="Enter your choice [1 or 2] (Default 1): "

if "%choice%"=="2" (
    echo [*] Starting Electron Desktop Application...
    if not exist node_modules\electron (
        echo [*] Installing Electron...
        if exist package-lock.json (call npm ci) else (call npm install)
        if errorlevel 1 (echo [ERROR] Desktop dependencies could not be installed.& pause & exit /b 1)
    )
    call node --env-file=.env node_modules\electron\cli.js .
) else (
    echo [*] Starting MK School Web Server...
    call start-web.bat
)

pause

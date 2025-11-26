@echo off
REM LLM Council - Check Status for Current Instance (Windows)

cd /d "%~dp0"

REM Load configuration from .env
set INSTANCE_NAME=council
set BACKEND_PORT=8001
set FRONTEND_PORT=5173
set REDIS_PORT=6380
set ALLOWED_HOSTS=localhost
for /f "tokens=2 delims==" %%a in ('findstr /r "^INSTANCE_NAME=" .env 2^>nul') do set INSTANCE_NAME=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "^BACKEND_PORT=" .env 2^>nul') do set BACKEND_PORT=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "^FRONTEND_PORT=" .env 2^>nul') do set FRONTEND_PORT=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "^REDIS_PORT=" .env 2^>nul') do set REDIS_PORT=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "^ALLOWED_HOSTS=" .env 2^>nul') do set ALLOWED_HOSTS=%%a

set REDIS_CONTAINER=llm-%INSTANCE_NAME%-redis
set PID_DIR=.pids\%INSTANCE_NAME%

echo LLM Council Status [%INSTANCE_NAME%]
echo ======================================
echo.

REM Check Frontend
set FRONTEND_STATUS=[91m✗ Frontend: Not running[0m
if exist "%PID_DIR%\frontend.pid" (
    set /p FRONTEND_PID=<"%PID_DIR%\frontend.pid"
    tasklist /fi "PID eq %FRONTEND_PID%" 2>nul | findstr %FRONTEND_PID% >nul
    if not errorlevel 1 (
        set FRONTEND_STATUS=[92m✓ Frontend: http://localhost:%FRONTEND_PORT%[0m
    )
)
echo %FRONTEND_STATUS%

REM Check Backend
set BACKEND_STATUS=[91m✗ Backend:  Not running[0m
if exist "%PID_DIR%\backend.pid" (
    set /p BACKEND_PID=<"%PID_DIR%\backend.pid"
    tasklist /fi "PID eq %BACKEND_PID%" 2>nul | findstr %BACKEND_PID% >nul
    if not errorlevel 1 (
        set BACKEND_STATUS=[92m✓ Backend:  http://localhost:%BACKEND_PORT%[0m
    )
)
echo %BACKEND_STATUS%

REM Check Redis
docker ps | findstr %REDIS_CONTAINER% >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [92m✓ Redis:    localhost:%REDIS_PORT% (container: %REDIS_CONTAINER%)[0m
) else (
    echo [91m✗ Redis:    Not running[0m
)

REM Check Worker
set WORKER_STATUS=[91m✗ Worker:   Not running[0m
if exist "%PID_DIR%\worker.pid" (
    set /p WORKER_PID=<"%PID_DIR%\worker.pid"
    tasklist /fi "PID eq %WORKER_PID%" 2>nul | findstr %WORKER_PID% >nul
    if not errorlevel 1 (
        set WORKER_STATUS=[92m✓ Worker:   queue: %INSTANCE_NAME%[0m
    )
)
echo %WORKER_STATUS%

echo.
echo Access URLs:
for %%h in (%ALLOWED_HOSTS%) do (
    echo   http://%%h:%FRONTEND_PORT%
)
echo.
pause

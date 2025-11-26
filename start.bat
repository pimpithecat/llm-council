@echo off
REM LLM Council - Start All Services (Windows)
REM Supports multiple instances via INSTANCE_NAME in .env

cd /d "%~dp0"

REM Check if .env exists
if not exist ".env" (
    echo [91mX .env file not found.[0m
    echo   Please run: setup.bat
    exit /b 1
)

REM Load configuration from .env
set INSTANCE_NAME=council
set BACKEND_PORT=8001
set FRONTEND_PORT=5173
set REDIS_PORT=6380
for /f "tokens=2 delims==" %%a in ('findstr /r "^INSTANCE_NAME=" .env 2^>nul') do set INSTANCE_NAME=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "^BACKEND_PORT=" .env 2^>nul') do set BACKEND_PORT=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "^FRONTEND_PORT=" .env 2^>nul') do set FRONTEND_PORT=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "^REDIS_PORT=" .env 2^>nul') do set REDIS_PORT=%%a

REM Derived names based on instance
set REDIS_CONTAINER=llm-%INSTANCE_NAME%-redis
set WORKER_QUEUE=%INSTANCE_NAME%
set PID_DIR=.pids\%INSTANCE_NAME%
set LOG_DIR=logs\%INSTANCE_NAME%

echo Starting LLM Council [%INSTANCE_NAME%]...
echo.

REM Check if virtual environment exists
if not exist ".venv" (
    echo [91mX Virtual environment not found.[0m
    echo   Please run: setup.bat
    exit /b 1
)

REM Check if Python dependencies are installed
.venv\Scripts\python -c "import fastapi" >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [91mX Python dependencies not installed.[0m
    echo   Please run: setup.bat
    exit /b 1
)

REM Check if frontend dependencies are installed
if not exist "frontend\node_modules" (
    echo [91mX Frontend dependencies not installed.[0m
    echo   Please run: setup.bat
    exit /b 1
)

REM Create directories for PIDs and logs
if not exist "%PID_DIR%" mkdir "%PID_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Sync frontend .env with root .env
echo VITE_BACKEND_PORT=%BACKEND_PORT%> frontend\.env

REM Check if Redis container exists and has correct port
set REDIS_NEEDS_RECREATE=0
docker ps -a --filter "name=^%REDIS_CONTAINER%$" --format "{{.Names}}" 2>nul | findstr %REDIS_CONTAINER% >nul 2>nul
if %ERRORLEVEL% equ 0 (
    REM Container exists, check port
    for /f "tokens=2 delims=:" %%p in ('docker port %REDIS_CONTAINER% 6379 2^>nul') do (
        if not "%%p"=="%REDIS_PORT%" (
            echo [93m! Redis container has wrong port. Recreating with port %REDIS_PORT%...[0m
            docker stop %REDIS_CONTAINER% >nul 2>nul
            docker rm %REDIS_CONTAINER% >nul 2>nul
            set REDIS_NEEDS_RECREATE=1
        )
    )
)

docker ps -a --filter "name=^%REDIS_CONTAINER%$" --format "{{.Names}}" 2>nul | findstr %REDIS_CONTAINER% >nul 2>nul
if %ERRORLEVEL% neq 0 set REDIS_NEEDS_RECREATE=1

if %REDIS_NEEDS_RECREATE% equ 1 (
    echo Creating Redis container [%REDIS_CONTAINER%] on port %REDIS_PORT%...
    docker run -d --name %REDIS_CONTAINER% -p %REDIS_PORT%:6379 --restart unless-stopped redis:7-alpine
    timeout /t 2 /nobreak >nul
) else (
    docker ps | findstr %REDIS_CONTAINER% >nul 2>nul
    if %ERRORLEVEL% neq 0 (
        echo Starting Redis container [%REDIS_CONTAINER%]...
        docker start %REDIS_CONTAINER% >nul 2>nul
        timeout /t 2 /nobreak >nul
    )
)

REM Start backend
echo Starting backend on http://localhost:%BACKEND_PORT%...
start "LLM Council Backend [%INSTANCE_NAME%]" /B .venv\Scripts\python -m backend.main > "%LOG_DIR%\backend.log" 2>&1
for /f "tokens=2" %%p in ('tasklist /fi "windowtitle eq LLM Council Backend [%INSTANCE_NAME%]" /fo list ^| findstr PID') do echo %%p > "%PID_DIR%\backend.pid"

timeout /t 2 /nobreak >nul

REM Start worker
echo Starting worker (queue: %WORKER_QUEUE%)...
start "LLM Council Worker [%INSTANCE_NAME%]" /B .venv\Scripts\python -m rq.cli worker %WORKER_QUEUE% --url redis://localhost:%REDIS_PORT% > "%LOG_DIR%\worker.log" 2>&1

timeout /t 2 /nobreak >nul

REM Start frontend
echo Starting frontend on http://localhost:%FRONTEND_PORT%...
cd frontend
start "LLM Council Frontend [%INSTANCE_NAME%]" /B cmd /c "npm run dev > ..\%LOG_DIR%\frontend.log 2>&1"
cd ..

REM Load ALLOWED_HOSTS for display
set ALLOWED_HOSTS=localhost
for /f "tokens=2 delims==" %%a in ('findstr /r "^ALLOWED_HOSTS=" .env 2^>nul') do set ALLOWED_HOSTS=%%a

echo.
echo [92m✓ LLM Council [%INSTANCE_NAME%] is running![0m
echo.
echo Services:
echo   Frontend: http://localhost:%FRONTEND_PORT%
echo   Backend:  http://localhost:%BACKEND_PORT%
echo   Redis:    localhost:%REDIS_PORT% (container: %REDIS_CONTAINER%)
echo   Worker:   queue: %WORKER_QUEUE%
echo.
echo Access URLs:
for %%h in (%ALLOWED_HOSTS%) do (
    echo   http://%%h:%FRONTEND_PORT%
)
echo.
echo Logs:
echo   type %LOG_DIR%\frontend.log
echo   type %LOG_DIR%\backend.log
echo   type %LOG_DIR%\worker.log
echo.
echo To stop: stop.bat
echo.

@echo off
REM LLM Council - Start All Services (Windows)

echo Starting LLM Council...
echo.

cd /d "%~dp0"

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

REM Check if .env exists
if not exist ".env" (
    echo [91mX .env file not found.[0m
    echo   Please run: setup.bat
    exit /b 1
)

REM Load ports from .env
set BACKEND_PORT=8001
set FRONTEND_PORT=5173
set REDIS_PORT=6380
for /f "tokens=2 delims==" %%a in ('findstr /r "^BACKEND_PORT=" .env 2^>nul') do set BACKEND_PORT=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "^FRONTEND_PORT=" .env 2^>nul') do set FRONTEND_PORT=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "^REDIS_PORT=" .env 2^>nul') do set REDIS_PORT=%%a

REM Sync frontend .env with root .env
echo VITE_BACKEND_PORT=%BACKEND_PORT%> frontend\.env

REM Check if Redis container is running
docker ps | findstr llm-council-redis >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [93m! Redis container not running. Starting...[0m
    docker start llm-council-redis >nul 2>nul
    if %ERRORLEVEL% neq 0 (
        docker run -d --name llm-council-redis -p %REDIS_PORT%:6379 --restart unless-stopped redis:7-alpine
    )
    timeout /t 2 /nobreak >nul
)

REM Start backend
echo Starting backend on http://localhost:%BACKEND_PORT%...
start "LLM Council Backend" /B .venv\Scripts\python -m backend.main > backend.log 2>&1

timeout /t 2 /nobreak >nul

REM Start worker
echo Starting worker...
start "LLM Council Worker" /B .venv\Scripts\python -m rq.cli worker council --url redis://localhost:%REDIS_PORT% > worker.log 2>&1

timeout /t 2 /nobreak >nul

REM Start frontend
echo Starting frontend on http://localhost:%FRONTEND_PORT%...
cd frontend
start "LLM Council Frontend" /B cmd /c "npm run dev > frontend.log 2>&1"
cd ..

echo.
echo [92m✓ LLM Council is running![0m
echo.
echo Services:
echo   Backend:  http://localhost:%BACKEND_PORT%
echo   Worker:   Running
echo   Frontend: http://localhost:%FRONTEND_PORT%
echo   Redis:    localhost:%REDIS_PORT% (Docker container)
echo.
echo Logs:
echo   Backend:  type backend.log
echo   Worker:   type worker.log
echo   Frontend: type frontend\frontend.log
echo.
echo To stop: stop.bat (or close the command windows)
echo.

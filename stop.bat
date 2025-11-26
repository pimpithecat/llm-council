@echo off
REM LLM Council - Stop Services for Current Instance (Windows)
REM Only stops services matching INSTANCE_NAME in .env

cd /d "%~dp0"

REM Load instance name from .env
set INSTANCE_NAME=council
for /f "tokens=2 delims==" %%a in ('findstr /r "^INSTANCE_NAME=" .env 2^>nul') do set INSTANCE_NAME=%%a

set REDIS_CONTAINER=llm-%INSTANCE_NAME%-redis

echo Stopping LLM Council [%INSTANCE_NAME%]...

REM Stop processes by window title
taskkill /FI "WINDOWTITLE eq LLM Council Backend [%INSTANCE_NAME%]*" /F >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [92m✓ Backend stopped[0m
) else (
    echo   Backend was not running
)

taskkill /FI "WINDOWTITLE eq LLM Council Worker [%INSTANCE_NAME%]*" /F >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [92m✓ Worker stopped[0m
) else (
    echo   Worker was not running
)

taskkill /FI "WINDOWTITLE eq LLM Council Frontend [%INSTANCE_NAME%]*" /F >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [92m✓ Frontend stopped[0m
) else (
    echo   Frontend was not running
)

REM Stop Redis container for this instance
docker ps | findstr %REDIS_CONTAINER% >nul 2>nul
if %ERRORLEVEL% equ 0 (
    docker stop %REDIS_CONTAINER% >nul 2>nul
    echo [92m✓ Redis stopped (container: %REDIS_CONTAINER%)[0m
) else (
    echo   Redis was not running
)

echo.
echo Instance [%INSTANCE_NAME%] stopped.
pause

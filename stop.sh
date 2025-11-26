#!/bin/bash

# LLM Council - Stop Services for Current Instance
# Only stops services matching INSTANCE_NAME in .env

cd "$(dirname "$0")"

# Load configuration from .env
INSTANCE_NAME="council"
BACKEND_PORT=8001
FRONTEND_PORT=5173
if [ -f ".env" ]; then
    INSTANCE_NAME=$(grep '^INSTANCE_NAME=' .env 2>/dev/null | cut -d'=' -f2)
    INSTANCE_NAME=${INSTANCE_NAME:-council}
    BACKEND_PORT=$(grep '^BACKEND_PORT=' .env 2>/dev/null | cut -d'=' -f2)
    BACKEND_PORT=${BACKEND_PORT:-8001}
    FRONTEND_PORT=$(grep '^FRONTEND_PORT=' .env 2>/dev/null | cut -d'=' -f2)
    FRONTEND_PORT=${FRONTEND_PORT:-5173}
fi

REDIS_CONTAINER="llm-${INSTANCE_NAME}-redis"
PID_DIR=".pids/${INSTANCE_NAME}"

echo "Stopping LLM Council [${INSTANCE_NAME}]..."

# Function to kill process and its children
kill_process_tree() {
    local PID=$1
    local NAME=$2
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        # Kill process group (includes children)
        kill -- -"$PID" 2>/dev/null || kill "$PID" 2>/dev/null
        sleep 0.5
        # Force kill if still running
        if kill -0 "$PID" 2>/dev/null; then
            kill -9 "$PID" 2>/dev/null
        fi
        echo "✓ $NAME stopped (PID: $PID)"
        return 0
    fi
    return 1
}

# Function to kill by port (fallback)
kill_by_port() {
    local PORT=$1
    local NAME=$2
    local PID=$(lsof -t -i:$PORT 2>/dev/null)
    if [ -n "$PID" ]; then
        kill $PID 2>/dev/null
        sleep 0.5
        kill -9 $PID 2>/dev/null
        echo "✓ $NAME stopped (port: $PORT)"
        return 0
    fi
    return 1
}

# Stop backend
STOPPED=0
if [ -f "${PID_DIR}/backend.pid" ]; then
    BACKEND_PID=$(cat "${PID_DIR}/backend.pid")
    kill_process_tree "$BACKEND_PID" "Backend" && STOPPED=1
    rm -f "${PID_DIR}/backend.pid"
fi
if [ $STOPPED -eq 0 ]; then
    kill_by_port "$BACKEND_PORT" "Backend" || echo "  Backend was not running"
fi

# Stop worker
STOPPED=0
if [ -f "${PID_DIR}/worker.pid" ]; then
    WORKER_PID=$(cat "${PID_DIR}/worker.pid")
    kill_process_tree "$WORKER_PID" "Worker" && STOPPED=1
    rm -f "${PID_DIR}/worker.pid"
fi
if [ $STOPPED -eq 0 ]; then
    echo "  Worker was not running"
fi

# Stop frontend (always use port-based killing for reliability)
rm -f "${PID_DIR}/frontend.pid"
kill_by_port "$FRONTEND_PORT" "Frontend" || echo "  Frontend was not running"

# Stop Redis container for this instance
if docker ps | grep -q "$REDIS_CONTAINER"; then
    docker stop "$REDIS_CONTAINER" > /dev/null 2>&1
    echo "✓ Redis stopped (container: $REDIS_CONTAINER)"
else
    echo "  Redis was not running"
fi

echo ""
echo "Instance [${INSTANCE_NAME}] stopped."

#!/bin/bash

# LLM Council - Check Status for Current Instance

cd "$(dirname "$0")"

# Load configuration from .env
INSTANCE_NAME="council"
BACKEND_PORT=8001
FRONTEND_PORT=5173
REDIS_PORT=6380

if [ -f ".env" ]; then
    INSTANCE_NAME=$(grep '^INSTANCE_NAME=' .env 2>/dev/null | cut -d'=' -f2)
    INSTANCE_NAME=${INSTANCE_NAME:-council}
    BACKEND_PORT=$(grep '^BACKEND_PORT=' .env 2>/dev/null | cut -d'=' -f2)
    BACKEND_PORT=${BACKEND_PORT:-8001}
    FRONTEND_PORT=$(grep '^FRONTEND_PORT=' .env 2>/dev/null | cut -d'=' -f2)
    FRONTEND_PORT=${FRONTEND_PORT:-5173}
    REDIS_PORT=$(grep '^REDIS_PORT=' .env 2>/dev/null | cut -d'=' -f2)
    REDIS_PORT=${REDIS_PORT:-6380}
fi

REDIS_CONTAINER="llm-${INSTANCE_NAME}-redis"
PID_DIR=".pids/${INSTANCE_NAME}"

echo "LLM Council Status [${INSTANCE_NAME}]"
echo "======================================"
echo ""

# Check Frontend
if [ -f "${PID_DIR}/frontend.pid" ]; then
    FRONTEND_PID=$(cat "${PID_DIR}/frontend.pid")
    if kill -0 "$FRONTEND_PID" 2>/dev/null; then
        echo "✓ Frontend: http://localhost:${FRONTEND_PORT} (PID: $FRONTEND_PID)"
    else
        echo "✗ Frontend: Not running (stale PID file)"
    fi
else
    echo "✗ Frontend: Not running"
fi

# Check Backend
if [ -f "${PID_DIR}/backend.pid" ]; then
    BACKEND_PID=$(cat "${PID_DIR}/backend.pid")
    if kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "✓ Backend:  http://localhost:${BACKEND_PORT} (PID: $BACKEND_PID)"
    else
        echo "✗ Backend:  Not running (stale PID file)"
    fi
else
    echo "✗ Backend:  Not running"
fi

# Check Redis
if docker ps | grep -q "$REDIS_CONTAINER"; then
    echo "✓ Redis:    localhost:${REDIS_PORT} (container: $REDIS_CONTAINER)"
else
    echo "✗ Redis:    Not running"
fi

# Check Worker
if [ -f "${PID_DIR}/worker.pid" ]; then
    WORKER_PID=$(cat "${PID_DIR}/worker.pid")
    if kill -0 "$WORKER_PID" 2>/dev/null; then
        echo "✓ Worker:   queue: ${INSTANCE_NAME} (PID: $WORKER_PID)"
    else
        echo "✗ Worker:   Not running (stale PID file)"
    fi
else
    echo "✗ Worker:   Not running"
fi

# Load ALLOWED_HOSTS for display
ALLOWED_HOSTS=$(grep '^ALLOWED_HOSTS=' .env 2>/dev/null | cut -d'=' -f2)
ALLOWED_HOSTS=${ALLOWED_HOSTS:-localhost}

echo ""
echo "Access URLs:"
IFS=',' read -ra HOSTS <<< "$ALLOWED_HOSTS"
for host in "${HOSTS[@]}"; do
    host=$(echo "$host" | xargs)
    if [ -n "$host" ]; then
        echo "  http://${host}:${FRONTEND_PORT}"
    fi
done

#!/bin/bash

# LLM Council - Check Status

echo "LLM Council Status"
echo "=================="
echo ""

cd "$(dirname "$0")"

# Load ports from .env
BACKEND_PORT=8001
FRONTEND_PORT=5173
REDIS_PORT=6380
if [ -f ".env" ]; then
    BACKEND_PORT=$(grep '^BACKEND_PORT=' .env 2>/dev/null | cut -d'=' -f2)
    BACKEND_PORT=${BACKEND_PORT:-8001}
    FRONTEND_PORT=$(grep '^FRONTEND_PORT=' .env 2>/dev/null | cut -d'=' -f2)
    FRONTEND_PORT=${FRONTEND_PORT:-5173}
    REDIS_PORT=$(grep '^REDIS_PORT=' .env 2>/dev/null | cut -d'=' -f2)
    REDIS_PORT=${REDIS_PORT:-6380}
fi

# Check Redis
if docker ps | grep -q llm-council-redis; then
    echo "✓ Redis:    Running (port ${REDIS_PORT})"
else
    echo "✗ Redis:    Not running"
fi

# Check Backend
if pgrep -f "backend.main" > /dev/null; then
    BACKEND_PID=$(pgrep -f "backend.main" | head -1)
    echo "✓ Backend:  Running (PID: $BACKEND_PID, port ${BACKEND_PORT})"
else
    echo "✗ Backend:  Not running"
fi

# Check Worker (check for rq worker with council queue)
if pgrep -f "worker.*council" > /dev/null; then
    WORKER_PID=$(pgrep -f "worker.*council" | head -1)
    echo "✓ Worker:   Running (PID: $WORKER_PID)"
else
    echo "✗ Worker:   Not running"
fi

# Check Frontend
if pgrep -f "vite" > /dev/null; then
    FRONTEND_PID=$(pgrep -f "vite" | head -1)
    echo "✓ Frontend: Running (PID: $FRONTEND_PID, port ${FRONTEND_PORT})"
else
    echo "✗ Frontend: Not running"
fi

echo ""
echo "Access: http://localhost:${FRONTEND_PORT}"

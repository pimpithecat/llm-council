#!/bin/bash

# LLM Council - Start All Services (Background Mode)
# Supports multiple instances via INSTANCE_NAME in .env

cd "$(dirname "$0")"

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found."
    echo "   Please run: ./setup.sh"
    exit 1
fi

# Load configuration from .env
INSTANCE_NAME=$(grep '^INSTANCE_NAME=' .env 2>/dev/null | cut -d'=' -f2)
INSTANCE_NAME=${INSTANCE_NAME:-council}
BACKEND_PORT=$(grep '^BACKEND_PORT=' .env 2>/dev/null | cut -d'=' -f2)
BACKEND_PORT=${BACKEND_PORT:-8001}
FRONTEND_PORT=$(grep '^FRONTEND_PORT=' .env 2>/dev/null | cut -d'=' -f2)
FRONTEND_PORT=${FRONTEND_PORT:-5173}
REDIS_PORT=$(grep '^REDIS_PORT=' .env 2>/dev/null | cut -d'=' -f2)
REDIS_PORT=${REDIS_PORT:-6380}

# Derived names based on instance
REDIS_CONTAINER="llm-${INSTANCE_NAME}-redis"
WORKER_QUEUE="${INSTANCE_NAME}"
PID_DIR=".pids/${INSTANCE_NAME}"
LOG_DIR="logs/${INSTANCE_NAME}"

echo "Starting LLM Council [${INSTANCE_NAME}]..."
echo ""

# Check if virtual environment exists
if [ ! -d ".venv" ]; then
    echo "❌ Virtual environment not found."
    echo "   Please run: ./setup.sh"
    exit 1
fi

# Check if Python dependencies are installed in venv
if ! .venv/bin/python3 -c "import fastapi" &> /dev/null; then
    echo "❌ Python dependencies not installed."
    echo "   Please run: ./setup.sh"
    exit 1
fi

# Check if frontend dependencies are installed
if [ ! -d "frontend/node_modules" ]; then
    echo "❌ Frontend dependencies not installed."
    echo "   Please run: ./setup.sh"
    exit 1
fi

# Create directories for PIDs and logs
mkdir -p "$PID_DIR"
mkdir -p "$LOG_DIR"

# Sync frontend .env with root .env
echo "VITE_BACKEND_PORT=${BACKEND_PORT}" > frontend/.env

# Check if Redis container exists and has correct port
REDIS_CONTAINER_EXISTS=$(docker ps -a --filter "name=^${REDIS_CONTAINER}$" --format "{{.Names}}" 2>/dev/null)
REDIS_CURRENT_PORT=$(docker port "$REDIS_CONTAINER" 6379 2>/dev/null | cut -d':' -f2)

if [ -n "$REDIS_CONTAINER_EXISTS" ] && [ "$REDIS_CURRENT_PORT" != "$REDIS_PORT" ]; then
    echo "⚠️  Redis container has wrong port ($REDIS_CURRENT_PORT). Recreating with port $REDIS_PORT..."
    docker stop "$REDIS_CONTAINER" 2>/dev/null
    docker rm "$REDIS_CONTAINER" 2>/dev/null
    REDIS_CONTAINER_EXISTS=""
fi

if [ -z "$REDIS_CONTAINER_EXISTS" ]; then
    echo "Creating Redis container [${REDIS_CONTAINER}] on port $REDIS_PORT..."
    docker run -d --name "$REDIS_CONTAINER" -p ${REDIS_PORT}:6379 --restart unless-stopped redis:7-alpine
    sleep 2
elif ! docker ps | grep -q "$REDIS_CONTAINER"; then
    echo "Starting Redis container [${REDIS_CONTAINER}]..."
    docker start "$REDIS_CONTAINER"
    sleep 2
fi

# Start backend
echo "Starting backend..."
if command -v uv &> /dev/null; then
    nohup uv run python -m backend.main > "${LOG_DIR}/backend.log" 2>&1 &
else
    nohup .venv/bin/python3 -m backend.main > "${LOG_DIR}/backend.log" 2>&1 &
fi
echo $! > "${PID_DIR}/backend.pid"
sleep 2

# Start worker
echo "Starting worker..."
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
if command -v uv &> /dev/null; then
    nohup uv run rq worker "$WORKER_QUEUE" --url redis://localhost:${REDIS_PORT} > "${LOG_DIR}/worker.log" 2>&1 &
else
    nohup .venv/bin/python3 -m rq.cli worker "$WORKER_QUEUE" --url redis://localhost:${REDIS_PORT} > "${LOG_DIR}/worker.log" 2>&1 &
fi
echo $! > "${PID_DIR}/worker.pid"
sleep 2

# Start frontend
echo "Starting frontend..."
cd frontend
nohup npm run dev > "../${LOG_DIR}/frontend.log" 2>&1 &
NPM_PID=$!
sleep 2
# Get the actual node/vite PID (child of npm)
VITE_PID=$(pgrep -P $NPM_PID -f "node" 2>/dev/null | head -1)
if [ -n "$VITE_PID" ]; then
    echo $VITE_PID > "../${PID_DIR}/frontend.pid"
else
    echo $NPM_PID > "../${PID_DIR}/frontend.pid"
fi
cd ..

# Read PIDs for display
BACKEND_PID=$(cat "${PID_DIR}/backend.pid" 2>/dev/null)
WORKER_PID=$(cat "${PID_DIR}/worker.pid" 2>/dev/null)
FRONTEND_PID=$(cat "${PID_DIR}/frontend.pid" 2>/dev/null)

# Load ALLOWED_HOSTS for display
ALLOWED_HOSTS=$(grep '^ALLOWED_HOSTS=' .env 2>/dev/null | cut -d'=' -f2)
ALLOWED_HOSTS=${ALLOWED_HOSTS:-localhost}

echo ""
echo "✓ LLM Council [${INSTANCE_NAME}] is running!"
echo ""
echo "Services:"
echo "  Frontend: http://localhost:${FRONTEND_PORT} (PID: $FRONTEND_PID)"
echo "  Backend:  http://localhost:${BACKEND_PORT} (PID: $BACKEND_PID)"
echo "  Redis:    localhost:${REDIS_PORT} (container: $REDIS_CONTAINER)"
echo "  Worker:   queue: $WORKER_QUEUE (PID: $WORKER_PID)"
echo ""
echo "Access URLs:"
IFS=',' read -ra HOSTS <<< "$ALLOWED_HOSTS"
for host in "${HOSTS[@]}"; do
    host=$(echo "$host" | xargs)  # trim whitespace
    if [ -n "$host" ]; then
        echo "  http://${host}:${FRONTEND_PORT}"
    fi
done
echo ""
echo "Logs:"
echo "  tail -f ${LOG_DIR}/frontend.log"
echo "  tail -f ${LOG_DIR}/backend.log"
echo "  tail -f ${LOG_DIR}/worker.log"
echo ""
echo "To stop: ./stop.sh"

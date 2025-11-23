#!/bin/bash

# LLM Council - Start All Services (Background Mode)

echo "Starting LLM Council in background mode..."
echo ""

cd "$(dirname "$0")"

# Check if Redis container is running
if ! docker ps | grep -q llm-council-redis; then
    echo "⚠️  Redis container not running. Starting..."
    docker start llm-council-redis 2>/dev/null || \
    docker run -d --name llm-council-redis -p 6380:6379 --restart unless-stopped redis:7-alpine
    sleep 2
fi

# Start backend
echo "Starting backend..."
nohup ~/.local/bin/uv run python -m backend.main > backend.log 2>&1 &
BACKEND_PID=$!
sleep 2

# Start worker
echo "Starting worker..."
nohup ~/.local/bin/uv run rq worker council --url redis://localhost:6380 > worker.log 2>&1 &
WORKER_PID=$!
sleep 2

# Start frontend
echo "Starting frontend..."
cd frontend
nohup npm run dev > frontend.log 2>&1 &
FRONTEND_PID=$!
cd ..

echo ""
echo "✓ LLM Council is running in background!"
echo ""
echo "Services:"
echo "  Backend:  http://192.168.2.105:8001 (PID: $BACKEND_PID)"
echo "  Worker:   Running (PID: $WORKER_PID)"
echo "  Frontend: http://192.168.2.105:5173 (PID: $FRONTEND_PID)"
echo "  Redis:    localhost:6380 (Docker container)"
echo ""
echo "Logs:"
echo "  Backend:  tail -f backend.log"
echo "  Worker:   tail -f worker.log"
echo "  Frontend: tail -f frontend/frontend.log"
echo ""
echo "To stop: ./stop.sh"

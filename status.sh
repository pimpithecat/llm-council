#!/bin/bash

# LLM Council - Check Status

echo "LLM Council Status"
echo "=================="
echo ""

# Check Redis
if docker ps | grep -q llm-council-redis; then
    echo "✓ Redis:    Running (port 6380)"
else
    echo "✗ Redis:    Not running"
fi

# Check Backend
if pgrep -f "python -m backend.main" > /dev/null; then
    BACKEND_PID=$(pgrep -f "python -m backend.main")
    echo "✓ Backend:  Running (PID: $BACKEND_PID, port 8001)"
else
    echo "✗ Backend:  Not running"
fi

# Check Worker
if pgrep -f "rq worker" > /dev/null; then
    WORKER_PID=$(pgrep -f "rq worker")
    echo "✓ Worker:   Running (PID: $WORKER_PID)"
else
    echo "✗ Worker:   Not running"
fi

# Check Frontend
if pgrep -f "vite" > /dev/null; then
    FRONTEND_PID=$(pgrep -f "vite")
    echo "✓ Frontend: Running (PID: $FRONTEND_PID, port 5173)"
else
    echo "✗ Frontend: Not running"
fi

echo ""
echo "Access: http://192.168.2.105:5173"

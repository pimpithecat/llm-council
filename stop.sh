#!/bin/bash

# LLM Council - Stop All Services

echo "Stopping LLM Council services..."

# Stop backend
pkill -f "python -m backend.main" && echo "✓ Backend stopped"

# Stop worker
pkill -f "rq worker" && echo "✓ Worker stopped"

# Stop frontend
pkill -f "vite" && echo "✓ Frontend stopped"

echo ""
echo "All services stopped."
echo ""
echo "Note: Redis container is still running."
echo "To stop Redis: docker stop llm-council-redis"

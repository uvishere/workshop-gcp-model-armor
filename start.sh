#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"

# Kill any old server on port 8080
lsof -ti:8080 | xargs kill -9 2>/dev/null || true

# Load env vars from app/.env
set -a
# shellcheck source=/dev/null
source "$DIR/app/.env"
set +a

# Start app server in background, log to /tmp/server.log
npm --prefix "$DIR/app" start > /tmp/server.log 2>&1 &
SERVER_PID=$!

# Wait for server to be ready (up to 10s)
echo "Starting server..."
for i in $(seq 1 20); do
  if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅  Server ready (pid $SERVER_PID)"
    break
  fi
  sleep 0.5
done

# Open the presentation
echo "🎬  Opening presentation..."
open "$DIR/presentation.html"

echo ""
echo "Press Ctrl+C to stop the server when done."
wait $SERVER_PID

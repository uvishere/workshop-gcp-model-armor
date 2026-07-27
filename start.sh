#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"

# Kill any old proxy on port 3001
lsof -ti:3001 | xargs kill -9 2>/dev/null || true

# Load env vars from app/.env
set -a
# shellcheck source=/dev/null
source "$DIR/app/.env"
set +a

# Start proxy in background, log to /tmp/proxy.log
node "$DIR/proxy.js" > /tmp/proxy.log 2>&1 &
SERVER_PID=$!

# Wait for proxy to be ready (up to 10s)
echo "Starting proxy..."
for i in $(seq 1 20); do
  if curl -sf http://localhost:3001/health > /dev/null 2>&1; then
    echo "✅  Proxy ready (pid $SERVER_PID)"
    break
  fi
  sleep 0.5
done

# Open the presentation
echo "🎬  Opening presentation..."
open "$DIR/presentation.html"

echo ""
echo "Press Ctrl+C to stop the proxy when done."
wait $SERVER_PID

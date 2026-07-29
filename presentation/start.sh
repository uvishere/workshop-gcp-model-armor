#!/usr/bin/env bash
#
# Launcher for the workshop: starts the proxy, then opens the presentation.
#
# Runs on macOS, Linux, and Windows under Git Bash / WSL. The Windows path
# matters — the talk is presented from a Windows laptop.
#
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"   # presentation/
ROOT="$(cd "$DIR/.." && pwd)"          # repo root — app/ and setup-redaction.sh live here

# Git Bash, MSYS and Cygwin all report a Windows-ish uname.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
  Darwin)               PLATFORM=macos ;;
  *)                    PLATFORM=linux ;;
esac

# ── Kill any old proxy on port 3001 ────────────────────────────────────────
# lsof does not exist on Windows; use netstat + taskkill there. The // prefix
# on taskkill flags stops MSYS from mangling them into paths.
kill_stale() {
  if [ "$PLATFORM" = windows ]; then
    netstat -ano 2>/dev/null \
      | grep -i 'LISTENING' \
      | grep -E '[:.]3001[[:space:]]' \
      | awk '{print $NF}' | sort -u \
      | while read -r pid; do
          [ -n "$pid" ] && taskkill //PID "$pid" //F >/dev/null 2>&1 || true
        done
  else
    lsof -ti:3001 | xargs kill -9 2>/dev/null || true
  fi
}
kill_stale

# ── Load env vars from app/.env ────────────────────────────────────────────
if [ ! -f "$ROOT/app/.env" ]; then
  echo "❌ app/.env not found. Copy the settings from CLAUDE.md into it."
  exit 1
fi
set -a
# shellcheck source=/dev/null
source "$ROOT/app/.env"
set +a

# ── Preflight: fail here with a clear message, not mid-demo ────────────────
command -v node >/dev/null 2>&1 || {
  echo "❌ node not found on PATH. Install Node.js, then reopen this shell."
  exit 1
}
command -v gcloud >/dev/null 2>&1 || command -v gcloud.cmd >/dev/null 2>&1 || {
  echo "❌ gcloud not found on PATH. Install the Google Cloud CLI, then reopen this shell."
  exit 1
}
if ! gcloud auth print-access-token >/dev/null 2>&1; then
  echo "❌ gcloud has no valid access token."
  echo "   Run:  gcloud auth login"
  exit 1
fi

# ── Start the proxy ────────────────────────────────────────────────────────
LOG="${TMPDIR:-/tmp}/proxy.log"
node "$DIR/proxy.js" > "$LOG" 2>&1 &
SERVER_PID=$!

echo "Starting proxy..."
READY=no
for _ in $(seq 1 20); do
  if curl -sf http://localhost:3001/health > /dev/null 2>&1; then
    echo "✅  Proxy ready (pid $SERVER_PID)"
    READY=yes
    break
  fi
  sleep 0.5
done

if [ "$READY" = no ]; then
  echo "❌ Proxy did not come up. Last lines of $LOG:"
  tail -20 "$LOG" || true
  exit 1
fi

# Warn if the redaction demo will fall back to scripted content.
if curl -s http://localhost:3001/health | grep -q '"redactConfigured":false'; then
  echo "⚠️   MODEL_ARMOR_TEMPLATE_REDACT not set — slide 14 will use its scripted fallback."
  echo "    Run ../setup-redaction.sh to enable the live redaction demo."
fi

# ── Open the presentation ──────────────────────────────────────────────────
open_presentation() {
  local file="$1"
  case "$PLATFORM" in
    macos) open "$file" ;;
    linux) xdg-open "$file" ;;
    windows)
      # cmd needs a native Windows path, and // stops MSYS path mangling.
      if command -v cygpath >/dev/null 2>&1; then
        cmd //c start "" "$(cygpath -w "$file")"
      else
        cmd //c start "" "$file"
      fi
      ;;
  esac
}

echo "🎬  Opening presentation..."
if ! open_presentation "$DIR/presentation.html"; then
  echo "⚠️   Could not open a browser automatically."
  echo "    Open this file in Chrome manually:"
  echo "    $DIR/presentation.html"
fi

echo ""
echo "Press Ctrl+C to stop the proxy when done."
wait $SERVER_PID

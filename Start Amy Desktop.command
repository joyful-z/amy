#!/bin/zsh
set -u

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
DESKTOP_DIR="$PROJECT_DIR/desktop"
LOG_DIR="$PROJECT_DIR/tmp/logs"
HOST_LOG="$LOG_DIR/amy-host.log"

mkdir -p "$LOG_DIR"

port_open() {
  nc -z 127.0.0.1 "$1" >/dev/null 2>&1
}

wait_for_port() {
  local port="$1"
  local name="$2"
  local retries=60
  local count=0
  while ! port_open "$port"; do
    count=$((count + 1))
    if [ "$count" -ge "$retries" ]; then
      echo "$name did not start on port $port."
      return 1
    fi
    sleep 1
  done
  return 0
}

echo "Starting Amy Desktop..."
echo "Project: $PROJECT_DIR"
echo ""

STARTED_BACKEND_PID=""

if port_open 8000; then
  echo "Amy Host is already running on 127.0.0.1:8000."
else
  echo "Starting Amy Host on 127.0.0.1:8000..."
  (
    cd "$BACKEND_DIR" || exit 1
    if [ -f ".venv/bin/activate" ]; then
      source ".venv/bin/activate"
    fi
    python -m app.server >"$HOST_LOG" 2>&1
  ) &
  STARTED_BACKEND_PID="$!"

  if ! wait_for_port 8000 "Amy Host"; then
    echo ""
    echo "Amy Host log:"
    tail -n 80 "$HOST_LOG"
    exit 1
  fi
  echo "Amy Host started. Log: $HOST_LOG"
fi

echo "Starting Electron desktop..."
echo "Close this terminal window to stop the desktop dev process."
echo ""

cd "$DESKTOP_DIR" || exit 1
if port_open 5173; then
  echo "Vite is already running on 127.0.0.1:5173."
  echo "Opening Electron against the existing frontend..."
  npm run electron
else
  echo "Starting Vite and Electron..."
  npm run electron:dev
fi
STATUS="$?"

if [ -n "$STARTED_BACKEND_PID" ]; then
  echo ""
  echo "Stopping Amy Host started by this launcher..."
  kill "$STARTED_BACKEND_PID" >/dev/null 2>&1 || true
fi

exit "$STATUS"

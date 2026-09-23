#!/bin/zsh
set -u

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
DESKTOP_DIR="$PROJECT_DIR/desktop"
LOG_DIR="$PROJECT_DIR/tmp/logs"
HOST_LOG="$LOG_DIR/amy-web-host.log"

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

local_ip() {
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "YOUR_SERVER_IP"
}

echo "Starting Amy Web..."
echo "Project: $PROJECT_DIR"
echo ""

STARTED_BACKEND_PID=""

if port_open 8000; then
  echo "Amy Host is already running on port 8000."
else
  echo "Starting Amy Host on 0.0.0.0:8000..."
  (
    cd "$BACKEND_DIR" || exit 1
    if [ -f ".venv/bin/activate" ]; then
      source ".venv/bin/activate"
    fi
    python -m app.server --host 0.0.0.0 --port 8000 >"$HOST_LOG" 2>&1
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

IP="$(local_ip)"
echo ""
echo "Amy Web is available on this machine:"
echo "  http://127.0.0.1:5173"
echo ""
echo "Other devices on the same network can try:"
echo "  http://$IP:5173"
echo ""
echo "For internet access, deploy this project to a public server or expose these ports with a tunnel."
echo "Close this terminal window to stop the web dev process."
echo ""

cd "$DESKTOP_DIR" || exit 1
VITE_DEV_HOST=0.0.0.0 npm run dev
STATUS="$?"

if [ -n "$STARTED_BACKEND_PID" ]; then
  echo ""
  echo "Stopping Amy Host started by this launcher..."
  kill "$STARTED_BACKEND_PID" >/dev/null 2>&1 || true
fi

exit "$STATUS"

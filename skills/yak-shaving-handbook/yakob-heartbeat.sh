#!/usr/bin/env bash
# Yakob heartbeat: races fswatch against a 5-minute timeout.
# Returns on whichever fires first with a message for Yakob.

YAKS_DIR="${1:-.yaks}"
TIMEOUT="${2:-300}"

# Watch only agent-status files (not .state — Yakob writes those himself)
fswatch -1 --include '/agent-status$' --exclude '.*' -r "$YAKS_DIR" > /tmp/yakob-fswatch-hit.txt 2>/dev/null &
FSWATCH_PID=$!

# Start timeout
sleep "$TIMEOUT" &
SLEEP_PID=$!

# Race: wait for either to finish
while kill -0 "$FSWATCH_PID" 2>/dev/null && kill -0 "$SLEEP_PID" 2>/dev/null; do
  sleep 1
done

# Determine winner
if ! kill -0 "$FSWATCH_PID" 2>/dev/null; then
  # fswatch fired — a yak changed
  kill "$SLEEP_PID" 2>/dev/null
  wait "$SLEEP_PID" 2>/dev/null
  CHANGED_FILE=$(cat /tmp/yakob-fswatch-hit.txt 2>/dev/null)
  echo "=== YAK EVENT at $(date +%H:%M) ==="
  echo "Changed: $CHANGED_FILE"
  echo ""
  echo "A shaver updated a yak. Check agent-status and act if needed."
else
  # timeout fired — safety net
  kill "$FSWATCH_PID" 2>/dev/null
  wait "$FSWATCH_PID" 2>/dev/null
  echo "=== 5 MIN HEARTBEAT at $(date +%H:%M) ==="
  echo ""
  echo "No yak events in 5 minutes. Check on shaver statuses."
fi

echo ""
echo ">> Relaunch the heartbeat: run this script again in the background."

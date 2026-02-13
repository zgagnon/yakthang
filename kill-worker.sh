#!/usr/bin/env bash
set -euo pipefail

# kill-worker.sh - Stop a specific worker container
#
# Usage: kill-worker.sh <worker-name>
#
# Example: kill-worker.sh my-worker
#          (stops container named yak-worker-my-worker)

if [[ $# -ne 1 ]]; then
	echo "Usage: kill-worker.sh <worker-name>" >&2
	exit 1
fi

WORKER_NAME="$1"
CONTAINER_NAME="yak-worker-${WORKER_NAME}"

# Check if container exists
if ! docker ps -a --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
	echo "Error: Worker container '${CONTAINER_NAME}' not found" >&2
	echo "Available workers:" >&2
	docker ps -a --filter "name=yak-worker-" --format "  {{.Names}}" >&2
	exit 1
fi

# Stop the container (graceful with 10s timeout)
echo "Stopping worker: ${WORKER_NAME}"
docker stop -t 10 "${CONTAINER_NAME}"

echo "Worker stopped: ${WORKER_NAME}"
echo "Container preserved. Use cleanup-workers.sh to remove stopped containers."

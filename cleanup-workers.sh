#!/usr/bin/env bash
set -euo pipefail

# cleanup-workers.sh - Remove stopped worker containers
#
# Usage: cleanup-workers.sh [--all]
#
# Without --all: Removes only stopped (exited) worker containers
# With --all: Removes ALL worker containers (including running - use with caution)

REMOVE_ALL=false

if [[ $# -gt 0 && "$1" == "--all" ]]; then
	REMOVE_ALL=true
fi

if [[ "$REMOVE_ALL" == "true" ]]; then
	echo "WARNING: This will remove ALL worker containers (including running ones)"
	read -p "Are you sure? (yes/no): " CONFIRM
	if [[ "$CONFIRM" != "yes" ]]; then
		echo "Aborted."
		exit 0
	fi

	echo "Removing all worker containers..."
	docker ps -a --filter "name=yak-worker-" --format "{{.Names}}" | while read -r container; do
		echo "  Removing: $container"
		docker rm -f "$container"
	done
else
	echo "Removing stopped worker containers..."
	docker ps -a --filter "name=yak-worker-" --filter "status=exited" --format "{{.Names}}" | while read -r container; do
		echo "  Removing: $container"
		docker rm "$container"
	done
fi

echo "Cleanup complete."
echo ""
echo "Remaining workers:"
docker ps -a --filter "name=yak-worker-" --format "  {{.Names}}\t{{.Status}}"

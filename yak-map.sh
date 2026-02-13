#!/usr/bin/env bash
set -euo pipefail

CLEAR='\033[2J\033[H'

while true; do
	buffer=$(yx ls --format '{name}{?assigned-to: [{assigned-to}]}')
	echo -ne "$CLEAR"
	printf '%s\n' "$buffer"
	sleep 2
done

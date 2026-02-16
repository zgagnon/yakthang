#!/usr/bin/env bash
set -euo pipefail

if zellij list-sessions 2>/dev/null | grep -q "yakthang"; then
	zellij attach yakthang --force-run-commands
else
	zellij -s yakthang -n orchestrator.kdl
fi

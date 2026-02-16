#!/usr/bin/env bash
set -euo pipefail

# cost-summary.sh - Unified cost reporting combining OpenClaw + OpenCode workers
# Usage: cost-summary.sh [--today|--week|--month|--all] [--append-csv]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKER_COSTS="${SCRIPT_DIR}/.worker-costs"
OPENCLAW_SCRIPT="${SCRIPT_DIR}/cost-openclaw.sh"
CSV_FILE="${SCRIPT_DIR}/.worker-costs/daily-totals.csv"

DAYS=""
APPEND_CSV=false

usage() {
    echo "Usage: $0 [--today|--week|--month|--all] [--append-csv]"
    echo "  --today    Show today's costs (default)"
    echo "  --week     Show last 7 days"
    echo "  --month    Show last 30 days"
    echo "  --all      Show all time"
    echo "  --append-csv  Append today's totals to CSV history"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --today) DAYS="1" ;;
        --week) DAYS="7" ;;
        --month) DAYS="30" ;;
        --all) DAYS="3650" ;;
        --append-csv) APPEND_CSV=true ;;
        -h|--help) usage ;;
        *) 
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                DAYS="$1"
            else
                usage
            fi
            ;;
    esac
    shift
done

if [[ -z "$DAYS" ]]; then
    DAYS="1"
fi

# Run OpenClaw cost script ONCE and capture all output
OPENCLAW_OUTPUT=$("${OPENCLAW_SCRIPT}" "$DAYS" 2>/dev/null || true)

# Extract data from cached output
openclaw_cost=$(echo "$OPENCLAW_OUTPUT" | grep "^Total:" | awk '{print $2}' | tr -d '$' || true)
[[ -z "$openclaw_cost" ]] && openclaw_cost="0"

# Count session types
sessions=$(echo "$OPENCLAW_OUTPUT" | grep -cE "^(Interactive|Cron|Slack|Heartbeat):" || true)
[[ -z "$sessions" ]] && sessions=0

# Header
DATE_STR=$(date +%Y-%m-%d)
echo "═══ Cost Report: ${DATE_STR} ═══"
echo ""

# OpenClaw costs
echo "OpenClaw (Orchestrator):"
printf "  Total:                   \$%.2f\n" "$openclaw_cost"

# Get breakdown from cached output
echo "$OPENCLAW_OUTPUT" | { grep -E "^(Interactive|Cron|Slack|Heartbeat):" || true; } | while read -r line; do
    printf "  %s\n" "$line"
done

echo ""

# OpenCode worker costs
echo "OpenCode (Workers):"
WORKER_SCRIPT="${SCRIPT_DIR}/cost-workers.sh"

if [[ -x "$WORKER_SCRIPT" ]]; then
    worker_output=$("$WORKER_SCRIPT" --days "$DAYS" --summary 2>/dev/null || true)
    echo "$worker_output" | grep -v "^$" | grep -v "Total:" || true

    total_worker_cost=$(echo "$worker_output" | grep "Total:" | awk '{print $2}' | tr -d '$')
    [[ -z "$total_worker_cost" ]] && total_worker_cost="0"
    worker_count=$(echo "$worker_output" | grep -cE '^\s+\S+:' | head -1 || true)
    worker_count=$((worker_count - 1))
    [[ $worker_count -lt 0 ]] && worker_count=0
else
    echo "  (cost-workers.sh not found)"
    total_worker_cost=0
    worker_count=0
fi

echo ""

# Grand total
grand_total=$(awk -v oc="$openclaw_cost" -v wc="$total_worker_cost" 'BEGIN {print oc + wc}')
printf "                          Total: \$%.2f\n" "$grand_total"

# Model breakdown from cached output
echo ""
echo "Models:"
echo "$OPENCLAW_OUTPUT" | sed -n '/^By Model:/,/^[A-Z]/p' | { grep -v "^By Model:" | grep -v "^[A-Z]" | grep -v "^$" | head -5 || true; }

# Append to CSV if requested
if [[ "$APPEND_CSV" == "true" ]]; then
    mkdir -p "$(dirname "$CSV_FILE")"
    if [[ ! -f "$CSV_FILE" ]]; then
        echo "date,openclaw_cost,opencode_cost,total_cost,sessions,workers" > "$CSV_FILE"
    fi
    
    echo "${DATE_STR},${openclaw_cost},${total_worker_cost},${grand_total},${sessions},${worker_count}" >> "$CSV_FILE"
    echo "" 
    echo "Appended to $CSV_FILE"
fi

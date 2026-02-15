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
        --today) DAYS="--today" ;;
        --week) DAYS="--week" ;;
        --month) DAYS="--month" ;;
        --all) DAYS="--all" ;;
        --append-csv) APPEND_CSV=true ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
    shift
done

if [[ -z "$DAYS" ]]; then
    DAYS="--today"
fi

# Header
DATE_STR=$(date +%Y-%m-%d)
echo "═══ Cost Report: ${DATE_STR} ═══"
echo ""

# OpenClaw costs
echo "OpenClaw (Orchestrator):"
openclaw_cost=$(${OPENCLAW_SCRIPT} "$DAYS" 2>/dev/null | grep "^Total:" | awk '{print $2}' | tr -d '$')
if [[ -z "$openclaw_cost" ]]; then
    openclaw_cost="0"
fi
printf "  Total:                   \$%.2f\n" "$openclaw_cost"

# Get breakdown from OpenClaw
openclaw_breakdown=$(${OPENCLAW_SCRIPT} "$DAYS" 2>/dev/null | grep -E "^(Interactive|Cron|Slack|Heartbeat):" || true)
if [[ -n "$openclaw_breakdown" ]]; then
    echo "$openclaw_breakdown" | while read -r line; do
        printf "  %s\n" "$line"
    done
fi

echo ""

# OpenCode worker costs
echo "OpenCode (Workers):"
if [[ -d "$WORKER_COSTS" ]]; then
    # Parse worker exports
    declare -A worker_costs
    
    for json_file in "${WORKER_COSTS}"/*.json; do
        [[ -f "$json_file" ]] || continue
        
        # Extract worker name from filename (e.g., Yakriel-20260214T123456Z.json)
        worker=$(basename "$json_file" | cut -d'-' -f1)
        
        # Sum costs from session export - find all "cost": number patterns
        cost=$(grep -oP '"cost":\s*\K[0-9.]+' "$json_file" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        
        worker_costs["$worker"]=$(awk "BEGIN {print ${worker_costs[$worker]:-0} + $cost}" 2>/dev/null || echo "0")
    done
    
    total_worker_cost=0
    for worker in "${!worker_costs[@]}"; do
        cost="${worker_costs[$worker]}"
        total_worker_cost=$(awk "BEGIN {print $total_worker_cost + $cost}" 2>/dev/null || echo "$total_worker_cost")
        printf "  %-20s \$%.2f\n" "$worker:" "$cost"
    done
    
    if [[ -z "${worker_costs[@]}" ]]; then
        echo "  (no worker runs in period)"
        total_worker_cost=0
    fi
else
    echo "  (no cost data captured yet)"
    total_worker_cost=0
fi

echo ""

# Grand total
grand_total=$(awk -v oc="$openclaw_cost" -v wc="$total_worker_cost" 'BEGIN {print oc + wc}')
printf "                          Total: \$%.2f\n" "$grand_total"

# Model breakdown (combine both sources if available)
echo ""
echo "Models:"

# OpenClaw models
if [[ -x "$OPENCLAW_SCRIPT" ]]; then
    openclaw_models=$(${OPENCLAW_SCRIPT} "$DAYS" 2>/dev/null | grep -A 20 "By Model:" || true)
    if [[ -n "$openclaw_models" ]]; then
        echo "$openclaw_models" | grep -v "^$" | head -5
    fi
fi

# Append to CSV if requested
if [[ "$APPEND_CSV" == "true" ]]; then
    mkdir -p "$(dirname "$CSV_FILE")"
    if [[ ! -f "$CSV_FILE" ]]; then
        echo "date,openclaw_cost,opencode_cost,total_cost,sessions,workers" > "$CSV_FILE"
    fi
    
    # Count sessions and workers
    sessions=$(${OPENCLAW_SCRIPT} "$DAYS" 2>/dev/null | grep -c "Interactive\|Cron\|Slack\|Heartbeat" || true)
    [[ -z "$sessions" ]] && sessions=0
    workers=$(find "$WORKER_COSTS" -name "*.json" -mtime 0 2>/dev/null | wc -l)
    [[ -z "$workers" ]] && workers=0
    
    echo "${DATE_STR},${openclaw_cost},${total_worker_cost},${grand_total},${sessions},${workers}" >> "$CSV_FILE"
    echo "" 
    echo "Appended to $CSV_FILE"
fi

#!/usr/bin/env bash
set -euo pipefail

# cost-openclaw.sh - Extract cost data from OpenClaw Gateway (PERFORMANT VERSION)
# Parses JSONL transcripts efficiently using single jq queries per file

OPENCLAW_SESSIONS="${HOME}/.openclaw/agents/main/sessions"
DAYS="${1:-1}"

# Pricing model (per 1M tokens) - used when cost not in transcript
declare -A PRICING=(
    [claude-opus-4-5]="15.00 75.00 0.60 0.30"
    [claude-opus-4-6]="15.00 75.00 0.60 0.30"
    [claude-sonnet-4-5]="3.00 15.00 0.30 0.15"
    [claude-sonnet-4-4]="3.00 15.00 0.30 0.15"
    [claude-haiku-4-5]="0.80 4.00 0.10 0.05"
    [claude-haiku-4-4]="0.80 4.00 0.10 0.05"
)

usage() {
    echo "Usage: $0 [--today|--week|--month|--all] [days]"
    echo "  --today   Show today's costs (default)"
    echo "  --week    Show last 7 days"
    echo "  --month   Show last 30 days"
    echo "  --all     Show all time"
    echo "  days      Custom number of days (default: 1)"
    exit 1
}

case "${1:-}" in
    --today) DAYS=1 ;;
    --week) DAYS=7 ;;
    --month) DAYS=30 ;;
    --all) DAYS=3650 ;;
    -h|--help) usage ;;
    ''|[0-9]*) ;;  # Accept empty or numeric as days
    *) usage ;;
esac

# Calculate cutoff timestamp
CUTOFF=$(date -d "${DAYS} days ago" +%s 2>/dev/null || date -v-${DAYS}d +%s)

# Session type classification
classify_session() {
    local key="$1"
    case "$key" in
        *cron*) echo "cron" ;;
        *slack*) echo "slack" ;;
        *heartbeat*) echo "heartbeat" ;;
        *) echo "interactive" ;;
    esac
}

# Compute cost from usage when not directly available
compute_cost() {
    local input="$1" output="$2" cache_read="$3" cache_write="$4" model="$5"
    
    if [[ -v "PRICING[$model]" ]]; then
        read -r i o c_r c_w <<< "${PRICING[$model]}"
        awk "BEGIN { 
            input_c = $input * $i / 1000000;
            output_c = $output * $o / 1000000;
            cache_r_c = $cache_read * $c_r / 1000000;
            cache_w_c = $cache_write * $c_w / 1000000;
            printf \"%.6f\", input_c + output_c + cache_r_c + cache_w_c
        }"
    else
        echo "0"
    fi
}

# Temp file for accumulating results
TEMP_RESULTS=$(mktemp)
trap 'rm -f "$TEMP_RESULTS"' EXIT

# Process sessions.json to get file mappings
if [[ ! -f "${OPENCLAW_SESSIONS}/sessions.json" ]]; then
    echo "No sessions.json found"
    exit 0
fi

# Build array of session_key -> session_file, filter by date, extract costs
while IFS=$'\t' read -r key session_file; do
    [[ -z "$key" || -z "$session_file" ]] && continue
    [[ ! -f "$session_file" ]] && continue
    
    # Get timestamp from first line
    first_line=$(head -1 "$session_file" 2>/dev/null)
    [[ -z "$first_line" ]] && continue
    
    session_time=$(echo "$first_line" | jq -r '.timestamp // empty' 2>/dev/null | sed 's/Z//' | sed 's/T/ /')
    [[ -z "$session_time" ]] && continue
    
    session_ts=$(date -d "$session_time" +%s 2>/dev/null || date -jf "%Y-%m-%d %H:%M:%S" "$session_time" +%s 2>/dev/null || continue)
    [[ "$session_ts" -lt "$CUTOFF" ]] && continue
    
    type=$(classify_session "$key")
    
    # Extract all assistant message costs in ONE jq query per file
    # Output format: type|model|cost
    jq -r --arg type "$type" '
        . as $root |
        select($root.message.role == "assistant") |
        (
            ($root.message.usage.cost.total // "0") as $cost |
            ($root.message.model // "unknown") as $model |
            ($root.message.usage.input // "0") as $input |
            ($root.message.usage.output // "0") as $output |
            ($root.message.usage.cacheRead // "0") as $cache_r |
            ($root.message.usage.cacheWrite // "0") as $cache_w |
            if $cost == "null" or $cost == "0" then
                "NEED_COMPUTE|\($type)|\($model)|\($input)|\($output)|\($cache_r)|\($cache_w)"
            else
                "DONE|\($type)|\($model)|\($cost)"
            end
        )
    ' "$session_file" 2>/dev/null | while IFS='|' read -r status type model a b c d; do
        if [[ "$status" == "NEED_COMPUTE" ]]; then
            cost=$(compute_cost "$a" "$b" "$c" "$d" "$model")
            echo "$type|$model|$cost" >> "$TEMP_RESULTS"
        else
            echo "$type|$model|$a" >> "$TEMP_RESULTS"
        fi
    done
    
done < <(jq -r 'to_entries[] | [.key, .value.sessionFile] | @tsv' "${OPENCLAW_SESSIONS}/sessions.json" 2>/dev/null)

# Aggregate results from temp file
declare -A type_costs
declare -A model_costs
total_cost=0

while IFS='|' read -r type model cost; do
    [[ -z "$type" || -z "$cost" ]] && continue
    
    # Accumulate
    type_costs["$type"]=$(awk "BEGIN {print ${type_costs[$type]:-0} + $cost}")
    model_costs["$model"]=$(awk "BEGIN {print ${model_costs[$model]:-0} + $cost}")
    total_cost=$(awk "BEGIN {print $total_cost + $cost}")
done < "$TEMP_RESULTS"

# Output results
echo "OpenClaw Cost Report (last ${DAYS} day(s))"
echo "============================================="
echo ""

for type in interactive cron slack heartbeat; do
    cost="${type_costs[$type]:-0}"
    if awk "BEGIN {exit !($cost > 0.001)}"; then
        printf "%-20s \$%.2f\n" "${type^}:" "$cost"
    fi
done

echo ""
printf "%-20s \$%.2f\n" "Total:" "$total_cost"
echo ""
echo "By Model:"
for model in "${!model_costs[@]}"; do
    cost="${model_costs[$model]}"
    # Skip zero-cost or delivery models
    if ! awk "BEGIN {exit !($cost > 0.001)}" || [[ "$model" == "delivery-mirror" ]]; then
        continue
    fi
    pct=$(awk "BEGIN {printf \"%.1f\", $cost * 100 / $total_cost}")
    printf "  %-20s \$%.2f (%s%%)\n" "$model:" "$cost" "$pct"
done

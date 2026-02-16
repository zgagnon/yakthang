#!/usr/bin/env bash
set -euo pipefail

# cost-workers.sh - Query worker costs directly from persistent home SQLite DBs
#
# Reads OpenCode's opencode.db from each worker's persistent home to compute
# token usage and estimated costs. Works regardless of container state — the DB
# persists in .yak-boxes/@home/{Persona}/.local/share/opencode/opencode.db
#
# Output: TSV lines of "persona\tmodel\tinput\toutput\tcache_read\tcache_write\tcost"
# Usage: cost-workers.sh [--days N] [--summary]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKER_HOMES="${SCRIPT_DIR}/.yak-boxes/@home"

DAYS=""
SUMMARY=false

# Pricing per 1M tokens (input output cache_read cache_write)
# These match the models used via github-copilot provider
declare -A PRICING=(
    [claude-opus-4-5]="15.00 75.00 0.60 0.30"
    [claude-opus-4-6]="15.00 75.00 0.60 0.30"
    [claude-opus-4.5]="15.00 75.00 0.60 0.30"
    [claude-opus-4.6]="15.00 75.00 0.60 0.30"
    [claude-sonnet-4-5]="3.00 15.00 0.30 0.15"
    [claude-sonnet-4-4]="3.00 15.00 0.30 0.15"
    [claude-sonnet-4.5]="3.00 15.00 0.30 0.15"
    [claude-sonnet-4.4]="3.00 15.00 0.30 0.15"
    [claude-haiku-4-5]="0.80 4.00 0.10 0.05"
    [claude-haiku-4-4]="0.80 4.00 0.10 0.05"
    [claude-haiku-4.5]="0.80 4.00 0.10 0.05"
    [claude-haiku-4.4]="0.80 4.00 0.10 0.05"
    [gemini-3-pro]="1.25 10.00 0.315 0.315"
    [gemini-2.5-pro]="1.25 10.00 0.315 0.315"
)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --days) DAYS="$2"; shift ;;
        --summary) SUMMARY=true ;;
        -h|--help)
            echo "Usage: $0 [--days N] [--summary]"
            echo "  --days N    Filter to last N days (default: all)"
            echo "  --summary   Show formatted summary instead of TSV"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

compute_cost() {
    local input="$1" output="$2" cache_read="$3" cache_write="$4" model="$5"
    # Normalize model name: replace dots with dashes for lookup
    local lookup="${model//./-}"
    if [[ -v "PRICING[$lookup]" ]]; then
        read -r i o c_r c_w <<< "${PRICING[$lookup]}"
        awk "BEGIN {
            printf \"%.6f\", ($input * $i + $output * $o + $cache_read * $c_r + $cache_write * $c_w) / 1000000
        }"
    elif [[ -v "PRICING[$model]" ]]; then
        read -r i o c_r c_w <<< "${PRICING[$model]}"
        awk "BEGIN {
            printf \"%.6f\", ($input * $i + $output * $o + $cache_read * $c_r + $cache_write * $c_w) / 1000000
        }"
    else
        echo "0"
    fi
}

if [[ ! -d "$WORKER_HOMES" ]]; then
    if [[ "$SUMMARY" == "true" ]]; then
        echo "  (no worker homes found)"
    fi
    exit 0
fi

# Build time filter for SQL
TIME_FILTER=""
if [[ -n "$DAYS" ]]; then
    CUTOFF_MS=$(( ($(date +%s) - DAYS * 86400) * 1000 ))
    TIME_FILTER="AND m.time_created >= $CUTOFF_MS"
fi

total_cost=0
worker_count=0

for persona_dir in "$WORKER_HOMES"/*/; do
    [[ -d "$persona_dir" ]] || continue
    persona=$(basename "$persona_dir")
    db_file="${persona_dir}.local/share/opencode/opencode.db"

    if [[ ! -f "$db_file" ]]; then
        continue
    fi

    abs_home="$(cd "$persona_dir" && pwd)"

    # Query token usage grouped by model, across all sessions
    query_result=$(HOME="$abs_home" opencode db \
        "SELECT
            json_extract(data, '$.modelID') as model,
            SUM(json_extract(data, '$.tokens.input')) as input_tokens,
            SUM(json_extract(data, '$.tokens.output')) as output_tokens,
            SUM(COALESCE(json_extract(data, '$.tokens.cache.read'), 0)) as cache_read,
            SUM(COALESCE(json_extract(data, '$.tokens.cache.write'), 0)) as cache_write
        FROM message m
        WHERE json_extract(data, '$.role') = 'assistant'
        $TIME_FILTER
        GROUP BY json_extract(data, '$.modelID')" \
        --format tsv 2>/dev/null || echo "")

    if [[ -z "$query_result" ]]; then
        continue
    fi

    persona_cost=0

    while IFS=$'\t' read -r model input output cache_read cache_write; do
        [[ -z "$model" || "$model" == "model" ]] && continue
        input=${input:-0}
        output=${output:-0}
        cache_read=${cache_read:-0}
        cache_write=${cache_write:-0}

        cost=$(compute_cost "$input" "$output" "$cache_read" "$cache_write" "$model")

        if [[ "$SUMMARY" != "true" ]]; then
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$persona" "$model" "$input" "$output" "$cache_read" "$cache_write" "$cost"
        fi

        persona_cost=$(awk "BEGIN {print $persona_cost + $cost}")
    done <<< "$query_result"

    if [[ "$SUMMARY" == "true" ]]; then
        printf "  %-20s \$%.2f\n" "$persona:" "$persona_cost"
    fi

    total_cost=$(awk "BEGIN {print $total_cost + $persona_cost}")
    worker_count=$((worker_count + 1))
done

if [[ "$SUMMARY" == "true" ]]; then
    if [[ $worker_count -eq 0 ]]; then
        echo "  (no worker data found)"
    fi
    echo ""
    printf "  %-20s \$%.2f\n" "Total:" "$total_cost"
fi

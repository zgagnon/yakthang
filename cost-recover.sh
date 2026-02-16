#!/usr/bin/env bash
set -euo pipefail

# cost-recover.sh - Extract cost data from worker persistent homes
#
# Workers store their OpenCode sessions in persistent home directories:
#   .yak-boxes/@home/{Persona}/.local/share/opencode/opencode.db
#
# This script reads those DBs from the host to recover cost data that
# would be lost if a container crashes or exits without running its
# cleanup hook. It's idempotent — already-exported sessions are skipped.
#
# Usage: cost-recover.sh [--verbose] [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKER_HOMES="${SCRIPT_DIR}/.yak-boxes/@home"
WORKER_COSTS="${SCRIPT_DIR}/.worker-costs"
EXPORTED_LOG="${WORKER_COSTS}/.exported-sessions"

VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v) VERBOSE=true ;;
        --dry-run|-n) DRY_RUN=true ;;
        -h|--help)
            echo "Usage: $0 [--verbose] [--dry-run]"
            echo "  --verbose   Show detailed progress"
            echo "  --dry-run   Show what would be exported without writing"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "$@" >&2
    fi
}

# Ensure output directories exist
if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$WORKER_COSTS"
    touch "$EXPORTED_LOG"
fi

# Check if a session has already been exported
is_exported() {
    local session_id="$1"
    if [[ ! -f "$EXPORTED_LOG" ]]; then
        return 1
    fi
    grep -qF "$session_id" "$EXPORTED_LOG" 2>/dev/null
}

# Mark a session as exported
mark_exported() {
    local session_id="$1" persona="$2"
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "${session_id}:${persona}" >> "$EXPORTED_LOG"
    fi
}

# Check for existing JSON exports that match a session ID
has_json_export() {
    local session_id="$1"
    # Check if any existing JSON file in .worker-costs/ contains this session ID
    for json_file in "${WORKER_COSTS}"/*.json; do
        [[ -f "$json_file" ]] || continue
        if head -5 "$json_file" | grep -qF "$session_id" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

recovered=0
skipped=0
failed=0

if [[ ! -d "$WORKER_HOMES" ]]; then
    log "No worker homes directory at $WORKER_HOMES"
    exit 0
fi

for persona_dir in "$WORKER_HOMES"/*/; do
    [[ -d "$persona_dir" ]] || continue
    persona=$(basename "$persona_dir")
    db_file="${persona_dir}.local/share/opencode/opencode.db"

    if [[ ! -f "$db_file" ]]; then
        log "  No opencode.db for $persona"
        continue
    fi

    log "Checking $persona..."

    # Get session list from the worker's DB
    # Use HOME override so opencode reads the worker's DB
    abs_home="$(cd "$persona_dir" && pwd)"
    session_list=$(HOME="$abs_home" opencode session list 2>/dev/null || true)

    if [[ -z "$session_list" ]]; then
        log "  No sessions for $persona"
        continue
    fi

    # Parse session IDs (skip header lines)
    while IFS= read -r line; do
        session_id=$(echo "$line" | awk '{print $1}')
        [[ -z "$session_id" ]] && continue
        [[ "$session_id" == "Session" ]] && continue
        [[ "$session_id" == "─"* ]] && continue
        # Must look like a session ID
        [[ "$session_id" == ses_* ]] || continue

        # Skip if already exported
        if is_exported "$session_id"; then
            log "  Skip $session_id (already in log)"
            skipped=$((skipped + 1))
            continue
        fi

        # Skip if JSON export already exists
        if has_json_export "$session_id"; then
            log "  Skip $session_id (JSON exists)"
            mark_exported "$session_id" "$persona"
            skipped=$((skipped + 1))
            continue
        fi

        # Get session creation time for the filename timestamp
        ts=$(HOME="$abs_home" opencode db \
            "SELECT time_created FROM session WHERE id = '$session_id'" \
            --format json 2>/dev/null \
            | grep -oP '"time_created":\s*\K[0-9]+' \
            | head -1 || echo "")

        if [[ -n "$ts" ]]; then
            # Convert epoch millis to timestamp string
            ts_seconds=$((ts / 1000))
            ts_str=$(date -u -d "@$ts_seconds" +%Y%m%dT%H%M%SZ 2>/dev/null || \
                     date -u -r "$ts_seconds" +%Y%m%dT%H%M%SZ 2>/dev/null || \
                     date -u +%Y%m%dT%H%M%SZ)
        else
            ts_str=$(date -u +%Y%m%dT%H%M%SZ)
        fi

        output_file="${WORKER_COSTS}/${persona}-${ts_str}.json"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "Would export: $persona $session_id -> $(basename "$output_file")"
            recovered=$((recovered + 1))
            continue
        fi

        log "  Exporting $session_id -> $(basename "$output_file")"

        # Export the session
        # opencode export prints "Exporting session: ..." to stderr, JSON to stdout
        export_output=$(HOME="$abs_home" opencode export "$session_id" 2>/dev/null || true)

        if [[ -n "$export_output" ]] && echo "$export_output" | head -1 | grep -q '^{'; then
            echo "$export_output" > "$output_file"
            mark_exported "$session_id" "$persona"
            recovered=$((recovered + 1))
            log "  OK: $(basename "$output_file")"
        else
            # Export failed — try to extract what we can from the DB directly
            log "  Export failed for $session_id, trying DB query..."
            db_output=$(HOME="$abs_home" opencode db \
                "SELECT json_object(
                    'session_id', '$session_id',
                    'persona', '$persona',
                    'recovered', 1,
                    'total_input', SUM(CASE WHEN json_extract(data, '$.role') = 'assistant' THEN json_extract(data, '$.tokens.input') ELSE 0 END),
                    'total_output', SUM(CASE WHEN json_extract(data, '$.role') = 'assistant' THEN json_extract(data, '$.tokens.output') ELSE 0 END),
                    'total_cache_read', SUM(CASE WHEN json_extract(data, '$.role') = 'assistant' THEN json_extract(data, '$.tokens.cache.read') ELSE 0 END),
                    'total_cache_write', SUM(CASE WHEN json_extract(data, '$.role') = 'assistant' THEN json_extract(data, '$.tokens.cache.write') ELSE 0 END),
                    'assistant_msgs', COUNT(CASE WHEN json_extract(data, '$.role') = 'assistant' THEN 1 END),
                    'models', GROUP_CONCAT(DISTINCT CASE WHEN json_extract(data, '$.role') = 'assistant' THEN json_extract(data, '$.modelID') END)
                ) FROM message WHERE session_id = '$session_id'" \
                --format json 2>/dev/null || echo "")

            if [[ -n "$db_output" ]]; then
                echo "$db_output" > "${output_file%.json}.recovered.json"
                mark_exported "$session_id" "$persona"
                recovered=$((recovered + 1))
                log "  OK (recovered from DB): $(basename "${output_file%.json}.recovered.json")"
            else
                failed=$((failed + 1))
                log "  FAILED: could not export $session_id"
            fi
        fi
    done <<< "$session_list"
done

if [[ "$VERBOSE" == "true" || $recovered -gt 0 ]]; then
    echo "Cost recovery: ${recovered} exported, ${skipped} skipped, ${failed} failed" >&2
fi

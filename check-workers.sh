#!/usr/bin/env bash
set -euo pipefail

# check-workers.sh - Show agent-status for all tasks that have one
#
# Used by the orchestrator to poll worker feedback.
# Reads the agent-status field from every task that has reported status.
#
# Usage:
#   check-workers.sh              Show all statuses
#   check-workers.sh --blocked    Show only blocked tasks
#   check-workers.sh --wip        Show only in-progress tasks
#   check-workers.sh <prefix>     Show statuses under a task prefix

YAK_PATH="${YAK_PATH:-.yaks}"
FILTER=""
PREFIX=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --blocked) FILTER="blocked"; shift ;;
        --wip)     FILTER="wip";     shift ;;
        *)         PREFIX="$1";      shift ;;
    esac
done

SEARCH_PATH="${YAK_PATH}"
if [[ -n "$PREFIX" ]]; then
    SEARCH_PATH="${YAK_PATH}/${PREFIX}"
fi

if [[ ! -d "$SEARCH_PATH" ]]; then
    echo "No tasks found under ${SEARCH_PATH}" >&2
    exit 1
fi

found=0
while IFS= read -r status_file; do
    # Get the task path relative to .yaks
    task_dir="$(dirname "$status_file")"
    task_name="${task_dir#"${YAK_PATH}"/}"

    status="$(cat "$status_file")"

    # Apply filter if set
    if [[ -n "$FILTER" ]]; then
        case "$status" in
            "${FILTER}"*) ;; # matches
            *) continue ;;   # skip
        esac
    fi

    printf "%-50s %s\n" "$task_name" "$status"
    found=1
done < <(find "$SEARCH_PATH" -name "agent-status" -type f 2>/dev/null | sort)

if [[ "$found" -eq 0 ]]; then
    if [[ -n "$FILTER" ]]; then
        echo "No tasks with status '${FILTER}' found."
    else
        echo "No tasks have reported agent-status yet."
    fi
fi

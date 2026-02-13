# Worker Feedback Protocol

## Overview

Workers report their status to the orchestrator via `yx field`. The
orchestrator monitors these fields to track progress, detect blocked workers,
and verify completion. This is a pull-based protocol — the orchestrator
polls rather than receiving push notifications.

## Status Field

Workers write to the `agent-status` field on their assigned task:

```bash
echo "<status>" | yx field <task-name> agent-status
```

### Status Prefixes

| Prefix | Meaning | Orchestrator Action |
|--------|---------|-------------------|
| `wip:` | Worker is actively working | None — let it run |
| `blocked:` | Worker is stuck and needs help | Read reason, unblock or reassign |
| `done:` | Worker finished | Verify summary, check task state |

### Examples

```bash
# Starting work
echo "wip: starting" | yx field auth/api agent-status

# Progress update
echo "wip: implementing JWT validation middleware" | yx field auth/api agent-status

# Blocked
echo "blocked: need database schema for user tokens" | yx field auth/api agent-status

# Plan ready (plan mode workers)
echo "blocked: plan ready for review" | yx field auth/api agent-status

# Completed
echo "done: JWT auth implemented with expiry check" | yx field auth/api agent-status
```

## Checking Status

### check-workers.sh

The primary monitoring tool. Scans `.yaks/` for `agent-status` fields and
displays them in a table.

```bash
# All statuses
./check-workers.sh

# Only blocked workers (needs immediate attention)
./check-workers.sh --blocked

# Only in-progress workers
./check-workers.sh --wip

# Scoped to a task subtree
./check-workers.sh auth/
```

Output format:
```
auth/api                                           wip: implementing JWT validation
auth/frontend                                      blocked: waiting for API spec
auth/integration                                   done: test suite passing
```

### Direct field read

For a single task:
```bash
yx field --show auth/api agent-status
```

## Status Lifecycle

Workers are expected to write `agent-status` at each transition:

```
spawn → wip: starting
      → wip: <progress updates>
      → done: <summary>        (success path)
      → blocked: <reason>      (needs help)
```

## Reacting to Blocked Workers

When a worker reports `blocked:`, the orchestrator should:

1. Read the reason: `yx field --show <task> agent-status`
2. Decide on action:
   - **Unblock**: Update task context with missing information, fix a
     dependency, or provide guidance
   - **Reassign**: Mark the task back to `todo` with `yx state <task> todo`
     and spawn a fresh worker
3. Workers are disposable — if one is hopelessly stuck, spawning a fresh
   worker is often faster than debugging the stuck one

## Storage

Status is stored as a plain text file in the task directory:
```
.yaks/auth/api/agent-status
```

The file contains the most recent status string (not a history). Each write
overwrites the previous status.

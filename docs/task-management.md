# Task Management with yx

## Overview

Yakthang uses `yx`, a DAG-based CLI task tracker, as its shared state layer.
Tasks are hierarchical paths stored in the `.yaks/` directory. Both the
orchestrator and workers read and write task state through the `yx` CLI.

## Task Structure

Tasks are identified by slash-separated paths that form a tree:

```
auth/
  api/
  frontend/
  integration/
```

Created with:
```bash
yx add auth/api
yx add auth/frontend
yx add auth/integration
```

The tree is visible via `yx ls`, which renders states with bullet markers:
- `○` — todo (pending)
- `●` (green/bold) — wip (in progress) or parent with active children
- `●` (grey/strikethrough) — done

## Task Lifecycle States

| State | Meaning | Set by |
|-------|---------|--------|
| `todo` | Not started (default) | `yx add` |
| `wip` | Work in progress | `yx state <name> wip` |
| `done` | Completed | `yx done <name>` |

## Task Context

Every task can have markdown context attached — the requirements, entry
points, constraints, and acceptance criteria that a worker needs.

**Writing context** (pipe via stdin to avoid interactive editor):
```bash
echo "Implement JWT auth for the API layer.
- Entry point: src/auth/handler.rs
- POST /login returns a signed JWT
- Middleware rejects expired tokens" | yx context auth/api
```

**Reading context**:
```bash
yx context --show auth/api
```

Context should be written by the orchestrator before a worker picks up the
task. It serves as the task's specification.

## Custom Fields

`yx field` stores arbitrary key-value data on tasks. Yakthang uses this for
worker status reporting (see [worker-feedback.md](worker-feedback.md)).

```bash
# Write a field (pipe via stdin)
echo "wip: implementing JWT validation" | yx field auth/api agent-status

# Read a field
yx field --show auth/api agent-status
```

Fields are stored as files in the task directory:
`.yaks/auth/api/agent-status`

## Storage

All task state lives in `.yaks/` at the workspace root:
```
.yaks/
  auth/
    context.md
    state
    api/
      context.md
      state
      agent-status
    frontend/
      context.md
      state
```

The `.yaks/` directory is gitignored — task state is ephemeral to a work
session, not committed to the repo.

## Orchestrator Workflow

1. **Plan** — Break work into yx tasks with `yx add`, write context for each
2. **Spawn** — Launch workers scoped to task subtrees
3. **Monitor** — Watch `yx ls` in the yak-map pane
4. **React** — Check `agent-status` fields, unblock stuck workers, spawn
   replacements if needed

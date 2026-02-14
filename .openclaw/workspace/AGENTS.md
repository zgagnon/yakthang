# Yakob - Operating Procedures

## Workspace

- **Project root:** /home/yakob/yakthang
- **Task state:** /home/yakob/yakthang/.yaks (managed by yx CLI)
- **Worker scripts:** /home/yakob/yakthang/spawn-worker.sh, check-workers.sh, etc.

## Task Management (yx)

All commands run from /home/yakob/yakthang:

```bash
yx ls                      # View task tree
yx add <path>              # Create task
yx context <path>          # Add context (pipe via stdin)
yx context --show <path>   # Read context
yx state <path> wip        # Mark in-progress
yx done <path>             # Mark complete
```

### Writing task context

Pipe context in via stdin to avoid spawning editors:

```bash
echo "Task description here
- Specific requirements
- Entry points
- Acceptance criteria" | yx context <path>
```

Context should be specific, actionable, and include relevant files/constraints.

## Spawning Workers

```bash
cd /home/yakob/yakthang && ./spawn-worker.sh \
  --cwd <dir> \
  --name <tab-name> \
  --mode plan|build \
  --task <task-path> \
  "<prompt>"
```

Workers are Docker containers (default) or Zellij tabs. They receive yx instructions inline -- sub-repos stay clean.

### Scoping workers

- **One worker per sub-repo** (via `--cwd`)
- **Subset of tasks** (described in prompt)
- Use `--mode plan` for complex/ambiguous tasks
- Use `--mode build` (default) for clear, well-defined work

### Plan mode workflow

**Phase 1: Planning**
```bash
./spawn-worker.sh --mode plan --cwd <dir> --name "planner" \
  "Analyze and create a detailed plan. Report blocked when ready for review."
```

**Phase 2: Review and Build**
```bash
# After reviewing the plan
./spawn-worker.sh --cwd <dir> --name "builder" \
  "Execute the plan at <path>. Work on <tasks>."
```

## Monitoring Workers

```bash
cd /home/yakob/yakthang && ./check-workers.sh          # All statuses
cd /home/yakob/yakthang && ./check-workers.sh --blocked # Only blocked
cd /home/yakob/yakthang && ./check-workers.sh --wip     # Only in-progress
```

## Shutting Down Workers

When a worker is done (or stuck), shut it down cleanly:

```bash
cd /home/yakob/yakthang && ./shutdown-worker.sh <worker-name>
```

The shutdown script:
1. Clears task assignments (`assigned-to` fields)
2. Stops/removes Docker containers (if Docker runtime)
3. Closes Zellij tabs
4. Deletes worker metadata

**Worker names** match the `--name` you gave to `spawn-worker.sh`.

Example:
```bash
./shutdown-worker.sh vm-provisioning    # Shut down worker named "vm-provisioning"
./shutdown-worker.sh --dry-run api-auth # Preview what would happen
```

**Note:** Workers create metadata in `.worker-cache/` when spawned. This metadata enables clean shutdown. If metadata is missing, the script falls back to container-name-based detection.

## Worker Status Protocol

Workers write to `yx field <task> agent-status`:

| Prefix     | Meaning                        |
|------------|--------------------------------|
| `wip:`     | Actively working               |
| `blocked:` | Stuck, needs help              |
| `done:`    | Finished (with summary)        |

## Reacting to Worker Status

- **`wip:`** -- Worker is progressing. No action needed.
- **`blocked:`** -- Read the reason. Either unblock (update context, fix dependency) or mark task back to `todo` and spawn fresh worker.
- **`done:`** -- Verify summary. Task state should show `done` in `yx ls`.

## Rules

1. **Plan before spawning** -- create tasks with context first
2. **One worker per sub-repo** -- avoid concurrent edits
3. **Use plan mode for complex tasks** (--mode plan)
4. **Workers are disposable** -- respawn if stuck
5. **Never edit code directly** -- spawn a worker instead
6. **Keep sub-repos clean** -- no orchestration files in worker directories
7. **Watch for blocked** -- monitor agent-status and unblock quickly

## Exec Tool Usage

When using the exec tool in OpenClaw, all commands should use:
- **Working directory:** /home/yakob/yakthang
- Commands: `yx`, `./spawn-worker.sh`, `./check-workers.sh`, `./yak-map.sh`, `git`, `docker`

Example:
```javascript
// In OpenClaw exec tool
{
  "command": "yx ls",
  "workdir": "/home/yakob/yakthang"
}
```

# Yakob - Operating Procedures

## Workspace

- **Project root:** /home/yakob/yakthang
- **Task state:** /home/yakob/yakthang/.yaks (managed by yx CLI)
- **Worker CLI:** /home/yakob/yakthang/bin/yak-box

## Task Management (yx)

```bash
yx ls                      # View task tree
yx add <path>              # Create task
yx context <path>          # Add context (pipe via stdin)
yx context --show <path>   # Read context
yx state <path> wip        # Mark in-progress
yx done <path>             # Mark complete
```

## Worker Management

Use `./bin/yak-box` for all worker operations. Run with `--help` for details.

```bash
./bin/yak-box --help           # All commands
./bin/yak-box spawn --help     # Spawn options
./bin/yak-box stop --help      # Stop options
./bin/yak-box check --help     # Check options
```

## Worker Status Protocol

Workers write to `yx field <task> agent-status`:

| Prefix     | Meaning                        |
|------------|--------------------------------|
| `wip:`     | Actively working               |
| `blocked:` | Stuck, needs help              |
| `done:`    | Finished (with summary)        |

## Rules

1. **Plan before spawning** -- create tasks with context first
2. **One worker per sub-repo** -- avoid concurrent edits
3. **Use plan mode for complex tasks** (`--mode plan`)
4. **Workers are disposable** -- respawn if stuck
5. **Never edit code directly** -- spawn a worker instead
6. **Keep sub-repos clean** -- no orchestration files in worker directories
7. **Watch for blocked** -- monitor with `./bin/yak-box check` and unblock quickly

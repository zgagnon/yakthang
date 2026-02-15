# yak-box Design

## Overview

yak-box is a Go CLI tool that replaces the current shell-based worker orchestration scripts with a single, well-structured binary. It provides commands for spawning, shutting down, checking, and killing sandboxed (container-based) workers.

## Goals

1. **Replace shell scripts** with a Go binary for better error handling, testability, and maintainability
2. **Single entry point**: `yak-box <command>` instead of multiple scripts
3. **Preserve existing behavior** — workers should behave identically to the shell script version
4. **Idempotent operations** — safe to run multiple times

## Commands

```
yak-box --help              # Show help
yak-box spawn [flags]       # Spawn a new worker
yak-box stop [flags]        # Stop a worker (graceful or force)
yak-box check [flags]       # Check worker/task status
```

## Spawn Command

```bash
yak-box spawn --cwd <dir> --name <tab-name> [flags] "<prompt>"
```

### Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--cwd` | Yes | — | Working directory for the worker |
| `--name` | Yes | — | Worker name (used in logs, metadata) |
| `--mode` | No | `build` | Agent mode: `plan` or `build` |
| `--resources` | No | `default` | Resource profile: `light`, `default`, `heavy` |
| `--yaks` | No | [] | Yack paths from .yaks/ to assign (can repeat) |
| `--yak-path` | No | `.yaks` | Path to task state directory |
| `--runtime` | No | `auto` | Runtime: `auto`, `sandboxed`, `native` |

### Behavior

1. **Personality selection**: Randomly pick from Yakriel, Yakueline, Yakov, Yakira
2. **Runtime detection**: sandboxed (Docker) if available, else native
3. **Prompt assembly**: Combine personality + role description + yx instructions + user prompt
4. **Sandboxed mode**: Default. Uses `.devcontainer/` from repository root to build the container image. Constrained with resource limits (CPU, memory, pids), tmpfs mounts, bind-mounted workspace. Full isolation.
5. **Native mode**: Runs opencode directly on the host. Full system access, no container isolation. Useful when worker needs to interact with host tooling.
6. **Metadata**: Write to `.yak-boxes/<name>.meta`
7. **Task assignment**: Update yx field `assigned-to` for each task

### Resource Profiles

| Profile | CPUs | Memory | PIDs |
|---------|------|--------|------|
| `light` | 0.5 | 1g | 256 |
| `default` | 1.0 | 2g | 512 |
| `heavy` | 2.0 | 4g | 1024 |

## Stop Command

```bash
yak-box stop <worker-name> [flags]
```

### Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--timeout` | 30s | Docker stop timeout |
| `--force` / `-f` | false | Skip task cleanup, immediate stop |
| `--dry-run` | false | Show what would happen |

### Behavior

1. Load metadata from `.yak-boxes/<worker-name>.meta`
2. If `--force` not set: clear task assignments (remove `assigned-to` files)
3. Runtime-specific stop:
   - sandboxed: stop container → close Zellij tab → remove container
   - native: close tab (sends SIGTERM to processes)
4. Delete metadata file
5. **Fallback**: If no metadata, try to detect worker via Docker ps or Zellij tabs

## Check Command

```bash
yak-box check [flags]
```

### Flags

| Flag | Description |
|------|-------------|
| `--blocked` | Show only blocked tasks |
| `--wip` | Show only in-progress tasks |
| `--prefix` | Filter by task prefix |

### Output

1. Task statuses: `agent-status` field from all tasks in `.yaks`
2. Running workers: Docker container name, status, running time
3. Live cost: OpenCode cost from each running container

## Kill Command

```bash
yak-box kill <worker-name>
```

Simple wrapper around `docker stop -t 10`. Does NOT clean up metadata or task assignments — use `shutdown` for full cleanup.

## Data Structures

### Worker Metadata (.yak-boxes/<name>.meta)

```bash
SHAVER_NAME="Yakov"
SHAVER_EMOJI="🦬🔔"
DISPLAY_NAME="Yakov 🦬🔔 api-auth"
TAB_NAME="api-auth"
CONTAINER_NAME="yak-worker-api-auth"
RUNTIME="sandboxed"
CWD="/home/yakob/yakthang/api"
SPAWNED_AT=1700000000
YAK_PATH="/home/yakob/yakthang/.yaks"
ZELLIJ_SESSION_NAME="orchestrator"
TASKS=("auth/api/login" "auth/api/logout")
```

### Persona

```go
type Persona struct {
    Name        string
    Emoji       string
    Trait       string
    Personality string // Loaded from file
}
```

### Worker struct

```go
type Worker struct {
    Name          string
    DisplayName   string
    ContainerName string
    Runtime       string // "sandboxed" or "native"
    CWD           string
    YakPath       string
    Tasks         []string
    SpawnedAt     time.Time
}
```

## File Structure

```
src/yakbox/
├── go.mod
├── main.go
├── cmd/
│   ├── root.go
│   ├── spawn.go
│   ├── shutdown.go
│   ├── check.go
│   └── kill.go
├── internal/
│   ├── config/
│   │   └── config.go       # Configuration loading
│   ├── persona/
│   │   └── persona.go      # Personality selection
│   ├── runtime/
│   │   ├── sandboxed.go    # Container-based runtime
│   │   └── native.go       # Direct host execution
│   ├── metadata/
│   │   └── metadata.go     # Worker metadata management
│   ├── prompt/
│   │   └── prompt.go       # Prompt assembly
│   └── zellij/
│       └── layout.go       # KDL layout generation
├── pkg/
│   └── types/
│       └── types.go        # Shared types
```

Note: Container images are built from `.devcontainer/` at the repository root.

## Dependencies

Minimal dependencies to keep the tool lightweight:

- **cobra** — CLI framework (or urfave/cli for simplicity)
- **docker/docker** — Docker SDK for Go
- **testify** — Testing assertions and mocking
- Standard `testing` package for test structure

## Testing Strategy

Two-layer testing approach:

### Layer 1: Go Unit Tests (src/yakbox/)
- **Framework**: Standard `testing` + Testify
- **Location**: `*_test.go` files alongside source code
- **Coverage**: Individual functions, command handlers, internal packages
- **Strategy**: TDD during implementation

### Layer 2: Integration Tests (tests/)
- **Framework**: shellspec for behavioral testing
- **Location**: Top-level `tests/` directory
- **Coverage**: End-to-end CLI behavior with real Docker/Zellij
- **Strategy**: Uses actual infrastructure (not mocked)
- **Test Resources**: Prefix with `test-` (e.g., `test-worker-1`, `test-yaks`)
- **CI**: Skip for now

### Example Structure
```
tests/
├── spec/
│   ├── spawn_spec.sh       # spawn behavior
│   ├── stop_spec.sh        # stop behavior
│   └── check_spec.sh       # check behavior
├── fixtures/               # test data, mock yaks
└── helper.sh               # test utilities
```

## Implementation Notes

1. **Use exec for subprocesses**: Run Docker and Zellij commands via `exec.Command`
2. **Preserve shell script behavior**: The Go implementation must produce identical results
3. **Error handling**: Detailed error messages matching shell script style (icons, etc.)
4. **Idempotency**: Safe to run stop multiple times
5. **Deprecated alias**: `kill` command kept as alias for `stop --force`
5. **Fallback detection**: Match shell script's fallback logic for missing metadata

## Migration Path

Phase 1 (current task):
- [ ] Initialize Go module
- [ ] Set up CLI structure
- [ ] Create this design doc

Phase 2 (future):
- [ ] Implement spawn command
- [ ] Implement stop command
- [ ] Implement check command
- [ ] Add tests
- [ ] Replace shell scripts with symlinks or wrapper scripts
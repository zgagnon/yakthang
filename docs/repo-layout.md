# Repository Layout Spec

## Overview

yakthang is both a development environment for its own tooling and a reusable orchestration framework. The layout separates specs, source, compiled output, and scratch space.

## Directory Structure

```
yakthang/
├── docs/           # Specs, design docs, intent documentation
├── src/
│   ├── yaks/       # yx CLI - task tracker (shell/Rust)
│   ├── yak-map/    # Zellij WASM plugin (Rust)
│   └── yak-box/    # Worker orchestration tool (Go)
├── bin/            # Compiled binaries from src/
│   ├── yak-box     # Worker manager CLI
│   ├── yak-map.wasm # YakMap Zellij plugin
│   ├── yx          # Task tracker CLI
│   └── archive-yaks.sh # Archive completed tasks to memory/
├── scripts/        # Operational scripts (network setup, firewall)
├── memory/         # Archived task outcomes (organized by goal)
├── .devcontainer/  # DevContainer config for worker images
├── .opencode/      # OpenCode/OpenClaw workspace config
│   ├── agents/     # Agent definitions
│   └── personalities/ # Worker persona templates
├── tmp/            # Ephemeral scratch space (gitignored)
├── .yaks/          # Task state (managed by yx)
├── .yak-boxes/     # Worker metadata + persistent homes
│   └── @home/      # Persistent worker home directories
├── .openclaw/      # OpenClaw workspace config
└── .worker-costs/  # Cost tracking data + CSV history
```

## Principles

1. **`docs/`** contains all specs describing intent and design. Not READMEs scattered across source dirs -- centralized here.

2. **`src/`** groups all tool source code. Each sub-directory is a self-contained project with its own build system.

3. **`bin/`** holds compiled output. When using yakthang for a non-development purpose, you need `bin/` + `docs/` + `.yaks/` -- no source required.

4. **`tmp/`** is ephemeral, gitignored. Workers and builds use it for intermediate artifacts.

## Container Mounts

Docker worker containers mount the workspace directory and the `.yaks/` task
state. Workers also get persistent home directories at `.yak-boxes/@home/{Persona}/`
that survive container restarts. DevContainer configuration
(`.devcontainer/devcontainer.json`) can add additional mounts. Scoping is done
via task context (`yx`), not filesystem isolation. Git is the safety net against
workers wandering outside their lane.

## Migration Notes

Old top-level scripts (`spawn-worker.sh`, `check-workers.sh`, `shutdown-worker.sh`, `kill-worker.sh`, `yak-map.sh`) have been replaced by `bin/yak-box` and `bin/yak-map.wasm`.

Old `worker.Dockerfile` has been replaced by `.devcontainer/devcontainer.json` support. yak-box now reads devcontainer configs to build/pull worker images automatically.

Config files:
- `orchestrator.kdl` → root (Zellij layout)
- `.devcontainer/` → root (worker image config)
- `themes/` → root (Zellij themes)
- `.opencode/` → root (OpenCode/OpenClaw config)
- `cost-*.sh` → root (cost tracking scripts)

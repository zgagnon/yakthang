# Plan and Build Modes

## Overview

Workers operate in one of two modes, controlled by the `--mode` flag on
`yak-box spawn`. This enables a two-phase workflow where complex tasks
are planned before implementation begins.

## Build Mode (default)

```bash
./bin/yak-box spawn --cwd ./api --name "auth-builder" "Work on auth/* tasks."
```

- Uses opencode's `build` agent (full file editing permissions)
- Worker implements directly: reads context, writes code, marks tasks done
- Prompt says: "your job is to shave them clean"
- Appropriate for: simple tasks, well-defined requirements, clear approach

### Build Workflow

1. `yx ls` to see tasks
2. `yx context --show <name>` to read requirements
3. `yx state <name> wip` + report `wip: starting`
4. Do the work, updating `agent-status` as progress is made
5. `yx done <name>` + report `done: <summary>`

## Plan Mode

```bash
./bin/yak-box spawn --mode plan --cwd ./api --name "auth-planner" \
  "Plan the auth refactor."
```

- Uses opencode's `plan` agent (can read code and write plans, cannot edit
  application files)
- Worker analyzes the codebase and produces a plan, then stops
- Prompt says: "your job is to scout them and plan the shave. Do NOT pick
  up the clippers."
- Appropriate for: complex tasks, ambiguous requirements, multi-component
  changes

### Plan Workflow

1. `yx ls` to see tasks
2. `yx context --show <name>` to read requirements
3. `yx state <name> wip` + report `wip: starting plan`
4. Analyze codebase, understand the problem
5. Write a detailed plan (markdown file or yx context)
6. Report `blocked: plan ready for review`
7. **STOP** — do not implement

## Two-Phase Pattern

For complex tasks, the orchestrator runs both phases in sequence:

```
Phase 1: Plan
  Yakob spawns --mode plan worker
  Worker produces plan, reports blocked
  Human reviews plan

Phase 2: Build
  Yakob spawns --mode build worker with plan as context
  Worker follows the plan, implements, marks done
```

The handoff between phases uses the existing `blocked:` status protocol.
The orchestrator sees `blocked: plan ready for review` in `yak-box check`,
the human reviews, and then a build worker is spawned with a reference to
the plan.

## When to Use Which

| Signal | Mode |
|--------|------|
| Clear requirements, obvious approach | `build` |
| Simple, isolated change | `build` |
| Complex or ambiguous requirements | `plan` |
| Multiple components affected | `plan` |
| Want to review approach before implementation | `plan` |
| Unfamiliar codebase or risky change | `plan` |

## Agent Permissions

The mode maps directly to opencode's agent system:

- **`build` agent**: Full permissions — can read, write, edit, run commands.
  `plan_enter` and `plan_exit` are denied (it stays in build mode).
- **`plan` agent**: Read-only for application code. Can write to plan files
  (`.opencode/plans/*.md`). Can enter and exit plan mode. Cannot edit
  application files.

This provides a hard permission boundary — a plan worker literally cannot
modify your code, even if its prompt instructions fail to prevent it.

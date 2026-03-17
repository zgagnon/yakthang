# Yakthang Installer Design

This document captures the installer design for yakthang — what gets installed,
where it goes, and why the design works the way it does. It's a reference for
contributors and a rationale for the choices made.

This is a **contributor tool**. The target audience is people who have the
yakthang repo checked out and are building from source. It is not a general
end-user installer.

## Prerequisites

The following must be present before running `just install`:

- **Rust toolchain** — for building `yx` and `yak-map`
- **Go toolchain** — for building `yak-box`
- **just** — for running build and install targets
- **Zellij** — for the orchestrator session
- **Claude Code** — for yakob and the yak shaving skills

## What the installer does

`just install` copies all yakthang components to well-known locations so
the tools work from any directory. After installation:

- `yx`, `yak-box`, and `yakthang` are on your `$PATH`
- Yakob's agent definition is in `~/.claude/agents/`
- The yak shaving skills are in `~/.claude/skills/`
- The orchestrator config is where `yakthang` expects it
- The yak-map Zellij plugin is where Zellij expects it

No project directory, no `source` commands, no PATH manipulation in your
shell config. Just tools that work.

## Install locations

| Component | Destination | Override env var |
|-----------|-------------|-----------------|
| `yx` binary | `$BIN_DIR/yx` | `YAKTHANG_BIN` |
| `yak-box` binary | `$BIN_DIR/yak-box` | `YAKTHANG_BIN` |
| `yakthang` launcher | `$BIN_DIR/yakthang` | `YAKTHANG_BIN` |
| `orchestrator.kdl` | `$CONFIG_DIR/orchestrator.kdl` | `YAKTHANG_CONFIG` |
| `yakob.md` | `$CLAUDE_DIR/agents/yakob.md` | `YAKTHANG_CLAUDE` |
| `yak-*/` skills | `$CLAUDE_DIR/skills/yak-*/` | `YAKTHANG_CLAUDE` |
| `yak-map.wasm` | discovered at install time via `zellij setup --check` | `zellij --data-dir` |

**Defaults:**

```
BIN_DIR    = ${YAKTHANG_BIN:-${YAKTHANG_PREFIX:-$HOME/.local}/bin}
CONFIG_DIR = ${YAKTHANG_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/yakthang}
CLAUDE_DIR = ${YAKTHANG_CLAUDE:-$HOME/.claude}
```

The layered fallback (`YAKTHANG_BIN` → `YAKTHANG_PREFIX/bin` → `~/.local/bin`)
means you can redirect the entire installation with a single variable, or just
override individual locations. Most contributors need neither.

**Zellij plugin directory:** There is no `ZELLIJ_PLUGIN_DIR` environment
variable. The plugin directory is platform-specific — XDG on Linux,
`~/Library/Application Support/org.Zellij-Contributors.Zellij/plugins/` on
macOS — and must be discovered at install time:

```sh
zellij setup --check 2>/dev/null | grep 'PLUGIN DIR'
```

The installer runs this command to determine the correct destination. If you
need to override it, pass `--data-dir <PATH>` to `zellij`, which redirects
Zellij's data directory (and thus the plugins subdirectory).

## Why no interactive prompts

The installer must work in two environments: a human running `just install`
in a terminal, and an agent running it headlessly — Claude Code during setup,
CI during testing, a spawn script bootstrapping a new workstation.

Interactive prompts break both. A human running in a non-interactive context
(piped input, a script wrapper) gets stuck. An agent has no mechanism to respond
to them at all. The design follows the standard Unix convention: silent defaults,
env var overrides, and a `--dry-run` flag for inspection without side effects.

If the defaults don't work for your setup, set an env var. If you're not sure
what will happen, run with `--dry-run` (or `just install --dry-run`) and see
the full list of operations before any files change.

## Why copy, not symlink

The earlier setup used symlinks from `~/.claude/skills/` back into the
yakthang repo. This was convenient during development but has two problems:

**Location coupling.** A symlink encodes the repo's absolute path at the time
it was created. Move the repo, rename the user's home directory, or clone on
a new machine, and the symlinks break silently. The tools appear installed but
don't work.

**Version coupling.** A symlink always points at the current working tree. A
checkout, a rebase, or a `git stash` can change what `yx` does mid-session,
in ways that are surprising and hard to diagnose.

Copies decouple installation from the repo. The installed version is fixed
at install time. To update, run `just install` again — explicitly, intentionally.
The repo can live anywhere, move anywhere, and the installed tools keep working
until you choose to update them.

## `just doctor`

`just doctor` is a post-install validation target. It checks that the
installation is complete and visible to the tools that depend on it.

For each installed component, `doctor` verifies:

- **Binaries**: `yx`, `yak-box`, and `yakthang` exist at `$BIN_DIR` and are
  on `$PATH`. If a binary exists but isn't on PATH, `doctor` prints the
  specific `export PATH=...` line needed.
- **Agent definition**: `~/.claude/agents/yakob.md` (or `$CLAUDE_DIR/agents/yakob.md`)
  exists and is non-empty.
- **Skills**: Each `yak-*/` skill directory is present under `$CLAUDE_DIR/skills/`.
  Missing skills are listed individually.
- **Zellij plugin**: `yak-map.wasm` exists at the path reported by
  `zellij setup --check` (platform-specific; XDG on Linux,
  `~/Library/Application Support/...` on macOS).
- **Orchestrator config**: `orchestrator.kdl` exists at `$CONFIG_DIR`.

For each check that fails, `doctor` prints the fix: either the install command
to run, or the env var to set. No interactive prompts. No auto-repair. The
output is meant to be read and acted on deliberately.

Example output for a partially-installed system:

```
✓ yx                → /home/user/.local/bin/yx
✓ yak-box           → /home/user/.local/bin/yak-box
✓ yakthang          → /home/user/.local/bin/yakthang
✗ yakob.md          → not found at ~/.claude/agents/yakob.md
  fix: just install (or set YAKTHANG_CLAUDE to override location)
✓ skills/yak-shaving-handbook
✓ skills/yak-brand
✗ skills/yak-wrap   → not found
  fix: just install
✓ yak-map.wasm      → /home/user/.local/share/zellij/plugins/yak-map.wasm
✓ orchestrator.kdl  → ~/.config/yakthang/orchestrator.kdl
```

`doctor` exits 0 if all checks pass, non-zero otherwise — making it usable in
CI and automation.

## `yakthang` launcher behavior

The `yakthang` binary is a thin launcher. Its job is to find the right
orchestrator config and start a Zellij session.

At startup, it looks for `orchestrator.kdl` in this order:

1. `$YAKTHANG_CONFIG` (if set)
2. `${XDG_CONFIG_HOME:-$HOME/.config}/yakthang/orchestrator.kdl`

Once it finds the config, it starts a Zellij session with that layout. The
session name is optional — pass one as the first argument, or let Zellij
generate one.

The orchestrator layout starts Claude with `--agent yakob`. Claude finds
`yakob.md` in `~/.claude/agents/`, which is the global agents directory —
it works from any working directory because it's not resolved relative to cwd.

The design consequence: after installation, `yakthang` can be run from anywhere.
You don't need to be in the yakthang repo. You don't need any environment
setup. The config and agent definition are at fixed, well-known paths.

## Migrating from the old symlink setup

Earlier versions of yakthang used symlinks rather than copies. If you set up
yakthang before this installer was introduced, you may have:

- `~/.claude/skills/yak-*/` → symlinks pointing into the yakthang repo
- `~/.claude/agents/yakob.md` → a symlink or a project-local file
- `launch.sh` and `orchestrator.kdl` in the project root, used directly

To migrate:

1. **Run the installer**: `just install`. This copies the current versions of
   all components to the standard locations.

2. **Remove the old symlinks**: Check `~/.claude/skills/` for symlinks pointing
   into the yakthang repo and delete them. The installer will have already
   created the copies; the symlinks are now redundant and potentially confusing.

   ```sh
   # Find symlinks in skills dir pointing into yakthang repo
   find ~/.claude/skills -maxdepth 1 -type l | xargs ls -la | grep yakthang
   # Remove each one:
   rm ~/.claude/skills/yak-shaving-handbook  # repeat for each
   ```

3. **Check `~/.claude/agents/yakob.md`**: If it's a symlink, replace it with
   the installed copy (the installer handles this, but verify with `ls -la`).

4. **Stop using `launch.sh` directly**: Use `yakthang` from your PATH instead.
   The old `launch.sh` in the project root can be left alone or removed — it
   no longer needs to be the entry point.

5. **Run `just doctor`** to verify the new installation is complete and correct.

The old symlink approach will keep working until the symlinks break (repo move,
reclone, etc.). The migration is not urgent, but the new setup is more robust
and is what documentation and tooling will assume going forward.

## Versioning

The installer copies a snapshot of the current build. There is no version
pinning or manifest — the installed version is whatever was built when you ran
`just install`. To update to a newer version:

```sh
git pull       # or jj pull, depending on your setup
just build     # rebuild binaries from source
just install   # overwrite installed copies with new versions
just doctor    # verify the update landed correctly
```

This is intentionally simple. Yakthang is a personal workstation tool, not a
distributed package. Version management at the system-package level (homebrew,
nix, apt) would add complexity that doesn't pay off for a single-user install.
If you need reproducible multi-machine installs, the env var overrides and
`just doctor` exit code give you enough to script it.

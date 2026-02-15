# yak-map Plugin Design

## Overview

yak-map is a Zellij plugin that replaces the current `watch "yx ls"` approach in the orchestrator's left pane with a native plugin that provides richer task visualization, keyboard navigation, and potentially interactive features.

## Current State

The orchestrator layout (`orchestrator.kdl`) currently defines:

```
pane size="33%" name="yak-map" {
    command "./yak-map.sh"
}
```

The current `yak-map.sh` runs a simple `while true` loop:

```bash
buffer=$(yx ls --format '{name}{?assigned-to: [{assigned-to}]}')
echo -ne "$CLEAR"
printf '%s\n' "$buffer"
sleep 2
```

## Goals

1. **Replace the watch loop** with a native Zellij plugin
2. **Show task hierarchy** with proper tree visualization
3. **Display metadata annotations** (assigned-to, agent-status)
4. **Enable keyboard navigation** (select tasks, scroll)
5. **Provide color-coded status** (wip, done, blocked)

## Architecture

### Key Decision: Direct Filesystem Access

The plugin reads `.yaks/` directly rather than calling `yx` as a subprocess.

**Why:**
- WASM plugins have limited subprocess support
- No runtime dependency on yx
- Simpler and faster

**Risk mitigation:** An anti-corruption layer abstracts the storage format.

### Data Flow

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   .yaks/    │────▶│  TaskRepository  │────▶│   State     │
│  (filesystem)     │ (anti-corruption) │     │  (Vec<Task>)│
└─────────────┘     └──────────────────┘     └─────────────┘
         │                                       │
         │  TaskRepository provides:             ▼
         │  - list_tasks() → Vec<TaskPath> ┌─────────────┐
         │  - get_field(path, field)       │   Render    │
         │  - Handles format changes       │ (ANSI text) │
         ▼                                  └─────────────┘
    .yaks/
    ├── task-name/
    │   ├── state          # "wip" | "todo" | "done"
    │   ├── assigned-to    # worker name
    │   └── agent-status   # "wip: doing X"
    └── parent/
        └── child/
            └── state
```

### Components

#### 1. Task Data Model

```rust
struct TaskLine {
    path: String,       // Full path: "yurt-poc/worker-assignment"
    name: String,       // Just the name: "worker-assignment"
    depth: usize,       // 0 = root, 1 = child, etc.
    status: char,       // '●' (active), '○' (todo)
    assigned_to: Option<String>,
    agent_status: Option<String>,
}
```

#### 2. TaskRepository (Anti-Corruption Layer)

- Read `.yaks/` directory structure directly
- Provides `list_tasks()`, `get_field()`, `get_task()` methods
- If yx changes storage format, update TaskRepository only — rest of plugin stays unchanged

```rust
struct TaskRepository {
    yaks_dir: PathBuf,
}

impl TaskRepository {
    fn list_tasks(&self) -> Vec<(String, usize)>;
    fn get_field(&self, path: &str, field: &str) -> Option<String>;
    fn get_task(&self, path: &str, depth: usize) -> Task;
}
```

#### 3. Renderer Module

- Convert task list to ANSI-rendered text
- Apply colors based on task state:
  - `blocked:*` → Red
  - `done:*` → Green  
  - `wip:*` → Yellow
  - Default → White
- Support line truncation to fit column width
- Highlight selected line (reverse video)

### Event Handling

The plugin subscribes to:

| Event | Action |
|-------|--------|
| `Timer` (2s interval) | Refresh task list |
| `Key::Up` / `Key::Down` | Navigate tasks |
| `Key::Enter` | Open `context.md` in floating editor pane |
| `Key::r` | Manual refresh |
| `Resize` | Recalculate truncation |

### Build Requirements

```bash
rustup target add wasm32-wasi
cargo build --target wasm32-wasi
```

Output: `target/wasm32-wasi/debug/yak-map.wasm`

## Integration

### Option A: Direct Plugin Load

In `orchestrator.kdl`:

```
pane size="33%" name="yak-map" {
    plugin "file:target/wasm32-wasi/debug/yak-map.wasm"
}
```

### Option B: Via Plugin Manager

If the plugin is installed to `~/.local/share/zellij/plugins/`:

```
pane size="33%" name="yak-map" {
    plugin "yak-map"
}
```

## Comparison: Script vs Plugin

| Feature | Script (current) | Plugin (proposed) |
|---------|------------------|-------------------|
| Tree visualization | Via yx ls | Custom rendering |
| Assignment display | Via format flag | Inline annotation |
| Color-coded status | Via ANSI in output | Rich state colors |
| Keyboard navigation | None | Up/Down/Enter |
| Error handling | Basic | Graceful degradation |
| Resize handling | Terminal default | Smart truncation |
| Memory footprint | Per-process | Single instance |

## Implementation Phases

### Phase 1: Core Display (MVP)

- [ ] Execute `yx ls` subprocess
- [ ] Parse tree structure
- [ ] Render task list with colors
- [ ] Timer-based refresh (2s)
- [ ] Integrate into orchestrator.kdl

### Phase 2: Interactive Features

- [ ] Keyboard navigation (up/down)
- [ ] Selected task highlighting
- [ ] Manual refresh key (r)
- [ ] Scroll beyond visible area

### Phase 3: Enhancements

- [ ] Floating editor pane (on Enter)
  - Calls `open_file_floating(".yaks/{task-path}/context.md")`
  - Uses user's `$EDITOR` environment variable
  - Tree remains visible underneath
  - Requires `OpenFiles` permission
- [ ] Quick-jump to task by name
- [ ] Filter by status/assignment
- [ ] Persist last selection

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| yx storage format changes | TaskRepository anti-corruption layer |
| `$EDITOR` not set | Fallback to `cat` in command pane |
| WASM binary size | Optimize with LTO, single function |
| Plugin loading failures | Fallback to script if plugin fails |

## Testing Strategy

### Unit Tests (`cargo test`)

All unit tests use temp directories — no WASM runtime needed.

#### Test Module Structure

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    fn mock_yaks() -> (TempDir, PathBuf) {
        let temp = TempDir::new().unwrap();
        let yaks = temp.path().join(".yaks");
        fs::create_dir_all(&yaks).unwrap();
        (temp, yaks)
    }

    fn create_task(yaks: &Path, path: &str) {
        fs::create_dir_all(yaks.join(path)).unwrap();
    }

    fn set_field(yaks: &Path, task_path: &str, field: &str, value: &str) {
        fs::write(yaks.join(task_path).join(field), value).unwrap();
    }
}
```

#### Test Cases: TaskRepository

- `list_tasks_returns_empty_for_empty_directory`
- `list_tasks_finds_root_level_task`
- `list_tasks_finds_nested_task`
- `list_tasks_finds_multiple_tasks_at_different_depths`
- `get_field_returns_none_for_missing_field`
- `get_field_returns_value_for_present_field`
- `get_field_trims_whitespace`
- `get_task_assembles_all_fields`
- `get_task_defaults_to_todo_when_no_state`

#### Test Cases: State / Rendering

- `task_color_red_for_blocked`
- `task_color_green_for_done`
- `task_color_yellow_for_wip`
- `task_color_yellow_when_state_is_wip`
- `task_color_white_for_todo`
- `task_name_extracts_last_path_component`

#### Test Cases: Edge Cases

- `handles_special_characters_in_task_name`
- `handles_empty_field_file`

### Manual Testing

Build and load in Zellij:

```bash
cd src/yak-map
cargo build --target wasm32-wasi
zellij action start-or-reload-plugin file:target/wasm32-wasi/debug/yak-map.wasm
```

#### Manual Test Checklist

| Test | Steps | Expected |
|------|-------|----------|
| Plugin loads | Load plugin | Task tree appears |
| Refresh works | Modify `.yaks/`, wait 2s | Tree updates |
| Navigation | Press `↑` / `↓` | Selection moves |
| Details (Phase 2) | Select task, press `Enter` | Floating editor opens with `context.md` |
| Colors | Create tasks with different states | Correct colors per state |

## References

- Zellij Plugin API: https://zellij.dev/documentation/plugins.html
- zellij-tile crate: https://docs.rs/zellij-tile/latest/zellij_tile/
- Example plugin: https://github.com/zellij-org/rust-plugin-example
- Current PoC: `docs/research/FINDINGS-yak-map-wrapper.md`

## Open Questions

1. How to detect `.yaks/` changes? (Timer polling vs FileSystem events)
2. Should TaskRepository cache reads?
3. How to handle very large task trees (100+ tasks)?
4. Should we persist selection across refreshes?
5. Integration with Zellij's built-in search?
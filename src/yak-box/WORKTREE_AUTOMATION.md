# Worktree Automation Integration

## Summary

Successfully extracted and integrated automatic worktree management from packnplay into yak-box.

## Implementation Details

### 1. Created pkg/worktree Package

**File: `src/yak-box/pkg/worktree/manager.go`**

Extracted and adapted the following functions from packnplay's `pkg/git/worktree.go`:

- `DetermineWorktreePath()` - Calculates XDG-compliant worktree path (`~/.local/share/yakthang/worktrees/<project>/<task-path>`)
- `sanitizeTaskPath()` - Converts task path to filesystem-safe name
- `IsGitRepo()` - Checks if a directory is a git repository
- `GetCurrentBranch()` - Returns current branch name
- `WorktreeExists()` - Checks if a worktree with given name exists
- `GetWorktreePath()` - Gets path of existing worktree
- `CreateWorktree()` - Creates new worktree with branch
- `EnsureWorktree()` - High-level function that ensures worktree exists (creates if needed)

**Key Adaptations:**
- Changed XDG path from `packnplay/worktrees` to `yakthang/worktrees`
- Changed function parameter from `worktreeName` to `taskPath` for clarity
- Added `projectPath` parameter to git commands to work from any directory
- Added `EnsureWorktree()` as main entry point for spawn command

### 2. Integrated into spawn Command

**File: `src/yak-box/cmd/spawn.go`**

**Changes:**
- Added `spawnAutoWorktree` flag variable
- Imported `github.com/yakthang/yakbox/pkg/worktree` package
- Added worktree creation logic in `runSpawn()`:
  - When `--auto-worktree` flag is set and tasks are assigned
  - Creates/reuses worktree for first task in list
  - Updates `absCWD` to point to worktree
  - Stores worktree path in `worker.WorktreePath`
- Added worktree path to yx task metadata (written to `worktree-path` file in task directory)
- Added `--auto-worktree` flag definition in `init()`
- Updated command examples to show new flag usage

**File: `src/yak-box/pkg/types/types.go`**

**Changes:**
- Added `WorktreePath string` field to `Worker` struct to track worktree location

**File: `src/yak-box/internal/runtime/sandboxed.go`**

**Changes:**
- Added `worktreeMount` variable to construct worktree mount argument
- Added worktree mount to docker run command when `worker.WorktreePath` is set
- Worktree is mounted at its original path inside the container for seamless git operations

### 3. Tests

**File: `src/yak-box/pkg/worktree/manager_test.go`**

Comprehensive tests covering:
- `TestDetermineWorktreePath()` - Verifies path generation for various task paths
- `TestSanitizeTaskPath()` - Verifies sanitization of special characters

**Test Results:** All tests passing ✓

### 4. Build Verification

Successfully built yak-box with new worktree functionality:
```bash
cd src/yak-box && go build .
```

Flag appears correctly in help output:
```
--auto-worktree      Automatically create and use git worktree for the task
```

## Usage

```bash
# Basic usage with auto-worktree
yak-box spawn --cwd ./api --name api-auth --task auth/api --auto-worktree

# This will:
# 1. Detect if worktree exists at ~/.local/share/yakthang/worktrees/<project>/auth-api
# 2. Create worktree with branch "auth-api" if it doesn't exist
# 3. Mount the worktree into the container
# 4. Write worktree path to .yaks/auth/api/worktree-path
```

## Benefits

1. **Isolated Work**: Each task gets its own git worktree, preventing conflicts
2. **Automatic Management**: Worktrees are created/reused automatically
3. **XDG Compliance**: Worktrees stored in standard location (`~/.local/share/yakthang`)
4. **Metadata Tracking**: Worktree path stored in yx task metadata
5. **Clean Integration**: Minimal changes to existing spawn command
6. **Optional Feature**: Only activated with `--auto-worktree` flag

## Files Changed

- `src/yak-box/pkg/worktree/manager.go` (new, 212 lines)
- `src/yak-box/pkg/worktree/manager_test.go` (new, 98 lines)
- `src/yak-box/cmd/spawn.go` (modified, +32 lines)
- `src/yak-box/pkg/types/types.go` (modified, +1 field)
- `src/yak-box/internal/runtime/sandboxed.go` (modified, +7 lines)

## Total Lines of Code

Approximately 350 lines added (including tests and integration).

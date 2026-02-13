# yak-map.sh Proof of Concept - Findings

## Summary
Successfully created a working prototype that annotates `yx ls` output with `assigned-to` field values.

## What Works

### Core Functionality
- ✅ Parses hierarchical task tree from `yx ls` output
- ✅ Correctly builds full path for nested tasks (e.g., `yurt-poc/worker-assignment-display/explore-yak-map-wrapper`)
- ✅ Looks up `assigned-to` field from `.yaks/[full-path]/assigned-to`
- ✅ Inserts assignment annotation at beginning of task line (after bullet)
- ✅ Preserves original ANSI colors and formatting
- ✅ Gracefully handles tasks without assignments (no annotation)

### Visual Output
- Annotations appear as `[name]` in dimmed cyan, immediately after the bullet
- Format: `● [alice] task-name` or `○ [bob] task-name`
- Preserves tree structure and colors
- Works with both root-level and deeply nested tasks

### Performance
- Runs in ~0.5-0.7 seconds with current task tree (~25 tasks)
- Acceptable for `watch --interval 2` usage
- Some variability (spikes to 0.8s) but within tolerance

## How It Works

### Algorithm
1. Read `yx ls` output line by line
2. Strip ANSI escape codes to parse task name
3. Detect hierarchy using tree connector characters (`├─`, `╰─`, `│`)
4. Maintain path stack by:
   - Resetting stack for root tasks (no tree connectors)
   - Keeping stack depth for child tasks (has tree connectors)
   - Using indent level to map depth positions
5. Build full path from stack: `parent/child/grandchild`
6. Check for `.yaks/[full-path]/assigned-to` file
7. If found, append `→ [value]` to output line

### Key Insight
The hierarchy is determined by tree connector presence, not just indent:
- `  ● task` = root level (reset path)
- `  ├─ ● task` = child of previous root (even at same indent)
- `  │  ├─ ● task` = grandchild (deeper indent + connectors)

## Fragility Assessment

### Brittle Points

1. **ANSI Code Parsing** (Medium risk)
   - Uses `sed 's/\x1b\[[0-9;]*m//g'` to strip color codes
   - Assumes standard ANSI SGR sequences
   - Would break if `yx` changes escape code format
   - Mitigation: Request `yx ls --plain` flag (see recommendations)

2. **UTF-8 Tree Characters** (Low risk)
   - Depends on specific box-drawing chars: `├ ╰ ─ │`
   - These are standard unicode and unlikely to change
   - Pattern: `^[[:space:]│]*[├╰]` to detect hierarchy

3. **Task Name Extraction** (Low risk)
   - Regex: `sed -E 's/^[[:space:]│├─╰]*[[:space:]]*[●○][[:space:]]*//'`
   - Assumes bullet symbols `●` (wip/done) or `○` (todo)
   - If `yx` adds new status symbols, regex needs update

4. **Indent-to-Depth Mapping** (High risk for large trees)
   - Uses associative array to map indent → depth
   - Works for current tree structure
   - Could fail with:
     - Very deep nesting (>10 levels)
     - Mixed indent widths
     - Malformed tree output
   - Current tree depth: 3 levels (works fine)

5. **Performance with Scale** (Medium risk)
   - Current: 0.6s for 25 tasks
   - Estimated: 5-10s for 1000+ tasks (linear growth)
   - Each line requires: string operations, array manipulation, file check
   - For large trees (100+ tasks), consider caching or batch field reads

### Robust Points

1. **File System Integration**
   - Direct filesystem access to `.yaks/` structure
   - No parsing of yx internal state
   - Works as long as `.yaks/[path]/[field]` pattern remains

2. **Graceful Degradation**
   - Missing assigned-to files → no annotation (silent)
   - Empty field values → handled cleanly
   - Malformed lines → passed through unchanged

3. **Color Preservation**
   - Original line passed to output with annotation appended
   - Original formatting intact

## Test Coverage

Tested scenarios:
- ✅ Root-level task assignment
- ✅ Second root-level task (verify path reset)
- ✅ Nested child task (2 levels deep)
- ✅ Deeply nested task (3 levels deep)
- ✅ Sibling tasks at same level
- ✅ Tasks with no assignment
- ✅ Performance under watch command

## Recommendations

### For Integration
1. **Request `yx ls --plain` flag** from yx maintainers
   - Machine-readable format (no ANSI codes)
   - Explicit depth/path information
   - More reliable than parsing tree graphics

2. **Alternative: Use yx list API**
   - If yx exposes task list as JSON/structured data
   - Parse once, combine with field values
   - Render tree with annotations

3. **Consider field batch read**
   - Currently: one file read per task per render
   - Optimization: read all assigned-to fields once, cache in memory
   - For 100+ tasks, could reduce runtime by 50%

### For Production Use
- Add error handling for malformed yx output
- Add `--debug` flag to troubleshoot parsing issues
- Consider timeout for large trees
- Add tests for edge cases (single-character task names, special chars, etc.)

### If Integrated into Orchestrator
- Replace left pane command: `watch --interval 2 ./yak-map.sh`
- Ensure script is executable and in PATH
- Consider colorization based on assignment status
- Add worker health indicators (green=active, red=blocked, etc.)

## Conclusion

**Viability**: HIGH
The wrapper works reliably for the current use case. The fragility points are manageable risks, and the approach is sound.

**Primary Risk**: Parsing `yx ls` output is inherently fragile. A native `yx ls --with-fields` feature would be far more robust.

**Recommendation**: 
- ✅ Safe to use for this PoC/demo
- ⚠️  For production, file feature request with yx project
- ⚠️  Monitor yx releases for output format changes

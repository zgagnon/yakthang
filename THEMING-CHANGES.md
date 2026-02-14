# Theming Changes - Shell Panes & YakMap Tab

## Problem Statement
The shell panes and YakMap tab were not inheriting the graph box theming applied to OpenCode panes, creating visual inconsistency in the orchestrator UI.

## Root Cause Analysis

1. **OpenCode panes** display graph boxes with styling controlled by OpenCode's `gruvbox` theme and agent color settings
2. **Shell panes and YakMap** are plain Zellij terminal panes that only receive Zellij's pane frame styling
3. **Built-in `gruvbox-dark` theme** lacked a `frame_unselected` definition, causing unselected panes to have minimal visual distinction
4. **Frame colors didn't match** - The built-in theme used different colors than OpenCode's accent color

## Solution Implemented

Created a custom inline Gruvbox theme definition in `orchestrator.kdl` with the following enhancements:

### 1. Added `frame_unselected` Component
```kdl
frame_unselected {
    base 102 92 84        // Subtle gruvbox gray
    background 0
    emphasis_0 214 93 14
    emphasis_1 104 157 106
    emphasis_2 177 98 134
    emphasis_3 0
}
```

### 2. Updated `frame_selected` to Match OpenCode
```kdl
frame_selected {
    base 215 153 33       // Orchestrator accent color #d79921
    background 0
    emphasis_0 214 93 14
    emphasis_1 104 157 106
    emphasis_2 177 98 134
    emphasis_3 0
}
```

### 3. Embedded Theme Definition
- Theme is now defined inline in `orchestrator.kdl` (lines 12-140)
- Ensures the theme travels with the project configuration
- No dependency on global Zellij config
- Theme name changed from `gruvbox-dark` to `gruvbox` to match OpenCode

## Files Modified

1. **orchestrator.kdl**
   - Added inline theme definition with enhanced frame styling
   - Changed theme from `gruvbox-dark` to `gruvbox`
   - Lines 9-142 now contain the complete theme definition

2. **docs/theming.md**
   - Updated documentation to reflect custom theme implementation
   - Added "Implementation Notes" section explaining the fix
   - Documented the specific frame color choices

3. **themes/gruvbox.kdl** (NEW)
   - Standalone theme file for reference/reuse
   - Can be used in other layouts if needed

## Visual Result

- **Selected panes**: Warm yellow frame (#d79921) matching OpenCode graph box accents
- **Unselected panes**: Subtle gray frame (RGB 102 92 84) for clear visual hierarchy
- **Consistent appearance**: Shell panes, YakMap, and OpenCode panes now have cohesive frame styling
- **Better focus indication**: Clear distinction between focused and unfocused panes

## Testing

To verify the changes:
1. Restart Zellij with: `./restart-zellij.sh`
2. Observe that all panes (orchestrator OpenCode, shell, and YakMap) have consistent frame styling
3. Switch focus between panes - selected pane should show yellow frame, unselected show gray
4. Compare to OpenCode graph box colors - should match visually

## Technical Notes

- RGB 215 153 33 (#d79921) is Gruvbox "neutral yellow" - the orchestrator's accent color
- RGB 102 92 84 (#665c54) is Gruvbox "dark3" - used for subtle UI elements
- All other theme components remain identical to built-in `gruvbox-dark`
- Theme definition follows Zellij's KDL theme specification

### Theme Inheritance

- Theme is session-wide in Zellij
- When session starts with `./restart-zellij.sh`, it loads `orchestrator.kdl` which defines the custom `gruvbox` theme
- All tabs created in that session (including dynamically spawned worker tabs) inherit the session theme
- Worker tabs created by `spawn-worker.sh` will automatically use the custom frame styling
- No theme definition needed in worker tab layouts - they inherit from the session

### File Locations

- **Primary**: `orchestrator.kdl` (lines 9-142) - inline theme definition
- **Reference**: `themes/gruvbox.kdl` - standalone theme file for reuse
- **Global**: `~/.config/zellij/themes/gruvbox.kdl` - also available globally (optional)

# Theming

The Yak Orchestrator uses **Gruvbox** for consistent visual styling across Zellij and OpenCode, with custom frame styling to ensure shell panes and the YakMap tab visually match OpenCode's graph boxes.

## Color Palette

Gruvbox Medium provides a warm, retro-inspired color scheme with excellent readability:

- **Background:** `#282828` (dark0)
- **Foreground:** `#ebdbb2` (light1)
- **Accent colors:** Yellows, oranges, greens, blues, purples in medium contrast

See [Gruvbox repository](https://github.com/morhetz/gruvbox) for full palette details.

## Configuration

### Zellij Theme

The Zellij layout (`orchestrator.kdl`) defines a custom `gruvbox` theme inline. This theme is based on Zellij's built-in `gruvbox-dark` theme with the following enhancements:

1. **Added `frame_unselected` component** - The built-in theme lacks this, causing unselected panes to have no visible frame
2. **Matched frame colors to OpenCode** - Uses the orchestrator accent color (`#d79921` / RGB 215 153 33) for selected pane frames
3. **Consistent visual hierarchy** - Unselected frames use a subtle gruvbox gray (RGB 102 92 84) to differentiate from focused panes

This ensures shell panes and the YakMap tab have borders that match the visual style of OpenCode's graph boxes.

```kdl
themes {
    gruvbox {
        // ... theme definition ...
        frame_unselected {
            base 102 92 84
            background 0
            // ...
        }
        frame_selected {
            base 215 153 33  // Matches orchestrator accent #d79921
            background 0
            // ...
        }
    }
}

theme "gruvbox"
```

### OpenCode Theme

The OpenCode configuration (`opencode.json`) uses the built-in `gruvbox` theme:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "theme": "gruvbox"
}
```

This theme ships with OpenCode and matches the Zellij color palette.

### Orchestrator Color

Yakob (the orchestrator agent) uses **Gruvbox neutral yellow** (`#d79921`) as its UI accent color. This warm, authoritative color represents the shepherd coordinating the workers.

## Design Decisions

### Why Gruvbox?

- **Built-in support:** Both Zellij and OpenCode ship with Gruvbox themes
- **No custom configuration:** Leverages existing, well-tested themes
- **Warm aesthetic:** Matches the "yak shaving" metaphor with earthy, natural tones
- **Excellent readability:** Medium contrast optimized for long terminal sessions
- **Popular & familiar:** Widely used in the terminal/vim community

### Agent Architecture

Workers use the standard `plan` and `build` agents with personalities injected via prompts (not separate themed agents). This keeps the agent system simple while still providing personality variety through the randomly-assigned worker names and emojis:

- **Yakriel** 🦬🪒 - Precise and methodical
- **Yakueline** 🦬💈 - Fast and fearless
- **Yakov** 🦬🔔 - Cautious and thorough
- **Yakira** 🦬🧶 - Cheerful and communicative

Worker personalities are loaded from `.opencode/personalities/` and injected into the prompt by `yak-box spawn`.

## Implementation Notes

### Shell Pane and YakMap Tab Theming

**Issue**: The shell panes and YakMap tab were not inheriting the graph box theming used by OpenCode panes, creating visual inconsistency.

**Root cause**: 
- OpenCode panes render graph boxes with styling controlled by OpenCode's theme
- Shell panes and YakMap are plain terminal panes that only get Zellij's pane frames
- The built-in `gruvbox-dark` theme lacked a `frame_unselected` definition, causing unselected panes to have minimal visual distinction

**Solution**: Created a custom inline theme definition in `orchestrator.kdl` that:
1. Adds the missing `frame_unselected` component for better visual hierarchy
2. Uses the orchestrator accent color (`#d79921`) for selected pane frames to match OpenCode
3. Uses a subtle gruvbox gray for unselected frames to maintain visual consistency

This ensures all panes (OpenCode, shell, and YakMap) have cohesive frame styling.

## Future Enhancements

Potential theming improvements (not currently implemented):

1. **zjstatus**: Replace compact-bar with zjstatus for advanced status bar customization
2. **Worker color coding**: Assign distinct colors per worker personality (would require separate agent files)
3. **Status indicators**: Color-code task states (wip/blocked/done) in tab names
4. **Light mode**: Create matching light theme variant

These are intentionally deferred to keep the initial implementation simple.

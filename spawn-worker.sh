#!/usr/bin/env bash
set -euo pipefail

# spawn-worker.sh - Spawn an opencode worker in a new Zellij tab
#
# Called by the orchestrator to delegate work to sub-repos.
# The worker gets its own tab, runs in the sub-repo's directory, and receives
# all yx instructions inline.
#
# Usage:
#   spawn-worker.sh --cwd <dir> --name <tab-name> [--mode plan|build] "<prompt>"
#   spawn-worker.sh --cwd ./api --name "api-auth" "Work on auth/api/* tasks..."
#   spawn-worker.sh --cwd ./api --name "api-planner" --mode plan "Plan the auth tasks"
#
# Options:
#   --cwd <dir>       Working directory for the worker (required)
#   --name <name>     Zellij tab name (required)
#   --mode <mode>     Agent mode: plan or build (default: build)
#   --yak-path <dir>  Path to .yaks directory (default: $PWD/.yaks)

YAK_PATH="${YAK_PATH:-$PWD/.yaks}"
MODE="build"
CWD=""
TAB_NAME=""
PROMPT=""

# --- Yak-shaver personalities ------------------------------------------------
# Each worker gets a random identity. Yakob (the orchestrator) is the supervisor;
# these are the yak shavers. The yaks (tasks) are what get shaved.
SHAVER_NAMES=(Yakriel Yakueline Yakov Yakira)
SHAVER_EMOJIS=("🦬🪒" "🦬💈" "🦬🔔" "🦬🧶")
SHAVER_PERSONALITIES=(
	"You are Yakriel — precise and methodical. You measure twice, shave once. You leave clean commits and tidy code behind you."
	"You are Yakueline — fast and fearless. You tackle tasks head-on and ask forgiveness, not permission. Ship it."
	"You are Yakov — cautious and thorough. You double-check everything before marking done. Better safe than shorn."
	"You are Yakira — cheerful and communicative. You leave detailed status updates so Yakob always knows where things stand."
)

# Pick a random shaver
SHAVER_INDEX=$((RANDOM % ${#SHAVER_NAMES[@]}))
SHAVER_NAME="${SHAVER_NAMES[$SHAVER_INDEX]}"
SHAVER_EMOJI="${SHAVER_EMOJIS[$SHAVER_INDEX]}"
SHAVER_PERSONALITY="${SHAVER_PERSONALITIES[$SHAVER_INDEX]}"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--cwd)
		CWD="$2"
		shift 2
		;;
	--name)
		TAB_NAME="$2"
		shift 2
		;;
	--mode)
		MODE="$2"
		if [[ "$MODE" != "plan" && "$MODE" != "build" ]]; then
			echo "Error: --mode must be 'plan' or 'build'" >&2
			echo "Usage: spawn-worker.sh --cwd <dir> --name <tab-name> [--mode plan|build] \"<prompt>\"" >&2
			exit 1
		fi
		shift 2
		;;
	--yak-path)
		YAK_PATH="$2"
		shift 2
		;;
	*)
		if [[ -z "$PROMPT" ]]; then
			PROMPT="$1"
		else
			PROMPT="$PROMPT $1"
		fi
		shift
		;;
	esac
done

if [[ -z "$CWD" || -z "$TAB_NAME" || -z "$PROMPT" ]]; then
	echo "Usage: spawn-worker.sh --cwd <dir> --name <tab-name> [--mode plan|build] \"<prompt>\"" >&2
	exit 1
fi

# Resolve to absolute path
CWD="$(cd "$CWD" && pwd)"

# Format the tab name with the shaver identity
DISPLAY_NAME="${SHAVER_NAME} ${SHAVER_EMOJI}"

# Build the inline system prompt that teaches the worker about yx.
# This is the key design choice: sub-repos have NO CLAUDE.md about orchestration.
# Everything the worker needs to know comes in this prompt.
if [[ "$MODE" == "plan" ]]; then
	ROLE_DESCRIPTION="Your supervisor is Yakob. The yaks are tasks — your job is to scout them and plan the shave. Do NOT pick up the clippers."
else
	ROLE_DESCRIPTION="Your supervisor is Yakob. The yaks are tasks — your job is to shave them clean."
fi

WORKER_PROMPT="$(
	cat <<PROMPT_EOF
${SHAVER_PERSONALITY}

${ROLE_DESCRIPTION}

${PROMPT}

---
TASK TRACKER (yx)

You have access to a task tracker called yx. The task state lives in ${YAK_PATH}.

Commands:
  yx ls                     Show all tasks and their states
  yx context --show <name>  Read the context/requirements for a task
  yx done <name>            Mark a task as complete
  yx state <name> wip       Mark a task as in-progress

Reporting status (IMPORTANT -- the orchestrator monitors these fields):
  echo "<status>" | yx field <name> agent-status

  Write agent-status at each transition:
  - When starting:  echo "wip: starting" | yx field <name> agent-status
  - Progress:       echo "wip: <what you're doing>" | yx field <name> agent-status
  - When blocked:   echo "blocked: <reason>" | yx field <name> agent-status
  - When done:      echo "done: <summary>" | yx field <name> agent-status

PROMPT_EOF
)"

if [[ "$MODE" == "plan" ]]; then
	WORKER_PROMPT="${WORKER_PROMPT}

Workflow:
1. Run 'yx ls' to see available tasks
2. Pick a task, read its context with 'yx context --show <name>'
3. Set it to wip: 'yx state <name> wip'
4. Report status: echo \"wip: starting plan\" | yx field <name> agent-status
5. Analyze the codebase, understand the problem, and write a detailed plan
6. Save the plan where it makes sense (e.g. a markdown file, or in yx context)
7. Report: echo \"blocked: plan ready for review\" | yx field <name> agent-status
8. STOP and wait — do NOT implement. Your job is to plan, not build.

Focus on the tasks assigned to you. Do not modify tasks outside your scope."
else
	WORKER_PROMPT="${WORKER_PROMPT}

Workflow:
1. Run 'yx ls' to see available tasks
2. Pick a task, read its context with 'yx context --show <name>'
3. Set it to wip: 'yx state <name> wip'
4. Report status: echo \"wip: starting\" | yx field <name> agent-status
5. Do the work (update agent-status as you make progress)
6. When done: 'yx done <name>' then echo \"done: <summary>\" | yx field <name> agent-status
7. If blocked: echo \"blocked: <reason>\" | yx field <name> agent-status

Focus on the tasks assigned to you. Do not modify tasks outside your scope."
fi

# Write the prompt to a file and create a wrapper script that calls opencode with it.
# This avoids multiline string issues in the KDL layout.
WORKER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/worker-XXXXXX")"

PROMPT_FILE="${WORKER_DIR}/prompt.txt"
WRAPPER="${WORKER_DIR}/run.sh"

printf '%s' "$WORKER_PROMPT" >"$PROMPT_FILE"

# The wrapper reads the prompt, runs opencode, then cleans up the temp dir.
cat >"$WRAPPER" <<WRAPPER_EOF
#!/usr/bin/env bash
PROMPT="\$(cat "${PROMPT_FILE}")"
rm -rf "${WORKER_DIR}"
exec opencode --prompt "\$PROMPT" --agent ${MODE}
WRAPPER_EOF
chmod +x "$WRAPPER"

# Create a temporary layout file for the worker tab.
# Zellij 0.43+ requires a layout to run a command in a new tab.
WORKER_LAYOUT="${WORKER_DIR}/layout.kdl"

cat >"$WORKER_LAYOUT" <<LAYOUT_EOF
layout {
    tab name="${DISPLAY_NAME}" cwd="${CWD}" {
        pane size=1 borderless=true {
            plugin location="compact-bar"
        }
        pane size="67%" name="opencode (${MODE})" focus=true {
            command "bash"
            args "${WRAPPER}" "${PROMPT_FILE}"
        }
        pane size="33%" name="shell: ${CWD}"
        pane size=2 borderless=true {
            plugin location="status-bar"
        }
    }
}
LAYOUT_EOF

# Spawn the worker in a new Zellij tab
zellij action new-tab --layout "$WORKER_LAYOUT" --name "$DISPLAY_NAME" --cwd "$CWD"

# Return focus to the previous tab (the orchestrator that called this script)
sleep 0.3
zellij action go-to-previous-tab

echo "Spawned ${SHAVER_NAME} (${TAB_NAME}) in ${CWD}"

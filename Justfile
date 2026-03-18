# yakthang Justfile
# Build and install yakthang tools.

# Install directories — override with env vars, no interactive prompts
BIN_DIR    := env_var_or_default("YAKTHANG_BIN",    env_var_or_default("YAKTHANG_PREFIX", env_var("HOME") + "/.local") + "/bin")
CONFIG_DIR := env_var_or_default("YAKTHANG_CONFIG", env_var_or_default("XDG_CONFIG_HOME", env_var("HOME") + "/.config") + "/yakthang")
CLAUDE_DIR := env_var_or_default("YAKTHANG_CLAUDE", env_var("HOME") + "/.claude")

# Zellij plugin dir — discovered at load time (no env var override; use zellij --data-dir if needed)
ZELLIJ_PLUGIN_DIR := `zellij setup --check 2>/dev/null | grep 'PLUGIN DIR' | awk '{print $NF}'`

default: build

# ---------------------------------------------------------------------------
# Build group (independent — safe to run with just --parallel)
# ---------------------------------------------------------------------------

# Build all tools
build: build-yx build-yak-box build-yak-map

# Build yx (Rust)
build-yx:
    cd src/yaks && cargo build --release

# Build yak-box (Go)
build-yak-box:
    cd src/yak-box && go build -ldflags "-X main.version=$(git describe --tags --always --dirty)" -o yak-box .

# Build yak-map WASM plugin (Rust/WASM)
build-yak-map:
    cd src/yak-map && cargo build --target wasm32-wasip1 --release

# ---------------------------------------------------------------------------
# Install group
# ---------------------------------------------------------------------------

# Build and install all components
install: install-yx install-yak-box install-yak-map install-agent install-skills install-config install-launcher

# Build and install yx
install-yx: build-yx
    mkdir -p "{{BIN_DIR}}"
    cp src/yaks/target/release/yx "{{BIN_DIR}}/yx"
    @echo "✓ yx → {{BIN_DIR}}/yx"

# Build and install yak-box
install-yak-box: build-yak-box
    mkdir -p "{{BIN_DIR}}"
    cp src/yak-box/yak-box "{{BIN_DIR}}/yak-box"
    @echo "✓ yak-box → {{BIN_DIR}}/yak-box"

# Build and install yak-map WASM plugin
install-yak-map: build-yak-map
    mkdir -p "{{ZELLIJ_PLUGIN_DIR}}"
    cp src/yak-map/target/wasm32-wasip1/release/yak-map.wasm "{{ZELLIJ_PLUGIN_DIR}}/yak-map.wasm"
    @echo "✓ yak-map.wasm → {{ZELLIJ_PLUGIN_DIR}}/yak-map.wasm"

# Install yakob.md agent definition
install-agent:
    mkdir -p "{{CLAUDE_DIR}}/agents"
    cp agents/yakob.md "{{CLAUDE_DIR}}/agents/yakob.md"
    @echo "✓ yakob.md → {{CLAUDE_DIR}}/agents/yakob.md"

# Install yak-* skill directories
install-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{CLAUDE_DIR}}/skills"
    for skill_dir in skills/yak-*/; do
        skill=$(basename "$skill_dir")
        cp -r "$skill_dir" "{{CLAUDE_DIR}}/skills/$skill"
        echo "✓ $skill → {{CLAUDE_DIR}}/skills/$skill"
    done

# Install orchestrator config
install-config:
    mkdir -p "{{CONFIG_DIR}}"
    cp yakstead/orchestrator.kdl "{{CONFIG_DIR}}/orchestrator.kdl"
    @echo "✓ orchestrator.kdl → {{CONFIG_DIR}}/orchestrator.kdl"

# Install yakthang launcher script
install-launcher:
    mkdir -p "{{BIN_DIR}}"
    cp bin/yakthang "{{BIN_DIR}}/yakthang"
    chmod +x "{{BIN_DIR}}/yakthang"
    @echo "✓ yakthang → {{BIN_DIR}}/yakthang"

# ---------------------------------------------------------------------------
# Doctor group
# ---------------------------------------------------------------------------

# Check all installed components
doctor: check-yx check-yak-box check-yakthang check-agent check-skills check-yak-map check-config

# Check yx binary
check-yx:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -f "{{BIN_DIR}}/yx" ]] && command -v yx &>/dev/null; then
        echo "✓ yx             → $(command -v yx)"
    elif [[ -f "{{BIN_DIR}}/yx" ]]; then
        echo "✗ yx             → {{BIN_DIR}}/yx (not on PATH)"
        echo "  fix: export PATH=\"{{BIN_DIR}}:\$PATH\""
        exit 1
    else
        echo "✗ yx             → not installed"
        echo "  fix: just install-yx"
        exit 1
    fi

# Check yak-box binary
check-yak-box:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -f "{{BIN_DIR}}/yak-box" ]] && command -v yak-box &>/dev/null; then
        echo "✓ yak-box        → $(command -v yak-box)"
    elif [[ -f "{{BIN_DIR}}/yak-box" ]]; then
        echo "✗ yak-box        → {{BIN_DIR}}/yak-box (not on PATH)"
        echo "  fix: export PATH=\"{{BIN_DIR}}:\$PATH\""
        exit 1
    else
        echo "✗ yak-box        → not installed"
        echo "  fix: just install-yak-box"
        exit 1
    fi

# Check yakthang launcher
check-yakthang:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -f "{{BIN_DIR}}/yakthang" ]] && command -v yakthang &>/dev/null; then
        echo "✓ yakthang       → $(command -v yakthang)"
    elif [[ -f "{{BIN_DIR}}/yakthang" ]]; then
        echo "✗ yakthang       → {{BIN_DIR}}/yakthang (not on PATH)"
        echo "  fix: export PATH=\"{{BIN_DIR}}:\$PATH\""
        exit 1
    else
        echo "✗ yakthang       → not installed"
        echo "  fix: just install-launcher"
        exit 1
    fi

# Check yakob.md agent definition
check-agent:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -s "{{CLAUDE_DIR}}/agents/yakob.md" ]]; then
        echo "✓ yakob.md       → {{CLAUDE_DIR}}/agents/yakob.md"
    else
        echo "✗ yakob.md       → not found at {{CLAUDE_DIR}}/agents/yakob.md"
        echo "  fix: just install-agent (or set YAKTHANG_CLAUDE to override location)"
        exit 1
    fi

# Check yak-* skill directories
check-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    failed=0
    for skill_dir in skills/yak-*/; do
        skill=$(basename "$skill_dir")
        if [[ -d "{{CLAUDE_DIR}}/skills/$skill" ]]; then
            echo "✓ skills/$skill"
        else
            echo "✗ skills/$skill  → not found"
            echo "  fix: just install-skills"
            failed=1
        fi
    done
    exit $failed

# Check yak-map WASM plugin
check-yak-map:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -f "{{ZELLIJ_PLUGIN_DIR}}/yak-map.wasm" ]]; then
        echo "✓ yak-map.wasm   → {{ZELLIJ_PLUGIN_DIR}}/yak-map.wasm"
    else
        echo "✗ yak-map.wasm   → not found at {{ZELLIJ_PLUGIN_DIR}}/yak-map.wasm"
        echo "  fix: just install-yak-map"
        exit 1
    fi

# Check orchestrator config
check-config:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -f "{{CONFIG_DIR}}/orchestrator.kdl" ]]; then
        echo "✓ orchestrator.kdl → {{CONFIG_DIR}}/orchestrator.kdl"
    else
        echo "✗ orchestrator.kdl → not found at {{CONFIG_DIR}}/orchestrator.kdl"
        echo "  fix: just install-config (or set YAKTHANG_CONFIG to override location)"
        exit 1
    fi

# ---------------------------------------------------------------------------
# Other
# ---------------------------------------------------------------------------

# Launch yakthang session (installs first)
launch: install
    yakthang

# Clean all build artifacts
clean:
    cd src/yaks && cargo clean
    cd src/yak-map && cargo clean
    rm -f src/yak-box/yak-box

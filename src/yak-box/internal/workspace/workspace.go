// Package workspace provides utilities for finding the workspace root directory.
package workspace

import (
	"os/exec"
	"runtime"
	"strings"
)

// FindRoot finds the git repository root directory by running `git rev-parse --show-toplevel`.
// It returns the root directory path or an error if the command fails.
// On macOS, paths under /private (e.g. /private/var/...) are normalized to /var/... so that
// all callers (sessions, config, runtime) agree on a single canonical root.
func FindRoot() (string, error) {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	root := strings.TrimSpace(string(output))
	if runtime.GOOS == "darwin" && strings.HasPrefix(root, "/private") {
		root = strings.TrimPrefix(root, "/private")
	}
	return root, nil
}

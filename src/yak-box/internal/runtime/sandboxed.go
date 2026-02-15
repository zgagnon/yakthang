package runtime

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/yakthang/yakbox/pkg/types"
)

const (
	containerNamePrefix = "yak-worker-"
	workerCacheDir      = ".yak-boxes"
	networkName         = "yak-workers"
)

// GetResourceProfile returns the resource profile for a given name
func GetResourceProfile(name string) types.ResourceProfile {
	switch name {
	case "light":
		return types.ResourceProfile{
			Name:   "light",
			CPUs:   "0.5",
			Memory: "1g",
			PIDs:   256,
			Tmpfs: map[string]string{
				"/tmp":                   "size=1g,exec,uid=1000,gid=1000",
				"/home/worker":           "size=512m,exec,uid=1000,gid=1000",
				"/home/worker/.cache":    "size=512m,exec,uid=1000,gid=1000",
			},
		}
	case "heavy":
		return types.ResourceProfile{
			Name:   "heavy",
			CPUs:   "2.0",
			Memory: "4g",
			PIDs:   1024,
			Tmpfs: map[string]string{
				"/tmp":                   "size=2g,exec,uid=1000,gid=1000",
				"/home/worker":           "size=1g,exec,uid=1000,gid=1000",
				"/home/worker/.cache":    "size=1g,exec,uid=1000,gid=1000",
			},
		}
	default:
		return types.ResourceProfile{
			Name:   "default",
			CPUs:   "1.0",
			Memory: "2g",
			PIDs:   512,
			Tmpfs: map[string]string{
				"/tmp":                   "size=1g,exec,uid=1000,gid=1000",
				"/home/worker":           "size=512m,exec,uid=1000,gid=1000",
				"/home/worker/.cache":    "size=512m,exec,uid=1000,gid=1000",
			},
		}
	}
}

// DetectRuntime detects the available runtime (sandboxed/docker or native/zellij)
func DetectRuntime() string {
	if _, err := exec.LookPath("docker"); err == nil {
		if err := exec.Command("docker", "ps").Run(); err == nil {
			return "sandboxed"
		}
	}
	if _, err := exec.LookPath("zellij"); err == nil {
		return "native"
	}
	return "unknown"
}

// GetNetworkMode returns the network mode for Docker
func GetNetworkMode() string {
	cmd := exec.Command("docker", "network", "inspect", networkName)
	if err := cmd.Run(); err != nil {
		return "bridge"
	}
	return networkName
}

// SpawnSandboxedWorker spawns a worker in a Docker container
func SpawnSandboxedWorker(worker *types.Worker, persona *types.Persona, prompt string, profile types.ResourceProfile) error {
	containerName := containerNamePrefix + worker.Name
	networkMode := GetNetworkMode()
	workspaceRoot, err := findWorkspaceRoot()
	if err != nil {
		return fmt.Errorf("failed to find workspace root: %w", err)
	}

	// Create worker directory for temp files
	workerDir, err := os.MkdirTemp("", "worker-*")
	if err != nil {
		return fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(workerDir)

	// Write prompt to file
	promptFile := filepath.Join(workerDir, "prompt.txt")
	if err := os.WriteFile(promptFile, []byte(prompt), 0644); err != nil {
		return fmt.Errorf("failed to write prompt file: %w", err)
	}

	// Create inner script that runs inside container
	innerScript := filepath.Join(workerDir, "inner.sh")
	innerContent := `#!/usr/bin/env bash
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/yakob/yakthang}"
COST_DIR="${WORKSPACE_ROOT}/.worker-costs"
mkdir -p "$COST_DIR"

PROMPT="$(cat /opt/worker/prompt.txt)"
opencode --prompt "$PROMPT" --agent "$1"
EXIT_CODE=$?

WORKER="${WORKER_NAME:-unknown}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
SID="$(opencode session list 2>/dev/null | tail -1 | awk '{print $1}')"
if [[ -n "$SID" && "$SID" != "Session" ]]; then
  opencode export "$SID" > "${COST_DIR}/${WORKER}-${TS}.json" 2>/dev/null
fi
opencode stats --models > "${COST_DIR}/${WORKER}-${TS}.stats.txt" 2>/dev/null
exit $EXIT_CODE
`
	if err := os.WriteFile(innerScript, []byte(innerContent), 0755); err != nil {
		return fmt.Errorf("failed to write inner script: %w", err)
	}

	// Build docker run command
	dockerArgs := []string{
		"run", "-it", "--rm",
		"--name", containerName,
		"--user", fmt.Sprintf("%d:%d", os.Getuid(), os.Getgid()),
		"--network", networkMode,
		"--security-opt", "no-new-privileges",
		"--cap-drop", "ALL",
		"--read-only",
		"--tmpfs", "/tmp:rw,exec,size=2g",
		"--tmpfs", "/home/worker:rw,exec,size=1g",
		"--cpus", profile.CPUs,
		"--memory", profile.Memory,
		"--pids-limit", fmt.Sprintf("%d", profile.PIDs),
		"--stop-timeout", "7200",
		"-v", fmt.Sprintf("%s:%s:rw", workspaceRoot, workspaceRoot),
		"-v", fmt.Sprintf("%s:%s:rw", worker.YakPath, worker.YakPath),
		"-v", fmt.Sprintf("%s:/opt/worker/prompt.txt:ro", promptFile),
		"-v", fmt.Sprintf("%s:/opt/worker/start.sh:ro", innerScript),
		"-w", worker.CWD,
		"-e", "HOME=/home/worker",
		"-e", fmt.Sprintf("OPENCODE_API_KEY=%s", os.Getenv("OPENCODE_API_KEY")),
		"-e", fmt.Sprintf("WORKER_NAME=%s", persona.Name),
		"-e", fmt.Sprintf("WORKER_EMOJI=%s", persona.Emoji),
		"-e", fmt.Sprintf("YAK_PATH=%s", worker.YakPath),
		"yak-worker:latest",
		"bash", "/opt/worker/start.sh", "build",
	}

	cmd := exec.Command("docker", dockerArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run docker container: %w", err)
	}

	return nil
}

// StopSandboxedWorker stops a sandboxed worker with timeout
func StopSandboxedWorker(name string, timeout time.Duration) error {
	containerName := containerNamePrefix + name

	// Check if container exists
	cmd := exec.Command("docker", "ps", "-a", "--filter", fmt.Sprintf("name=^%s$", containerName), "--format", "{{.Names}}")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to check container: %w", err)
	}

	if strings.TrimSpace(string(output)) == "" {
		return fmt.Errorf("container %s not found", containerName)
	}

	// Stop container
	stopCmd := exec.Command("docker", "stop", "-t", fmt.Sprintf("%d", int(timeout.Seconds())), containerName)
	if err := stopCmd.Run(); err != nil {
		return fmt.Errorf("failed to stop container: %w", err)
	}

	// Remove container
	rmCmd := exec.Command("docker", "rm", containerName)
	if err := rmCmd.Run(); err != nil {
		return fmt.Errorf("failed to remove container: %w", err)
	}

	return nil
}

// ListRunningContainers returns list of running worker containers
func ListRunningContainers() ([]string, error) {
	cmd := exec.Command("docker", "ps", "--filter", "name=yak-worker-", "--format", "{{.Names}}")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var containers []string
	for _, line := range strings.Split(strings.TrimSpace(string(output)), "\n") {
		if line != "" {
			containers = append(containers, line)
		}
	}
	return containers, nil
}

// ListAllContainers returns list of all worker containers (running and stopped)
func ListAllContainers() ([]string, error) {
	cmd := exec.Command("docker", "ps", "-a", "--filter", "name=yak-worker-", "--format", "{{.Names}}")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var containers []string
	for _, line := range strings.Split(strings.TrimSpace(string(output)), "\n") {
		if line != "" {
			containers = append(containers, line)
		}
	}
	return containers, nil
}

func findWorkspaceRoot() (string, error) {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

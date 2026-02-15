package runtime

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const devcontainerPath = ".devcontainer"
const workerImageName = "yak-worker:latest"

func IsDevcontainerDirty() (bool, error) {
	workspaceRoot, err := findWorkspaceRoot()
	if err != nil {
		return false, fmt.Errorf("failed to find workspace root: %w", err)
	}

	devcontainerDir := workspaceRoot + "/" + devcontainerPath
	info, err := os.Stat(devcontainerDir)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	if !info.IsDir() {
		return false, nil
	}

	cmd := exec.Command("git", "status", "--porcelain", devcontainerPath)
	cmd.Dir = workspaceRoot
	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check git status: %w", err)
	}

	return strings.TrimSpace(string(output)) != "", nil
}

func RebuildDevcontainer() error {
	workspaceRoot, err := findWorkspaceRoot()
	if err != nil {
		return fmt.Errorf("failed to find workspace root: %w", err)
	}

	fmt.Println("Rebuilding yak-worker image due to .devcontainer changes...")

	cmd := exec.Command("docker", "build", "-t", "yak-worker:latest", "-f", "Dockerfile", ".")
	cmd.Dir = workspaceRoot + "/" + devcontainerPath
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to rebuild docker image: %w", err)
	}

	fmt.Println("Image rebuilt successfully")
	return nil
}

// EnsureDevcontainer ensures the Docker image exists and is up-to-date
func EnsureDevcontainer() error {
	// Check if image already exists
	if imageExists, err := ImageExists(); err == nil && imageExists {
		// Image exists, check if rebuild is needed due to changes
		dirty, err := IsDevcontainerDirty()
		if err != nil {
			return fmt.Errorf("failed to check devcontainer status: %w", err)
		}
		if dirty {
			return RebuildDevcontainer()
		}
		return nil
	}

	// Image doesn't exist, build it
	fmt.Println("Building yak-worker image for the first time...")
	return RebuildDevcontainer()
}

// ImageExists checks if the yak-worker Docker image exists locally
func ImageExists() (bool, error) {
	cmd := exec.Command("docker", "image", "inspect", workerImageName)
	err := cmd.Run()
	if err == nil {
		return true, nil
	}
	// Check if it's a "not found" error
	if exitErr, ok := err.(*exec.ExitError); ok {
		if exitErr.ExitCode() == 1 {
			return false, nil
		}
	}
	return false, err
}

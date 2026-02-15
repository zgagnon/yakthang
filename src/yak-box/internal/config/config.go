package config

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type Config struct {
	WorkspaceRoot string
	YakPath       string
	MetadataDir   string
}

func LoadConfig() (*Config, error) {
	root, err := findWorkspaceRoot()
	if err != nil {
		return nil, err
	}

	yakPath := os.Getenv("YAK_PATH")
	if yakPath == "" {
		yakPath = filepath.Join(root, ".yaks")
	}

	return &Config{
		WorkspaceRoot: root,
		YakPath:       yakPath,
		MetadataDir:   filepath.Join(root, ".yak-boxes"),
	}, nil
}

func findWorkspaceRoot() (string, error) {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

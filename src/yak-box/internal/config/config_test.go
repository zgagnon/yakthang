package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadConfig_FromGitRepo(t *testing.T) {
	// Run from repo root so workspace.FindRoot() succeeds
	restore := setEnv("YAK_PATH", "")
	defer restore()

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig: %v", err)
	}
	if cfg.WorkspaceRoot == "" {
		t.Error("WorkspaceRoot should be set")
	}
	if cfg.YakPath == "" {
		t.Error("YakPath should be set")
	}
	expectedYak := filepath.Join(cfg.WorkspaceRoot, ".yaks")
	if cfg.YakPath != expectedYak {
		t.Errorf("YakPath expected %q when YAK_PATH unset, got %q", expectedYak, cfg.YakPath)
	}
	if cfg.MetadataDir != filepath.Join(cfg.WorkspaceRoot, ".yak-boxes") {
		t.Errorf("MetadataDir should be <root>/.yak-boxes, got %q", cfg.MetadataDir)
	}
}

func TestLoadConfig_WithYakPathEnv(t *testing.T) {
	customYak := "/custom/.yaks"
	restore := setEnv("YAK_PATH", customYak)
	defer restore()

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig: %v", err)
	}
	if cfg.YakPath != customYak {
		t.Errorf("YakPath should respect YAK_PATH env, got %q", cfg.YakPath)
	}
}

func setEnv(key, value string) func() {
	old := os.Getenv(key)
	os.Setenv(key, value)
	return func() { os.Setenv(key, old) }
}

package runtime

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDirExists_Exists(t *testing.T) {
	tmp := t.TempDir()
	if !dirExists(tmp) {
		t.Error("dirExists should be true for existing directory")
	}
}

func TestDirExists_NotExists(t *testing.T) {
	if dirExists("/nonexistent-path-12345") {
		t.Error("dirExists should be false for non-existent path")
	}
}

func TestDirExists_FileNotDir(t *testing.T) {
	tmp := t.TempDir()
	f := filepath.Join(tmp, "file")
	if err := os.WriteFile(f, []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}
	if dirExists(f) {
		t.Error("dirExists should be false for regular file")
	}
}

func TestRebuildDevcontainer_OutsideGitRepo(t *testing.T) {
	// From a non-git directory, RebuildDevcontainer should fail with "find workspace root"
	dir := t.TempDir()
	oldWd, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(oldWd) }()

	err := RebuildDevcontainer()
	if err == nil {
		t.Error("RebuildDevcontainer should fail when not in a git repo")
	}
	if err != nil && !strings.Contains(err.Error(), "workspace root") {
		t.Errorf("expected workspace root error, got: %v", err)
	}
}

func TestImageExists_ReturnsBoolAndNilOrErr(t *testing.T) {
	// ImageExists runs docker; we only check it doesn't panic and returns (bool, error)
	exists, err := ImageExists()
	_ = exists
	if err != nil && exists {
		t.Error("when err != nil, exists should be false")
	}
}

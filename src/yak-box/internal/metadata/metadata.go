package metadata

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/yakthang/yakbox/pkg/types"
)

const metadataDir = ".yak-boxes"

type WorkerMetadata struct {
	ShaverName        string    `json:"shaver_name"`
	ShaverEmoji       string    `json:"shaver_emoji"`
	DisplayName       string    `json:"display_name"`
	TabName           string    `json:"tab_name"`
	ContainerName     string    `json:"container_name"`
	Runtime           string    `json:"runtime"`
	CWD               string    `json:"cwd"`
	SpawnedAt         time.Time `json:"spawned_at"`
	YakPath           string    `json:"yak_path"`
	ZellijSessionName string    `json:"zellij_session_name"`
	Tasks             []string  `json:"tasks"`
}

func getMetadataPath() (string, error) {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func ensureMetadataDir() error {
	root, err := getMetadataPath()
	if err != nil {
		return err
	}
	dir := filepath.Join(root, metadataDir)
	return os.MkdirAll(dir, 0755)
}

// SaveMetadata saves worker metadata to .yak-boxes/
func SaveMetadata(worker *types.Worker, persona *types.Persona, tasks []string) error {
	if err := ensureMetadataDir(); err != nil {
		return fmt.Errorf("failed to create metadata dir: %w", err)
	}

	root, err := getMetadataPath()
	if err != nil {
		return fmt.Errorf("failed to get workspace root: %w", err)
	}

	metadata := WorkerMetadata{
		ShaverName:        persona.Name,
		ShaverEmoji:       persona.Emoji,
		DisplayName:       worker.DisplayName,
		TabName:           worker.Name,
		ContainerName:     worker.ContainerName,
		Runtime:           worker.Runtime,
		CWD:               worker.CWD,
		SpawnedAt:         worker.SpawnedAt,
		YakPath:           worker.YakPath,
		ZellijSessionName: os.Getenv("ZELLIJ_SESSION_NAME"),
		Tasks:             tasks,
	}

	metadataFile := filepath.Join(root, metadataDir, fmt.Sprintf("%s.meta", worker.Name))
	data, err := json.MarshalIndent(metadata, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	if err := os.WriteFile(metadataFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write metadata file: %w", err)
	}

	return nil
}

// LoadMetadata loads worker metadata from .yak-boxes/
func LoadMetadata(name string) (*WorkerMetadata, error) {
	root, err := getMetadataPath()
	if err != nil {
		return nil, fmt.Errorf("failed to get workspace root: %w", err)
	}

	metadataFile := filepath.Join(root, metadataDir, fmt.Sprintf("%s.meta", name))
	data, err := os.ReadFile(metadataFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read metadata file: %w", err)
	}

	var metadata WorkerMetadata
	if err := json.Unmarshal(data, &metadata); err != nil {
		return nil, fmt.Errorf("failed to unmarshal metadata: %w", err)
	}

	return &metadata, nil
}

// DeleteMetadata deletes worker metadata from .yak-boxes/
func DeleteMetadata(name string) error {
	root, err := getMetadataPath()
	if err != nil {
		return fmt.Errorf("failed to get workspace root: %w", err)
	}

	metadataFile := filepath.Join(root, metadataDir, fmt.Sprintf("%s.meta", name))
	if err := os.Remove(metadataFile); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to delete metadata file: %w", err)
	}

	return nil
}

// ListMetadata returns all worker metadata files
func ListMetadata() ([]string, error) {
	root, err := getMetadataPath()
	if err != nil {
		return nil, fmt.Errorf("failed to get workspace root: %w", err)
	}

	dir := filepath.Join(root, metadataDir)
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return []string{}, nil
		}
		return nil, err
	}

	var names []string
	for _, entry := range entries {
		if !entry.IsDir() && filepath.Ext(entry.Name()) == ".meta" {
			names = append(names, entry.Name()[:len(entry.Name())-5])
		}
	}

	return names, nil
}

package metadata

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/yakthang/yakbox/pkg/types"
)

func TestSaveMetadata(t *testing.T) {
	worker := &types.Worker{
		Name:          "test-worker",
		DisplayName:   "Test Worker",
		ContainerName: "yakbox-test",
		Runtime:       "sandboxed",
		CWD:           "/tmp/test",
		YakPath:       ".yaks",
		Tasks:         []string{"task1"},
		SpawnedAt:     time.Now(),
	}

	persona := types.Persona{
		Name:        "Yakriel",
		Emoji:       "🦬🪒",
		Trait:       "Precise",
		Personality: "Test personality",
	}

	err := SaveMetadata(worker, &persona, []string{"task1"})
	assert.NoError(t, err)
}

func TestLoadMetadata(t *testing.T) {
	worker, err := LoadMetadata("test-worker")
	assert.NoError(t, err)
	assert.NotNil(t, worker)
	assert.Equal(t, "Yakriel", worker.ShaverName)
	assert.Equal(t, "test-worker", worker.TabName)
}

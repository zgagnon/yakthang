package cmd

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSpawnFlags(t *testing.T) {
	// Verify required flags are registered
	assert.NotNil(t, spawnCmd.Flags().Lookup("cwd"))
	assert.NotNil(t, spawnCmd.Flags().Lookup("name"))

	// Verify optional flags are registered
	assert.NotNil(t, spawnCmd.Flags().Lookup("mode"))
	assert.NotNil(t, spawnCmd.Flags().Lookup("resources"))
	assert.NotNil(t, spawnCmd.Flags().Lookup("yaks"))
	assert.NotNil(t, spawnCmd.Flags().Lookup("yak-path"))
	assert.NotNil(t, spawnCmd.Flags().Lookup("runtime"))

	// Verify flag defaults
	mode, _ := spawnCmd.Flags().GetString("mode")
	assert.Equal(t, "build", mode)

	resources, _ := spawnCmd.Flags().GetString("resources")
	assert.Equal(t, "default", resources)

	yakPath, _ := spawnCmd.Flags().GetString("yak-path")
	assert.Equal(t, ".yaks", yakPath)

	runtime, _ := spawnCmd.Flags().GetString("runtime")
	assert.Equal(t, "auto", runtime)
}

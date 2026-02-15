package cmd

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestStopFlags(t *testing.T) {
	// Verify required flags are registered
	assert.NotNil(t, stopCmd.Flags().Lookup("name"))

	// Verify optional flags are registered
	assert.NotNil(t, stopCmd.Flags().Lookup("timeout"))
	assert.NotNil(t, stopCmd.Flags().Lookup("force"))
	assert.NotNil(t, stopCmd.Flags().Lookup("dry-run"))

	// Verify flag defaults
	timeout, _ := stopCmd.Flags().GetString("timeout")
	assert.Equal(t, "30s", timeout)

	force, _ := stopCmd.Flags().GetBool("force")
	assert.False(t, force)

	dryRun, _ := stopCmd.Flags().GetBool("dry-run")
	assert.False(t, dryRun)
}

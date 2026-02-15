package cmd

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCheckFlags(t *testing.T) {
	// Verify optional flags are registered
	assert.NotNil(t, checkCmd.Flags().Lookup("blocked"))
	assert.NotNil(t, checkCmd.Flags().Lookup("wip"))
	assert.NotNil(t, checkCmd.Flags().Lookup("prefix"))

	// Verify flag defaults
	blocked, _ := checkCmd.Flags().GetBool("blocked")
	assert.False(t, blocked)

	wip, _ := checkCmd.Flags().GetBool("wip")
	assert.False(t, wip)

	prefix, _ := checkCmd.Flags().GetString("prefix")
	assert.Equal(t, "", prefix)
}

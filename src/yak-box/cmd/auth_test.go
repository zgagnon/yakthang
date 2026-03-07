package cmd

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestAuthCommandExists(t *testing.T) {
	assert.NotNil(t, authCmd)
	assert.Equal(t, "auth", authCmd.Use)

	var names []string
	for _, subcmd := range authCmd.Commands() {
		names = append(names, subcmd.Name())
	}
	assert.Contains(t, names, "login")
	assert.Contains(t, names, "status")
}

func TestAuthLoginFlags(t *testing.T) {
	assert.NotNil(t, authLoginCmd.Flags().Lookup("shaver"))
}

func TestAuthLoginRequiresShaver(t *testing.T) {
	err := runAuthLogin("")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "--shaver is required")
}

func TestAuthStatusFlags(t *testing.T) {
	assert.NotNil(t, authStatusCmd.Flags().Lookup("shaver"))
}

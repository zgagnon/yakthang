package persona

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetRandomPersona(t *testing.T) {
	persona := GetRandomPersona()

	assert.NotEmpty(t, persona.Name)
	assert.NotEmpty(t, persona.Emoji)
	assert.NotEmpty(t, persona.Trait)
	assert.NotEmpty(t, persona.Personality)
}

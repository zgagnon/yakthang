package devcontainer

import (
	"testing"
)

func TestSubstitute_StringNoVars(t *testing.T) {
	ctx := &SubstituteContext{LocalEnv: map[string]string{"FOO": "bar"}}
	out := Substitute(ctx, "hello")
	if out != "hello" {
		t.Errorf("expected %q, got %q", "hello", out)
	}
}

func TestSubstitute_LocalEnv(t *testing.T) {
	ctx := &SubstituteContext{
		LocalEnv: map[string]string{"MY_VAR": "myvalue"},
	}
	out := Substitute(ctx, "prefix ${localEnv:MY_VAR} suffix")
	if out != "prefix myvalue suffix" {
		t.Errorf("expected prefix myvalue suffix, got %q", out)
	}
}

func TestSubstitute_LocalEnvWithDefault(t *testing.T) {
	ctx := &SubstituteContext{LocalEnv: map[string]string{}}
	out := Substitute(ctx, "value: ${localEnv:MISSING:default}")
	if out != "value: default" {
		t.Errorf("expected value: default, got %q", out)
	}
}

func TestSubstitute_ContainerEnv(t *testing.T) {
	ctx := &SubstituteContext{
		ContainerEnv: map[string]string{"CONTAINER_VAR": "cval"},
	}
	out := Substitute(ctx, "${containerEnv:CONTAINER_VAR}")
	if out != "cval" {
		t.Errorf("expected cval, got %q", out)
	}
}

func TestSubstitute_LocalWorkspaceFolder(t *testing.T) {
	ctx := &SubstituteContext{LocalWorkspaceFolder: "/home/user/proj"}
	out := Substitute(ctx, "${localWorkspaceFolder}/src")
	if out != "/home/user/proj/src" {
		t.Errorf("expected /home/user/proj/src, got %q", out)
	}
}

func TestSubstitute_ArrayRecursion(t *testing.T) {
	ctx := &SubstituteContext{LocalEnv: map[string]string{"X": "y"}}
	out := Substitute(ctx, []interface{}{"a", "${localEnv:X}", "b"})
	sl, ok := out.([]interface{})
	if !ok || len(sl) != 3 {
		t.Fatalf("expected [a y b], got %#v", out)
	}
	if sl[0] != "a" || sl[1] != "y" || sl[2] != "b" {
		t.Errorf("expected [a y b], got %#v", sl)
	}
}

func TestSubstitute_MapRecursion(t *testing.T) {
	ctx := &SubstituteContext{LocalWorkspaceFolder: "/ws"}
	out := Substitute(ctx, map[string]interface{}{
		"path": "${localWorkspaceFolder}/app",
		"num":  42,
	})
	m, ok := out.(map[string]interface{})
	if !ok {
		t.Fatalf("expected map, got %#v", out)
	}
	if m["path"] != "/ws/app" {
		t.Errorf("expected path /ws/app, got %q", m["path"])
	}
	if m["num"] != 42 {
		t.Errorf("expected num 42, got %v", m["num"])
	}
}

func TestSubstitute_PreservesNonString(t *testing.T) {
	ctx := &SubstituteContext{}
	if Substitute(ctx, 42) != 42 {
		t.Error("number should be preserved")
	}
	if Substitute(ctx, true) != true {
		t.Error("bool should be preserved")
	}
	if Substitute(ctx, nil) != nil {
		t.Error("nil should be preserved")
	}
}

func TestSubstitute_UnknownVariablePreserved(t *testing.T) {
	ctx := &SubstituteContext{}
	out := Substitute(ctx, "keep ${unknown:var} as-is")
	if out != "keep ${unknown:var} as-is" {
		t.Errorf("unknown variable should be preserved, got %q", out)
	}
}

func TestSubstitute_DevContainerID(t *testing.T) {
	ctx := &SubstituteContext{
		Labels: map[string]string{"a": "1", "b": "2"},
	}
	out := Substitute(ctx, "${devcontainerId}")
	s, ok := out.(string)
	if !ok || len(s) == 0 {
		t.Errorf("devcontainerId should be non-empty string, got %#v", out)
	}
	// Same labels should produce same ID
	out2 := Substitute(ctx, "${devcontainerId}")
	if out2 != s {
		t.Error("devcontainerId should be deterministic")
	}
}

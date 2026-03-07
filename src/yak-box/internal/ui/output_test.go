package ui

import (
	"bytes"
	"io"
	"os"
	"testing"
)

func TestSuccess(t *testing.T) {
	// Redirect stderr to avoid coloring terminal output in tests
	old := os.Stderr
	r, w, _ := os.Pipe()
	os.Stderr = w
	defer func() { os.Stderr = old }()

	Success("ok %s\n", "done")
	w.Close()
	var buf bytes.Buffer
	io.Copy(&buf, r)
	if buf.Len() == 0 {
		t.Error("Success should write to stderr")
	}
}

func TestWarning(t *testing.T) {
	old := os.Stderr
	r, w, _ := os.Pipe()
	os.Stderr = w
	defer func() { os.Stderr = old }()

	Warning("warn %s\n", "msg")
	w.Close()
	var buf bytes.Buffer
	io.Copy(&buf, r)
	if buf.Len() == 0 {
		t.Error("Warning should write to stderr")
	}
}

func TestError(t *testing.T) {
	old := os.Stderr
	r, w, _ := os.Pipe()
	os.Stderr = w
	defer func() { os.Stderr = old }()

	Error("err %s\n", "msg")
	w.Close()
	var buf bytes.Buffer
	io.Copy(&buf, r)
	if buf.Len() == 0 {
		t.Error("Error should write to stderr")
	}
}

func TestInfo(t *testing.T) {
	old := os.Stderr
	r, w, _ := os.Pipe()
	os.Stderr = w
	defer func() { os.Stderr = old }()

	Info("info %s\n", "msg")
	w.Close()
	var buf bytes.Buffer
	io.Copy(&buf, r)
	if buf.Len() == 0 {
		t.Error("Info should write to stderr")
	}
}

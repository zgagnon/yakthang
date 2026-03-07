package ui

import (
	"bytes"
	"strings"
	"testing"
)

func TestPrintTable_Empty(t *testing.T) {
	var buf bytes.Buffer
	err := PrintTable(&buf, nil, nil)
	if err != nil {
		t.Fatalf("PrintTable: %v", err)
	}
	if buf.Len() != 0 {
		t.Errorf("empty table should produce no output, got %d bytes", buf.Len())
	}
}

func TestPrintTable_HeadersOnly(t *testing.T) {
	var buf bytes.Buffer
	err := PrintTable(&buf, []string{"A", "B", "C"}, nil)
	if err != nil {
		t.Fatalf("PrintTable: %v", err)
	}
	out := buf.String()
	if !strings.Contains(out, "A") || !strings.Contains(out, "B") || !strings.Contains(out, "C") {
		t.Errorf("headers should appear: %q", out)
	}
}

func TestPrintTable_WithRows(t *testing.T) {
	var buf bytes.Buffer
	headers := []string{"Name", "Count"}
	rows := [][]string{
		{"foo", "1"},
		{"bar", "2"},
	}
	err := PrintTable(&buf, headers, rows)
	if err != nil {
		t.Fatalf("PrintTable: %v", err)
	}
	out := buf.String()
	for _, h := range headers {
		if !strings.Contains(out, h) {
			t.Errorf("header %q missing from %q", h, out)
		}
	}
	for _, row := range rows {
		for _, cell := range row {
			if !strings.Contains(out, cell) {
				t.Errorf("cell %q missing from %q", cell, out)
			}
		}
	}
}

func TestPrintTable_SingleColumn(t *testing.T) {
	var buf bytes.Buffer
	err := PrintTable(&buf, []string{"X"}, [][]string{{"a"}, {"b"}})
	if err != nil {
		t.Fatalf("PrintTable: %v", err)
	}
	if !strings.Contains(buf.String(), "X") || !strings.Contains(buf.String(), "a") || !strings.Contains(buf.String(), "b") {
		t.Errorf("single column output: %q", buf.String())
	}
}

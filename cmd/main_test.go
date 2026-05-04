package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestRun_LoadPersonsError exercises the first error branch of run() — a
// non-existent personsDir surfaces a wrapped "load persons" error and
// terminates the pipeline before any face.NewRecognizer call. This is the
// only error branch unreachable from the integration suite, since the
// integration tests start from a known-good repo layout.
func TestRun_LoadPersonsError(t *testing.T) {
	err := run(
		"/nonexistent/persons",
		"models",
		"images",
		filepath.Join("fonts", "Roboto-Regular.ttf"),
	)
	if err == nil {
		t.Fatal("expected error from run() with non-existent personsDir, got nil")
	}
	if !strings.Contains(err.Error(), "load persons") {
		t.Errorf("expected error to be wrapped with 'load persons', got: %v", err)
	}
}

// TestRun_RecognizerInitError exercises the NewRecognizer error branch —
// LoadPersons succeeds against an empty (but existing) persons dir, then
// face.NewRecognizer fails on the bogus modelsDir, surfacing a wrapped
// "init face recognizer" error.
func TestRun_RecognizerInitError(t *testing.T) {
	tmp := t.TempDir()
	personsDir := filepath.Join(tmp, "persons")
	if err := os.MkdirAll(personsDir, 0o755); err != nil {
		t.Fatalf("mkdir persons: %v", err)
	}

	err := run(
		personsDir,
		"/nonexistent/models",
		"images",
		filepath.Join("fonts", "Roboto-Regular.ttf"),
	)
	if err == nil {
		t.Fatal("expected error from run() with non-existent modelsDir, got nil")
	}
	if !strings.Contains(err.Error(), "init face recognizer") {
		t.Errorf("expected error to be wrapped with 'init face recognizer', got: %v", err)
	}
}

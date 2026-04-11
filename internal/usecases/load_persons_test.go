package usecases

import (
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func TestLoadPersonsUseCase_Execute(t *testing.T) {
	t.Parallel()

	tmp := t.TempDir()

	// Layout under tmp:
	//   alice/a1.jpg
	//   alice/a2.jpg
	//   bob/b1.jpg
	//   loose.txt           <- non-dir, must be skipped
	mustWriteFile(t, filepath.Join(tmp, "alice", "a1.jpg"), []byte("fake-jpg-1"))
	mustWriteFile(t, filepath.Join(tmp, "alice", "a2.jpg"), []byte("fake-jpg-2"))
	mustWriteFile(t, filepath.Join(tmp, "bob", "b1.jpg"), []byte("fake-jpg-3"))
	mustWriteFile(t, filepath.Join(tmp, "loose.txt"), []byte("not-a-dir"))

	uc := NewLoadPersonsUseCase()
	persons, err := uc.Execute(tmp)
	if err != nil {
		t.Fatalf("Execute returned error: %v", err)
	}

	if len(persons) != 2 {
		t.Fatalf("expected 2 persons (alice, bob), got %d: %+v", len(persons), persons)
	}

	names := []string{}
	imageCountByName := map[string]int{}
	for _, p := range persons {
		names = append(names, p.Name)
		imageCountByName[p.Name] = len(p.ImagesPath)
	}
	sort.Strings(names)

	wantNames := []string{"alice", "bob"}
	if !equalStringSlices(names, wantNames) {
		t.Errorf("person names = %v, want %v", names, wantNames)
	}

	if imageCountByName["alice"] != 2 {
		t.Errorf("alice image count = %d, want 2", imageCountByName["alice"])
	}
	if imageCountByName["bob"] != 1 {
		t.Errorf("bob image count = %d, want 1", imageCountByName["bob"])
	}
}

func TestLoadPersonsUseCase_Execute_EmptyDir(t *testing.T) {
	t.Parallel()

	tmp := t.TempDir()

	uc := NewLoadPersonsUseCase()
	persons, err := uc.Execute(tmp)
	if err != nil {
		t.Fatalf("Execute on empty dir returned error: %v", err)
	}
	if len(persons) != 0 {
		t.Errorf("expected 0 persons from empty dir, got %d", len(persons))
	}
}

func TestLoadPersonsUseCase_Execute_NonExistentDir(t *testing.T) {
	t.Parallel()

	uc := NewLoadPersonsUseCase()
	_, err := uc.Execute(filepath.Join(t.TempDir(), "does-not-exist"))
	if err == nil {
		t.Errorf("expected error for non-existent directory, got nil")
	}
}

func TestLoadPersonsUseCase_Execute_SkipsNonDirectories(t *testing.T) {
	t.Parallel()

	tmp := t.TempDir()
	mustWriteFile(t, filepath.Join(tmp, "stray.jpg"), []byte("not-a-person-folder"))
	mustWriteFile(t, filepath.Join(tmp, "charlie", "c1.jpg"), []byte("real"))

	uc := NewLoadPersonsUseCase()
	persons, err := uc.Execute(tmp)
	if err != nil {
		t.Fatalf("Execute returned error: %v", err)
	}

	if len(persons) != 1 {
		t.Errorf("expected 1 person (charlie), got %d", len(persons))
	}
	for _, p := range persons {
		if p.Name != "charlie" {
			t.Errorf("loaded person name = %q, want %q", p.Name, "charlie")
		}
	}
}

func mustWriteFile(t *testing.T, path string, data []byte) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("MkdirAll(%s): %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, data, 0o600); err != nil {
		t.Fatalf("WriteFile(%s): %v", path, err)
	}
}

func equalStringSlices(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

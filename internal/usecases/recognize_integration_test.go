//go:build integration

package usecases_test

import (
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/AndriyKalashnykov/go-face"
	"github.com/AndriyKalashnykov/go-face-recognition/internal/usecases"
)

// repoRoot resolves the repo root from THIS file's location at compile time
// (runtime.Caller(0) returns this file's path), so refactors that move the
// test file (e.g., into a subpackage) automatically follow without a brittle
// "../.." string update. The repo root is two directories up from
// internal/usecases/recognize_integration_test.go.
func repoRoot(t *testing.T) string {
	t.Helper()
	_, thisFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller(0) failed — cannot resolve repo root")
	}
	return filepath.Join(filepath.Dir(thisFile), "..", "..")
}

// TestIntegration_RecognizeAndClassify_EndToEnd exercises the full CGO/dlib
// pipeline against the baked-in models, training images, and unknown.jpg.
// Runs under `go test -tags integration` only, because the go-face import
// chain requires the builder image's CGO + dlib headers to compile and link.
func TestIntegration_RecognizeAndClassify_EndToEnd(t *testing.T) {
	t.Chdir(repoRoot(t))

	loadUC := usecases.NewLoadPersonsUseCase()
	persons, err := loadUC.Execute("persons")
	if err != nil {
		t.Fatalf("LoadPersons.Execute(persons): %v", err)
	}
	if len(persons) == 0 {
		t.Fatal("no persons loaded — check persons/ directory layout")
	}

	rec, err := face.NewRecognizer("models")
	if err != nil {
		t.Fatalf("face.NewRecognizer(models): %v", err)
	}
	t.Cleanup(rec.Close)

	recognizeUC := usecases.NewRecognizePersonsUseCase(rec)
	if err := recognizeUC.Execute(persons); err != nil {
		t.Fatalf("RecognizePersons.Execute: %v", err)
	}

	classifyUC := usecases.NewClassifyPersonsUseCase(rec)
	unkPath := filepath.Join("images", "unknown.jpg")
	recognized, err := classifyUC.Execute(unkPath, 0.3)
	if err != nil {
		t.Fatalf("ClassifyPersons.Execute(%q): %v", unkPath, err)
	}

	if len(recognized) == 0 {
		t.Fatal("no faces classified in images/unknown.jpg — the baked-in test data expects at least one match")
	}

	for i, rf := range recognized {
		if rf.Face == nil {
			t.Errorf("recognized[%d].Face is nil", i)
		}
		if rf.ID < 0 {
			t.Errorf("recognized[%d].ID = %d, want ≥ 0", i, rf.ID)
		}
		if _, ok := persons[rf.ID]; !ok {
			t.Errorf("recognized[%d].ID = %d not present in loaded persons map", i, rf.ID)
		}
	}
}

// writeSolidJPEG creates a 256×256 solid-color JPEG (no face) for use as a
// negative-path fixture in integration tests. Returns the absolute path.
func writeSolidJPEG(t *testing.T, dir, name string) string {
	t.Helper()

	img := image.NewRGBA(image.Rect(0, 0, 256, 256))
	solid := color.RGBA{R: 40, G: 40, B: 40, A: 255}
	for y := 0; y < 256; y++ {
		for x := 0; x < 256; x++ {
			img.Set(x, y, solid)
		}
	}

	path := filepath.Join(dir, name)
	f, err := os.Create(path)
	if err != nil {
		t.Fatalf("create %s: %v", path, err)
	}
	t.Cleanup(func() { _ = f.Close() })

	if err := jpeg.Encode(f, img, &jpeg.Options{Quality: 90}); err != nil {
		t.Fatalf("encode solid jpeg: %v", err)
	}
	return path
}

// TestIntegration_RecognizePersons_FacelessTrainingImage seeds a person
// directory with a single faceless JPEG and asserts that RecognizePersons
// surfaces the "unable to recognize people in the image" error path. This
// guards the `face == nil` branch in RecognizePersonsUseCaseImpl.Execute.
func TestIntegration_RecognizePersons_FacelessTrainingImage(t *testing.T) {
	t.Chdir(repoRoot(t))

	tmpPersons := t.TempDir()
	personDir := filepath.Join(tmpPersons, "ghost")
	if err := os.MkdirAll(personDir, 0o755); err != nil {
		t.Fatalf("mkdir person dir: %v", err)
	}
	writeSolidJPEG(t, personDir, "blank.jpg")

	loadUC := usecases.NewLoadPersonsUseCase()
	persons, err := loadUC.Execute(tmpPersons)
	if err != nil {
		t.Fatalf("LoadPersons.Execute: %v", err)
	}
	if len(persons) != 1 {
		t.Fatalf("want 1 person (ghost), got %d", len(persons))
	}

	rec, err := face.NewRecognizer("models")
	if err != nil {
		t.Fatalf("face.NewRecognizer: %v", err)
	}
	t.Cleanup(rec.Close)

	err = usecases.NewRecognizePersonsUseCase(rec).Execute(persons)
	if err == nil {
		t.Fatal("expected error from RecognizePersons on faceless training image, got nil")
	}
}

// TestIntegration_ClassifyPersons_FacelessUnknownImage seeds classify with
// a synthetic faceless JPEG and asserts the `len(unkFaces) == 0` branch
// returns the "unable to recognize people" error.
func TestIntegration_ClassifyPersons_FacelessUnknownImage(t *testing.T) {
	t.Chdir(repoRoot(t))

	rec, err := face.NewRecognizer("models")
	if err != nil {
		t.Fatalf("face.NewRecognizer: %v", err)
	}
	t.Cleanup(rec.Close)

	tmp := t.TempDir()
	blank := writeSolidJPEG(t, tmp, "blank.jpg")

	_, err = usecases.NewClassifyPersonsUseCase(rec).Execute(blank, 0.3)
	if err == nil {
		t.Fatal("expected error classifying faceless image, got nil")
	}
}

// TestIntegration_ClassifyPersons_TightThresholdReturnsEmpty exercises the
// ClassifyThreshold `catID < 0` branch by setting a near-zero threshold
// that rejects every candidate match. Returns an empty slice with no
// error (not the faceless error path — faces ARE detected, they just
// don't meet the threshold).
func TestIntegration_ClassifyPersons_TightThresholdReturnsEmpty(t *testing.T) {
	t.Chdir(repoRoot(t))

	rec, err := face.NewRecognizer("models")
	if err != nil {
		t.Fatalf("face.NewRecognizer: %v", err)
	}
	t.Cleanup(rec.Close)

	loadUC := usecases.NewLoadPersonsUseCase()
	persons, err := loadUC.Execute("persons")
	if err != nil {
		t.Fatalf("LoadPersons: %v", err)
	}
	if err := usecases.NewRecognizePersonsUseCase(rec).Execute(persons); err != nil {
		t.Fatalf("RecognizePersons: %v", err)
	}

	// Threshold 0.0001 is effectively impossible to satisfy (descriptor
	// euclidean distance rounds well above it for any real photo).
	unkPath := filepath.Join("images", "unknown.jpg")
	recognized, err := usecases.NewClassifyPersonsUseCase(rec).Execute(unkPath, 0.0001)
	if err != nil {
		t.Fatalf("ClassifyPersons: %v", err)
	}
	if len(recognized) != 0 {
		t.Errorf("expected 0 matches with threshold=0.0001, got %d", len(recognized))
	}
}

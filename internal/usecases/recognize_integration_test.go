//go:build integration

package usecases_test

import (
	"path/filepath"
	"testing"

	"github.com/AndriyKalashnykov/go-face"
	"github.com/AndriyKalashnykov/go-face-recognition/internal/usecases"
)

// repoRoot must be set to the repo root so we can find models/, persons/,
// images/ from the test's working directory (internal/usecases).
const repoRoot = "../.."

// TestIntegration_RecognizeAndClassify_EndToEnd exercises the full CGO/dlib
// pipeline against the baked-in models, training images, and unknown.jpg.
// Runs under `go test -tags integration` only, because the go-face import
// chain requires the builder image's CGO + dlib headers to compile and link.
func TestIntegration_RecognizeAndClassify_EndToEnd(t *testing.T) {
	t.Chdir(repoRoot)

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

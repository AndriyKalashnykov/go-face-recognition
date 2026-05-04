package main

import (
	"fmt"
	"log"
	"path/filepath"
	"time"

	"github.com/AndriyKalashnykov/go-face"
	"github.com/AndriyKalashnykov/go-face-recognition/internal/entity"
	"github.com/AndriyKalashnykov/go-face-recognition/internal/usecases"
)

var (
	modelsDir  = "models"
	imagesDir  = "images"
	personsDir = "persons"
	fontPath   = filepath.Join("fonts", "Roboto-Regular.ttf")
)

// main is a thin shell — argv parsing, exit code mapping, and absolutely
// nothing else. All I/O, error handling, and orchestration lives in run()
// so it is unit-testable without subprocess gymnastics.
func main() {
	if err := run(personsDir, modelsDir, imagesDir, fontPath); err != nil {
		log.Fatal(err)
	}
}

// run executes the full classification pipeline against the supplied
// directory layout. Returns any error from the underlying use cases instead
// of calling log.Fatal so callers (main, tests) decide how to surface it.
func run(personsDir, modelsDir, imagesDir, fontPath string) error {
	initialTime := time.Now()
	defer func() {
		fmt.Printf("\x1b[34mTotal time: %s\x1b[0m\n", time.Since(initialTime))
	}()

	persons, err := usecases.NewLoadPersonsUseCase().Execute(personsDir)
	if err != nil {
		return fmt.Errorf("load persons: %w", err)
	}

	initRecognizerTime := time.Now()
	rec, err := face.NewRecognizer(modelsDir)
	if err != nil {
		return fmt.Errorf("init face recognizer: %w", err)
	}
	defer rec.Close()
	fmt.Println("Time to init recognizer: ", time.Since(initRecognizerTime))

	if err := usecases.NewRecognizePersonsUseCase(rec).Execute(persons); err != nil {
		return fmt.Errorf("recognize persons: %w", err)
	}

	unkImagePath := filepath.Join(imagesDir, "unknown.jpg")
	recognizedFaces, err := usecases.NewClassifyPersonsUseCase(rec).Execute(unkImagePath, 0.3)
	if err != nil {
		return fmt.Errorf("classify persons: %w", err)
	}

	fmt.Printf("\033[0;32mFound %d faces\033[0m\n", len(recognizedFaces))
	for _, recognizedFace := range recognizedFaces {
		fmt.Printf("\033[0;32mPerson: %s\033[0m\n", persons[recognizedFace.ID].Name)
	}

	drawer := entity.NewDrawer(unkImagePath, fontPath)
	for _, recognizedFace := range recognizedFaces {
		drawer.DrawFace(recognizedFace.Face.Rectangle, persons[recognizedFace.ID].Name)
	}

	if err := drawer.SaveImage(filepath.Join(imagesDir, "result.jpg")); err != nil {
		return fmt.Errorf("save result image: %w", err)
	}
	return nil
}

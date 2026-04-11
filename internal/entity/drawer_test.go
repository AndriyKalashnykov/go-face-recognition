package entity

import (
	"image"
	"image/jpeg"
	"os"
	"path/filepath"
	"testing"
)

// repoRoot is the relative path from this test file's directory
// (internal/entity) to the repo root, used to reach the baked-in
// images/ and fonts/ directories.
const repoRoot = "../.."

func TestNewDrawer_LoadsRealImageAndFont(t *testing.T) {
	t.Parallel()

	imagePath := filepath.Join(repoRoot, "images", "unknown.jpg")
	fontPath := filepath.Join(repoRoot, "fonts", "Roboto-Regular.ttf")

	d := NewDrawer(imagePath, fontPath)
	if d == nil {
		t.Fatal("NewDrawer returned nil")
	}

	impl, ok := d.(*DrawerImpl)
	if !ok {
		t.Fatalf("NewDrawer returned %T, want *DrawerImpl", d)
	}
	if impl.img == nil {
		t.Error("DrawerImpl.img is nil after NewDrawer — image load failed silently")
	}
	if impl.dst == nil {
		t.Error("DrawerImpl.dst is nil after NewDrawer")
	}
	if impl.font == nil {
		t.Error("DrawerImpl.font is nil after NewDrawer — font load failed silently")
	}
}

func TestDrawer_DrawFaceAndSave(t *testing.T) {
	t.Parallel()

	imagePath := filepath.Join(repoRoot, "images", "unknown.jpg")
	fontPath := filepath.Join(repoRoot, "fonts", "Roboto-Regular.ttf")

	d := NewDrawer(imagePath, fontPath)
	if d == nil {
		t.Fatal("NewDrawer returned nil")
	}

	d.DrawFace(image.Rect(10, 10, 100, 100), "Test")

	outPath := filepath.Join(t.TempDir(), "out.jpg")
	if err := d.SaveImage(outPath); err != nil {
		t.Fatalf("SaveImage(%q): %v", outPath, err)
	}

	info, err := os.Stat(outPath)
	if err != nil {
		t.Fatalf("stat(%q): %v", outPath, err)
	}
	if info.Size() == 0 {
		t.Errorf("saved image is zero bytes")
	}

	f, err := os.Open(outPath)
	if err != nil {
		t.Fatalf("open(%q): %v", outPath, err)
	}
	t.Cleanup(func() { _ = f.Close() })

	img, err := jpeg.Decode(f)
	if err != nil {
		t.Fatalf("jpeg.Decode: %v", err)
	}
	if img.Bounds().Dx() == 0 || img.Bounds().Dy() == 0 {
		t.Errorf("decoded image has zero dimensions: %v", img.Bounds())
	}
}

func TestDrawer_SaveImage_InvalidPath(t *testing.T) {
	t.Parallel()

	d := NewDrawer(
		filepath.Join(repoRoot, "images", "unknown.jpg"),
		filepath.Join(repoRoot, "fonts", "Roboto-Regular.ttf"),
	)
	if d == nil {
		t.Fatal("NewDrawer returned nil")
	}

	invalidPath := filepath.Join(t.TempDir(), "does", "not", "exist", "out.jpg")
	if err := d.SaveImage(invalidPath); err == nil {
		t.Errorf("expected error saving to non-existent directory, got nil")
	}
}

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

// TestDrawer_loadImage_Errors and TestDrawer_loadFont_Errors exercise the
// internal loaders directly — `NewDrawer` itself swallows their errors and
// returns a partially-initialized Drawer, so these table-driven tests
// guard against regressions in the error-return surface that `NewDrawer`
// relies on.
func TestDrawer_loadImage_Errors(t *testing.T) {
	t.Parallel()

	tmp := t.TempDir()
	notJPEG := filepath.Join(tmp, "not.jpg")
	if err := os.WriteFile(notJPEG, []byte("this is not a jpeg"), 0o600); err != nil {
		t.Fatalf("seed non-jpeg: %v", err)
	}

	cases := []struct {
		name string
		path string
	}{
		{"missing file", filepath.Join(tmp, "does-not-exist.jpg")},
		{"non-jpeg bytes", notJPEG},
		{"empty string", ""},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			d := &DrawerImpl{}
			if err := d.loadImage(tc.path); err == nil {
				t.Errorf("loadImage(%q): expected error, got nil", tc.path)
			}
			if d.img != nil {
				t.Errorf("loadImage(%q): d.img should remain nil on error", tc.path)
			}
		})
	}
}

func TestDrawer_loadFont_Errors(t *testing.T) {
	t.Parallel()

	tmp := t.TempDir()
	notTTF := filepath.Join(tmp, "not.ttf")
	if err := os.WriteFile(notTTF, []byte("not a real ttf"), 0o600); err != nil {
		t.Fatalf("seed non-ttf: %v", err)
	}

	cases := []struct {
		name string
		path string
	}{
		{"missing file", filepath.Join(tmp, "does-not-exist.ttf")},
		{"non-ttf bytes", notTTF},
		{"empty string", ""},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			d := &DrawerImpl{}
			if err := d.loadFont(tc.path); err == nil {
				t.Errorf("loadFont(%q): expected error, got nil", tc.path)
			}
			if d.font != nil {
				t.Errorf("loadFont(%q): d.font should remain nil on error", tc.path)
			}
		})
	}
}

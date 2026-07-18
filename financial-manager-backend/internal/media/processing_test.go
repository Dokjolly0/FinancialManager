package media

import (
	"bytes"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"testing"
)

func solidImage(t *testing.T, width, height int, c color.Color) image.Image {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := range height {
		for x := range width {
			img.Set(x, y, c)
		}
	}
	return img
}

func encodePNG(t *testing.T, img image.Image) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encode png: %v", err)
	}
	return buf.Bytes()
}

func encodeJPEG(t *testing.T, img image.Image) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, nil); err != nil {
		t.Fatalf("encode jpeg: %v", err)
	}
	return buf.Bytes()
}

func TestDetectMIME_AcceptsSupportedFormats(t *testing.T) {
	png := encodePNG(t, solidImage(t, 4, 4, color.White))
	if mime, err := DetectMIME(png); err != nil || mime != "image/png" {
		t.Fatalf("DetectMIME(png) = (%q, %v), want image/png, nil", mime, err)
	}

	jpg := encodeJPEG(t, solidImage(t, 4, 4, color.White))
	if mime, err := DetectMIME(jpg); err != nil || mime != "image/jpeg" {
		t.Fatalf("DetectMIME(jpg) = (%q, %v), want image/jpeg, nil", mime, err)
	}
}

func TestDetectMIME_RejectsUnsupportedFormat(t *testing.T) {
	if _, err := DetectMIME([]byte("this is not an image, just plain text padding out to more than a few bytes")); err == nil {
		t.Error("expected an error for non-image content")
	}
}

func TestDecodeWithLimits_DecodesAValidImage(t *testing.T) {
	original := solidImage(t, 10, 20, color.RGBA{R: 10, G: 20, B: 30, A: 255})
	encoded := encodePNG(t, original)

	decoded, err := DecodeWithLimits(encoded)
	if err != nil {
		t.Fatalf("DecodeWithLimits() error = %v", err)
	}
	b := decoded.Bounds()
	if b.Dx() != 10 || b.Dy() != 20 {
		t.Fatalf("decoded bounds = %v, want 10x20", b)
	}
}

func TestApplyCrop_CentersSquareWhenNoCropGiven(t *testing.T) {
	img := solidImage(t, 100, 50, color.White)
	cropped := ApplyCrop(img, nil)
	b := cropped.Bounds()
	if b.Dx() != 50 || b.Dy() != 50 {
		t.Fatalf("cropped bounds = %v, want a 50x50 centered square", b)
	}
}

func TestApplyCrop_ExtractsNormalizedRect(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 100, 100))
	topLeft := color.RGBA{R: 255, A: 255}
	bottomRight := color.RGBA{B: 255, A: 255}
	for y := range 100 {
		for x := range 100 {
			if x < 50 && y < 50 {
				img.Set(x, y, topLeft)
			} else {
				img.Set(x, y, bottomRight)
			}
		}
	}

	cropped := ApplyCrop(img, &CropRect{X: 0, Y: 0, Width: 0.5, Height: 0.5})
	b := cropped.Bounds()
	if b.Dx() != 50 || b.Dy() != 50 {
		t.Fatalf("cropped bounds = %v, want 50x50", b)
	}
	r, g, bl, a := cropped.At(10, 10).RGBA()
	if r>>8 != 255 || g>>8 != 0 || bl>>8 != 0 || a>>8 != 255 {
		t.Fatalf("cropped pixel = (%d,%d,%d,%d), want the top-left red quadrant", r>>8, g>>8, bl>>8, a>>8)
	}
}

func TestApplyCrop_RotatesBeforeCropping(t *testing.T) {
	// A 100x50 image rotated 90 degrees becomes 50x100; cropping the full
	// (rotated) frame should reflect the swapped dimensions.
	img := solidImage(t, 100, 50, color.White)
	cropped := ApplyCrop(img, &CropRect{X: 0, Y: 0, Width: 1, Height: 1, RotationDegrees: 90})
	b := cropped.Bounds()
	if b.Dx() != 50 || b.Dy() != 100 {
		t.Fatalf("cropped bounds after 90-degree rotation = %v, want 50x100", b)
	}
}

func TestResize_ProducesExactTargetSize(t *testing.T) {
	img := solidImage(t, 300, 300, color.White)
	resized := Resize(img, 512)
	b := resized.Bounds()
	if b.Dx() != 512 || b.Dy() != 512 {
		t.Fatalf("resized bounds = %v, want 512x512", b)
	}
}

func TestEncode_PicksJPEGForOpaqueImage(t *testing.T) {
	img := solidImage(t, 8, 8, color.White)
	_, mimeType, err := Encode(img)
	if err != nil {
		t.Fatalf("Encode() error = %v", err)
	}
	if mimeType != "image/jpeg" {
		t.Errorf("mimeType = %q, want image/jpeg for an opaque image", mimeType)
	}
}

func TestEncode_PicksPNGForTransparentImage(t *testing.T) {
	img := solidImage(t, 8, 8, color.RGBA{R: 255, A: 128})
	_, mimeType, err := Encode(img)
	if err != nil {
		t.Fatalf("Encode() error = %v", err)
	}
	if mimeType != "image/png" {
		t.Errorf("mimeType = %q, want image/png for a transparent image", mimeType)
	}
}

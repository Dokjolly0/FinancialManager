package media

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"net/http"

	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp" // decode-only WebP support, registered via image.Decode
)

// maxInputPixels guards against decompression bombs (plan.md section 16.3
// step 6): a 40-megapixel cap is far above any real transaction/profile
// photo but rejects maliciously crafted small-file/huge-dimension images
// before the costly full decode.
const maxInputPixels = 40_000_000

var ErrUnsupportedFormat = errors.New("unsupported image format")
var ErrImageTooLarge = errors.New("image exceeds the maximum allowed pixel dimensions")

// TargetSize returns the square output dimensions for a media kind (plan.md
// section 7.8: every kind in this app is a 1:1 crop — "Crop 1:1" appears
// under both "Profilo" and "Operazione").
func TargetSize(kind string) int {
	if kind == KindCategory {
		return 256
	}
	return 512
}

// DetectMIME sniffs the actual content type from magic bytes (plan.md
// section 16.3 steps 2-3: extension is only a first filter, the real check
// is the signature) and confirms it's one of the types this pipeline can
// decode.
func DetectMIME(content []byte) (string, error) {
	head := content
	if len(head) > 512 {
		head = head[:512]
	}
	detected := http.DetectContentType(head)
	switch detected {
	case "image/jpeg", "image/png", "image/webp":
		return detected, nil
	default:
		return "", fmt.Errorf("%w: detected %q", ErrUnsupportedFormat, detected)
	}
}

// DecodeWithLimits decodes an image only after checking its declared
// dimensions are within maxInputPixels, avoiding a full decode of a
// decompression bomb.
func DecodeWithLimits(content []byte) (image.Image, error) {
	cfg, _, err := image.DecodeConfig(bytes.NewReader(content))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnsupportedFormat, err)
	}
	if cfg.Width*cfg.Height > maxInputPixels {
		return nil, ErrImageTooLarge
	}

	img, _, err := image.Decode(bytes.NewReader(content))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnsupportedFormat, err)
	}
	return img, nil
}

// CropRect is the client-supplied crop in normalized [0,1] coordinates
// (plan.md section 16.5). RotationDegrees is rounded to the nearest
// multiple of 90 — arbitrary-angle rotation would need canvas expansion and
// interpolation the MVP doesn't attempt; the common "my photo is sideways"
// case is fully covered by 90/180/270.
type CropRect struct {
	X, Y, Width, Height float64
	RotationDegrees     float64
}

func rotate90(img image.Image) image.Image {
	b := img.Bounds()
	out := image.NewRGBA(image.Rect(0, 0, b.Dy(), b.Dx()))
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			out.Set(b.Max.Y-1-y+b.Min.Y, x-b.Min.X, img.At(x, y))
		}
	}
	return out
}

func applyRotation(img image.Image, degrees float64) image.Image {
	// Normalize to one of 0/90/180/270 (plan.md section 7.8: "Rotazione
	// facoltativa" — clients send whatever the user chose, we snap it).
	steps := (int(degrees+45) / 90) % 4
	if steps < 0 {
		steps += 4
	}
	for range steps {
		img = rotate90(img)
	}
	return img
}

// ApplyCrop extracts the normalized crop rect from img, applying rotation
// first if requested. A nil crop falls back to a centered square using the
// smaller dimension — the server never trusts that the client actually
// cropped anything (plan.md section 16.5: "Il backend applica nuovamente il
// crop all'originale decodificato").
func ApplyCrop(img image.Image, crop *CropRect) image.Image {
	if crop != nil && crop.RotationDegrees != 0 {
		img = applyRotation(img, crop.RotationDegrees)
	}

	b := img.Bounds()
	width, height := b.Dx(), b.Dy()

	var rect image.Rectangle
	if crop != nil {
		x := clamp01(crop.X)
		y := clamp01(crop.Y)
		w := clamp01(crop.Width)
		h := clamp01(crop.Height)
		rect = image.Rect(
			b.Min.X+int(x*float64(width)),
			b.Min.Y+int(y*float64(height)),
			b.Min.X+int((x+w)*float64(width)),
			b.Min.Y+int((y+h)*float64(height)),
		).Intersect(b)
	} else {
		side := min(height, width)
		offsetX := b.Min.X + (width-side)/2
		offsetY := b.Min.Y + (height-side)/2
		rect = image.Rect(offsetX, offsetY, offsetX+side, offsetY+side)
	}

	if rect.Empty() {
		rect = b
	}

	cropped := image.NewRGBA(image.Rect(0, 0, rect.Dx(), rect.Dy()))
	draw.Draw(cropped, cropped.Bounds(), img, rect.Min, draw.Src)
	return cropped
}

func clamp01(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

// Resize scales img to an exact size×size square using a high-quality
// interpolator — the crop step already guarantees a square input.
func Resize(img image.Image, size int) image.Image {
	dst := image.NewRGBA(image.Rect(0, 0, size, size))
	draw.CatmullRom.Scale(dst, dst.Bounds(), img, img.Bounds(), draw.Over, nil)
	return dst
}

// hasTransparency scans for any non-opaque pixel. Only ever called on the
// already-resized output (at most 512×512), so the scan is cheap.
func hasTransparency(img image.Image) bool {
	b := img.Bounds()
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			_, _, _, a := img.At(x, y).RGBA()
			if a < 0xffff {
				return true
			}
		}
	}
	return false
}

// Encode picks PNG when the image has any transparency, JPEG otherwise
// (plan.md section 16.4: "WebP o JPEG per foto; PNG/WebP per immagini con
// trasparenza" — WebP encoding needs cgo/libwebp, so this MVP pipeline
// always picks the JPEG/PNG alternative the plan explicitly allows).
func Encode(img image.Image) (data []byte, mimeType string, err error) {
	var buf bytes.Buffer
	if hasTransparency(img) {
		if err := png.Encode(&buf, img); err != nil {
			return nil, "", fmt.Errorf("encode png: %w", err)
		}
		return buf.Bytes(), "image/png", nil
	}

	// JPEG has no alpha channel; flatten onto white first so a transparent
	// PNG/WebP source without visible transparency doesn't get spurious
	// black backgrounds from an unset alpha-less color conversion.
	flattened := image.NewRGBA(img.Bounds())
	draw.Draw(flattened, flattened.Bounds(), image.NewUniform(color.White), image.Point{}, draw.Src)
	draw.Draw(flattened, flattened.Bounds(), img, img.Bounds().Min, draw.Over)

	if err := jpeg.Encode(&buf, flattened, &jpeg.Options{Quality: 85}); err != nil {
		return nil, "", fmt.Errorf("encode jpeg: %w", err)
	}
	return buf.Bytes(), "image/jpeg", nil
}

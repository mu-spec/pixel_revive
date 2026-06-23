import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart' show Size;

class ImageProcessor {
  static const int _jpgQuality = 90;

  static img.Image? _decode(Uint8List bytes) => img.decodeImage(bytes);

  static Uint8List _encode(img.Image image) =>
      Uint8List.fromList(img.encodeJpg(image, quality: _jpgQuality));

  static int _clamp(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

  static img.Image _clone(img.Image src) =>
      img.copyResize(src, width: src.width, height: src.height);

  /// Stronger unsharp mask sharpening filter (Fixed: Clone before blur to prevent in-place mutation!)
  static img.Image _sharpen(img.Image src, {double amount = 1.5}) {
    final clone = _clone(src); // CRITICAL FIX: Clone the image first!
    final blurred = img.gaussianBlur(clone, radius: 3); // Blurring clone keeps src perfectly sharp
    return _unsharpMask(src, blurred, amount: amount);
  }

  /// Adaptive unsharp masking with higher contrast detailing
  static img.Image _unsharpMask(img.Image original, img.Image blurred,
      {double amount = 1.5, double noiseThreshold = 2.0}) {
    final w = original.width;
    final h = original.height;
    final out = img.Image(width: w, height: h, numChannels: 4);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final orig = original.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        int comp(int o, int b) {
          final diff = o - b;
          if (diff.abs() < noiseThreshold) {
            return o;
          }
          return _clamp((o + diff * amount).toInt());
        }

        out.setPixel(
          x,
          y,
          img.ColorRgba8(
            comp(orig.r.toInt(), blur.r.toInt()),
            comp(orig.g.toInt(), blur.g.toInt()),
            comp(orig.b.toInt(), blur.b.toInt()),
            orig.a.toInt(),
          ),
        );
      }
    }
    return out;
  }

  // ==========================================
  // FILTER 1: ONE-TAP AUTO ENHANCE
  // ==========================================
  static Future<Uint8List> autoEnhance(Uint8List input, {double strength = 0.8}) async {
    return await compute(_autoEnhanceSync, _AutoEnhanceArgs(input, strength));
  }

  static Uint8List _autoEnhanceSync(_AutoEnhanceArgs args) {
    final src = _decode(args.input);
    if (src == null) return args.input;

    // Boost contrast, saturation and brightness for a vivid popping comparison difference
    final double contrastVal = 1.0 + args.strength * 0.40; // 0.8 strength -> 1.32 contrast! (Vivid details!)
    final double satVal = 1.0 + args.strength * 0.45;      // 0.8 strength -> 1.36 saturation!
    final double brightVal = 1.0 + args.strength * 0.12;   // 0.8 strength -> 1.10 brightness

    var out = img.adjustColor(
      src,
      contrast: contrastVal,
      saturation: satVal,
      brightness: brightVal,
    );
    // Apply heavy-detail unsharp mask
    out = _sharpen(out, amount: args.strength * 1.8); 
    return _encode(out);
  }

  // ==========================================
  // FILTER 2: HD UPSCALE (2X BICUBIC)
  // ==========================================
  static Future<Uint8List> upscale(Uint8List input, {int scale = 2}) async {
    return await compute(_upscaleSync, _UpscaleArgs(input, scale));
  }

  static Uint8List _upscaleSync(_UpscaleArgs args) {
    final src = _decode(args.input);
    if (src == null) return args.input;

    final newW = (src.width * args.scale).clamp(1, 2400).toInt();
    final newH = (src.height * args.scale).clamp(1, 2400).toInt();

    // Use high-end bicubic interpolation
    final out = img.copyResize(
      src,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.cubic,
    );
    // Heavy edge sharpening to make the upscaled resolution strikingly obvious!
    final sharpened = _sharpen(out, amount: 1.5);
    return _encode(sharpened);
  }

  // ==========================================
  // FILTER 3: FACE ENHANCE (PORTRAIT RETOUCH)
  // ==========================================
  static Future<Uint8List> faceEnhance(Uint8List input, {double smoothness = 0.5, double strength = 0.8}) async {
    return await compute(_faceEnhanceSync, _FaceEnhanceArgs(input, smoothness, strength));
  }

  static Uint8List _faceEnhanceSync(_FaceEnhanceArgs args) {
    final src = _decode(args.input);
    if (src == null) return args.input;

    final w = src.width;
    final h = src.height;

    // 1. Create a skin smoothing layer (Smart Edge-Preserving Blur)
    // Blur radius depends on smoothness slider (1 to 8)
    final int rRadius = (args.smoothness * 8).round().clamp(1, 8);
    
    // CRITICAL FIX: Clone before blur to prevent in-place source corruption!
    final clone = _clone(src);
    final blurred = img.gaussianBlur(clone, radius: rRadius);
    final smoothed = img.Image(width: w, height: h, numChannels: 4);

    // Threshold depends on smoothness strength (10 to 34)
    final int threshold = (10 + args.smoothness * 24).round();

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final orig = src.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final int rDiff = (orig.r - blur.r).abs().toInt();
        final int gDiff = (orig.g - blur.g).abs().toInt();
        final int bDiff = (orig.b - blur.b).abs().toInt();
        final double diff = (rDiff + gDiff + bDiff) / 3.0;

        // If difference is low, it is flat skin -> blend with blurred layer
        // If high, it is eyes/lips/hair -> keep 100% sharp
        double smoothWeight = (1.0 - (diff / threshold)).clamp(0.0, 1.0);
        // Exponential falloff for professional feathering
        smoothWeight = math.pow(smoothWeight, 2).toDouble();

        final int r = (orig.r * (1.0 - smoothWeight) + blur.r * smoothWeight).toInt();
        final int g = (orig.g * (1.0 - smoothWeight) + blur.g * smoothWeight).toInt();
        final int b = (orig.b * (1.0 - smoothWeight) + blur.b * smoothWeight).toInt();

        smoothed.setPixel(x, y, img.ColorRgba8(r, g, b, orig.a.toInt()));
      }
    }

    // 2. Boost color contrast and brightness for portrait aesthetic based on strength
    var out = img.adjustColor(
      smoothed,
      contrast: 1.05 + args.strength * 0.15, // stronger! (1.17)
      brightness: 1.0 + args.strength * 0.06, // stronger! (1.05)
      saturation: 1.0 + args.strength * 0.16, // stronger! (1.13)
    );

    // 3. Sharpen facial details (eyes, hair) back up
    out = _sharpen(out, amount: args.strength * 1.35); // stronger!

    return _encode(out);
  }

  // ==========================================
  // FILTER 4: PORTRAIT BACK-BLUR (DEPTH-OF-FIELD)
  // ==========================================
  static Future<Uint8List> backgroundBlur(Uint8List input, {double radius = 0.6}) async {
    return await compute(_bgBlurSync, _BgBlurArgs(input, radius));
  }

  static Uint8List _bgBlurSync(_BgBlurArgs args) {
    final src = _decode(args.input);
    if (src == null) return args.input;

    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h, numChannels: 4);

    // Generate fully blurred background layer
    // Blur radius depends on slider (4 to 28)
    final int bRadius = (args.radius * 28).round().clamp(4, 28);
    
    // CRITICAL FIX: Clone the image before blurring to prevent in-place source corruption!
    final clone = _clone(src);
    final bgBlur = img.gaussianBlur(clone, radius: bRadius);

    final double centerX = w / 2.0;
    final double centerY = h / 2.0;
    final double maxDist = math.sqrt(centerX * centerX + centerY * centerY);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double dx = x - centerX;
        final double dy = y - centerY;
        final double dist = math.sqrt(dx * dx + dy * dy);
        final double normDist = dist / maxDist;

        // Bokeh depth mask:
        // Inside central circle (30% radius) -> 100% sharp focus
        // Outside 75% boundary -> 100% fully blurred background
        // In-between -> Smooth feathering
        double blurWeight = ((normDist - 0.30) / 0.45).clamp(0.0, 1.0);
        // S-curve for professional smooth lens falloff
        blurWeight = 3 * blurWeight * blurWeight - 2 * blurWeight * blurWeight * blurWeight;

        final orig = src.getPixel(x, y);
        final bg = bgBlur.getPixel(x, y);

        final int r = (orig.r * (1.0 - blurWeight) + bg.r * blurWeight).toInt();
        final int g = (orig.g * (1.0 - blurWeight) + bg.g * blurWeight).toInt();
        final int b = (orig.b * (1.0 - blurWeight) + bg.b * blurWeight).toInt();

        out.setPixel(x, y, img.ColorRgba8(r, g, b, orig.a.toInt()));
      }
    }

    return _encode(out);
  }

  // ==========================================
  // FILTER 5: BILATERAL-LIKE DENOISE (GRAIN DISMISSAL)
  // ==========================================
  static Future<Uint8List> denoise(Uint8List input) async {
    return await compute(_denoiseSync, input);
  }

  static Uint8List _denoiseSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h, numChannels: 4);

    // Bilateral-like Edge Preserving Smoothing
    // We average 3x3 neighbors, but heavily down-weight neighbors that are far in color distance
    const double sigmaR = 25.0; // Color distance tolerance

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
          out.setPixel(x, y, src.getPixel(x, y));
          continue;
        }

        final center = src.getPixel(x, y);
        double sumR = 0, sumG = 0, sumB = 0;
        double totalWeight = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final neighbor = src.getPixel(x + kx, y + ky);

            // Compute Euclidean color distance
            final double colorDist = math.sqrt(
              math.pow(center.r - neighbor.r, 2) +
              math.pow(center.g - neighbor.g, 2) +
              math.pow(center.b - neighbor.b, 2)
            );

            // Gaussian spatial weight (simplified 3x3)
            final double spaceWeight = (kx == 0 && ky == 0) ? 1.0 : 0.6;

            // Range (color) weight
            final double rangeWeight = math.exp(- (colorDist * colorDist) / (2 * sigmaR * sigmaR));

            final double weight = spaceWeight * rangeWeight;

            sumR += neighbor.r * weight;
            sumG += neighbor.g * weight;
            sumB += neighbor.b * weight;
            totalWeight += weight;
          }
        }

        final int r = (sumR / totalWeight).round();
        final int g = (sumG / totalWeight).round();
        final int b = (sumB / totalWeight).round();

        out.setPixel(x, y, img.ColorRgba8(r, g, b, center.a.toInt()));
      }
    }

    // Slightly boost the contrast of the denoised photo to make it pop
    final contrastAdjusted = img.adjustColor(out, contrast: 1.10);
    return _encode(contrastAdjusted);
  }

  // ==========================================
  // FILTER 6: UNBLUR (MOTION & FOCUS REMEDIATION)
  // ==========================================
  static Future<Uint8List> unblur(Uint8List input) async {
    return await compute(_unblurSync, input);
  }

  static Uint8List _unblurSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final clone = _clone(src);
    final blurred = img.gaussianBlur(clone, radius: 3);
    var out = _unsharpMask(src, blurred, amount: 2.2); // Stronger unsharp masking (2.2) to make differences stark!
    out = img.adjustColor(out, contrast: 1.18);
    return _encode(out);
  }

  // ==========================================
  // FILTER 7: CINEMATIC SPLIT-TONING COLORIZE
  // ==========================================
  static Future<Uint8List> colorize(Uint8List input) async {
    return await compute(_colorizeSync, input);
  }

  static Uint8List _colorizeSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final w = src.width;
    final h = src.height;
    var out = img.Image(width: w, height: h, numChannels: 4);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        // Standard Grayscale Luminosity
        final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).toInt();

        int r, g, b;
        if (lum < 60) {
          // Shadows: Rich cinematic cool blue/teal
          r = (lum * 0.65).round();
          g = (lum * 0.78).round();
          b = (lum * 1.12).round().clamp(0, 255);
        } else if (lum < 185) {
          // Midtones: Warm, lifelike copper/skin tones
          r = (lum * 1.24).round().clamp(0, 255);
          g = (lum * 0.96).round().clamp(0, 255);
          b = (lum * 0.80).round().clamp(0, 255);
        } else {
          // Highlights: Clean soft golden white
          r = (lum * 1.04).round().clamp(0, 255);
          g = (lum * 1.01).round().clamp(0, 255);
          b = (lum * 0.94).round().clamp(0, 255);
        }

        out.setPixel(x, y, img.ColorRgba8(r, g, b, p.a.toInt()));
      }
    }
    // Boost saturation and contrasts slightly for an organic color look
    out = img.adjustColor(out, saturation: 1.45, contrast: 1.18);
    return _encode(out);
  }

  // ==========================================
  // FILTER 8: OLD PHOTO RESTORATION
  // ==========================================
  static Future<Uint8List> restoreOldPhoto(Uint8List input) async {
    return await compute(_restoreOldPhotoSync, input);
  }

  static Uint8List _restoreOldPhotoSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    // 1. Dynamic range expansion (Auto-Contrast Stretching)
    final w = src.width;
    final h = src.height;
    int minLum = 255, maxLum = 0;

    for (int y = 0; y < h; y += 4) { // sample pixels for speed
      for (int x = 0; x < w; x += 4) {
        final p = src.getPixel(x, y);
        final int lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).toInt();
        if (lum < minLum) minLum = lum;
        if (lum > maxLum) maxLum = lum;
      }
    }

    // Dynamic contrast stretch range
    final stretched = img.Image(width: w, height: h, numChannels: 4);
    final double range = (maxLum - minLum).clamp(1, 255).toDouble();

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        int stretch(int v) {
          return (((v - minLum) / range) * 255).round().clamp(0, 255);
        }
        stretched.setPixel(
          x,
          y,
          img.ColorRgba8(stretch(p.r.toInt()), stretch(p.g.toInt()), stretch(p.b.toInt()), p.a.toInt())
        );
      }
    }

    // 2. White balance / Sepia color shift neutralizing
    // Faded old photos are yellow/red, we neutralize by pulling down red/green and elevating blue
    var colorShifted = img.colorOffset(stretched, red: -18, green: -6, blue: 22);

    // 3. Adaptive unsharp mask to rescue details
    colorShifted = _sharpen(colorShifted, amount: 1.4); // stronger sharpening

    return _encode(colorShifted);
  }

  // ==========================================
  // FILTER 9: ARTISTIC CARTOON EFFECT (SKETCH & POP)
  // ==========================================
  static Future<Uint8List> cartoonEffect(Uint8List input) async {
    return await compute(_cartoonSync, input);
  }

  static Uint8List _cartoonSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final w = src.width;
    final h = src.height;

    // 1. Posterization / Color quantization to create solid flat color cells (16 colors)
    var quantized = img.quantize(src, numberOfColors: 18);
    quantized = img.adjustColor(quantized, contrast: 1.20, saturation: 1.35);

    final out = img.Image(width: w, height: h, numChannels: 4);

    // 2. Sobel Edge Filter overlay (draw thick beautiful sketch borders)
    const int threshold = 28;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final orig = quantized.getPixel(x, y);
        if (x == w - 1 || y == h - 1) {
          out.setPixel(x, y, orig);
          continue;
        }

        final pRight = quantized.getPixel(x + 1, y);
        final pBottom = quantized.getPixel(x, y + 1);

        final int lum = (0.299 * orig.r + 0.587 * orig.g + 0.114 * orig.b).toInt();
        final int lumR = (0.299 * pRight.r + 0.587 * pRight.g + 0.114 * pRight.b).toInt();
        final int lumB = (0.299 * pBottom.r + 0.587 * pBottom.g + 0.114 * pBottom.b).toInt();

        // If high change in brightness, draw a black ink comic boundary
        if ((lum - lumR).abs() > threshold || (lum - lumB).abs() > threshold) {
          out.setPixel(x, y, img.ColorRgba8(12, 12, 22, orig.a.toInt()));
        } else {
          out.setPixel(x, y, orig);
        }
      }
    }

    return _encode(out);
  }

  // ==========================================
  // WATERMARK APPLICATOR
  // ==========================================
  static Future<Uint8List> applyWatermark(Uint8List input) async {
    return await compute(_applyWatermarkSync, input);
  }

  static Uint8List _applyWatermarkSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    var out = _clone(src);
    final font = img.arial14;
    const text = 'PixelRevive';

    final x = 24;
    final y = out.height - 40;

    img.drawString(
      out,
      text,
      font: font,
      x: x + 1,
      y: y + 1,
      color: img.ColorRgba8(0, 0, 0, 180),
    );
    img.drawString(
      out,
      text,
      font: font,
      x: x,
      y: y,
      color: img.ColorRgba8(255, 255, 255, 200),
    );

    return _encode(out);
  }

  static Future<Size?> getImageSize(Uint8List bytes) async {
    return await compute(_getImageSizeSync, bytes);
  }

  static Size? _getImageSizeSync(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return Size(decoded.width.toDouble(), decoded.height.toDouble());
  }

  static Future<Uint8List> editImage({
    required Uint8List input,
    required double cropLeft,
    required double cropTop,
    required double cropWidth,
    required double cropHeight,
    required int rotateDegrees,
    required bool flipHorizontal,
    required bool flipVertical,
  }) async {
    return await compute(
      _editImageSync,
      _EditImageArgs(
        input: input,
        cropLeft: cropLeft,
        cropTop: cropTop,
        cropWidth: cropWidth,
        cropHeight: cropHeight,
        rotateDegrees: rotateDegrees,
        flipHorizontal: flipHorizontal,
        flipVertical: flipVertical,
      ),
    );
  }
}

class _AutoEnhanceArgs {
  final Uint8List input;
  final double strength;
  _AutoEnhanceArgs(this.input, this.strength);
}

class _FaceEnhanceArgs {
  final Uint8List input;
  final double smoothness;
  final double strength;
  _FaceEnhanceArgs(this.input, this.smoothness, this.strength);
}

class _BgBlurArgs {
  final Uint8List input;
  final double radius;
  _BgBlurArgs(this.input, this.radius);
}

class _EditImageArgs {
  final Uint8List input;
  final double cropLeft;
  final double cropTop;
  final double cropWidth;
  final double cropHeight;
  final int rotateDegrees;
  final bool flipHorizontal;
  final bool flipVertical;

  _EditImageArgs({
    required this.input,
    required this.cropLeft,
    required this.cropTop,
    required this.cropWidth,
    required this.cropHeight,
    required this.rotateDegrees,
    required this.flipHorizontal,
    required this.flipVertical,
  });
}

Uint8List _editImageSync(_EditImageArgs args) {
  var src = img.decodeImage(args.input);
  if (src == null) return args.input;

  // 1. Rotate if needed (angle in degrees, e.g. 90, 180, 270)
  if (args.rotateDegrees != 0) {
    src = img.copyRotate(src, angle: args.rotateDegrees);
  }

  // 2. Flip if needed
  if (args.flipHorizontal) {
    src = img.flipHorizontal(src);
  }
  if (args.flipVertical) {
    src = img.flipVertical(src);
  }

  // 3. Crop if needed (check if bounds are smaller than full image)
  if (args.cropWidth < 0.999 ||
      args.cropHeight < 0.999 ||
      args.cropLeft > 0.001 ||
      args.cropTop > 0.001) {
    final x = (args.cropLeft * src.width).round().clamp(0, src.width - 1);
    final y = (args.cropTop * src.height).round().clamp(0, src.height - 1);
    final w = (args.cropWidth * src.width).round().clamp(1, src.width - x);
    final h = (args.cropHeight * src.height).round().clamp(1, src.height - y);

    src = img.copyCrop(src, x: x, y: y, width: w, height: h);
  }

  return Uint8List.fromList(img.encodeJpg(src, quality: 90));
}

class _UpscaleArgs {
  final Uint8List input;
  final int scale;
  _UpscaleArgs(this.input, this.scale);
}
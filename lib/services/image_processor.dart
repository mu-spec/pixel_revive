import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart' show Size, Rect, Offset;
import 'package:pixel_revive/services/on_device_ml_service.dart';

class ImageProcessor {
  static const int _jpgQuality = 92;
  static const int _pngCompression = 6;

  static img.Image? _decode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (e) {
      debugPrint("❌ Image decode failed: $e");
      return null;
    }
  }

  static Uint8List _encode(img.Image image, {bool forPreview = false}) {
    try {
      if (forPreview) {
        return Uint8List.fromList(img.encodeJpg(image, quality: 70));
      }
      return Uint8List.fromList(img.encodeJpg(image, quality: _jpgQuality));
    } catch (e) {
      debugPrint("❌ Image encode failed: $e");
      return Uint8List.fromList(img.encodePng(image, level: _pngCompression));
    }
  }

  static int _clamp(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

  static img.Image _clone(img.Image src) => img.Image(
    width: src.width, 
    height: src.height, 
    numChannels: src.numChannels
  )..setPixels(src.getBytes());

  static img.Image _sharpen(img.Image src, {double amount = 1.5}) {
    final clone = _clone(src);
    final blurred = img.gaussianBlur(clone, radius: 2);
    final result = _unsharpMask(src, blurred, amount: amount);
    clone.dispose();
    blurred.dispose();
    return result;
  }

  static img.Image _unsharpMask(img.Image original, img.Image blurred, {
    double amount = 1.5, 
    double noiseThreshold = 2.0
  }) {
    final w = original.width;
    final h = original.height;
    final out = img.Image(width: w, height: h, numChannels: 4);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final orig = original.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        int comp(int o, int b) {
          final diff = o - b;
          if (diff.abs() < noiseThreshold) return o;
          return _clamp((o + diff * amount).toInt());
        }

        out.setPixel(x, y, img.ColorRgba8(
          comp(orig.r.toInt(), blur.r.toInt()),
          comp(orig.g.toInt(), blur.g.toInt()),
          comp(orig.b.toInt(), blur.b.toInt()),
          orig.a.toInt(),
        ));
      }
    }
    return out;
  }

  // ADVANCED EDGE-PRESERVING LUMINANCE BILATERAL DENOISE
  static img.Image _advancedDenoise(img.Image src, {double sigmaR = 32.0}) {
    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h, numChannels: 4);

    double getSpaceWeight(int kx, int ky) {
      final dSq = kx * kx + ky * ky;
      if (dSq == 0) return 1.0;
      if (dSq == 1) return 0.857;
      if (dSq == 2) return 0.735;
      if (dSq == 4) return 0.539;
      if (dSq == 5) return 0.462;
      return 0.291;
    }

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (x < 2 || y < 2 || x >= w - 2 || y >= h - 2) {
          out.setPixel(x, y, src.getPixel(x, y));
          continue;
        }

        final center = src.getPixel(x, y);
        final double cLum = 0.299 * center.r + 0.587 * center.g + 0.114 * center.b;

        double sumR = 0, sumG = 0, sumB = 0;
        double totalWeight = 0;

        for (int ky = -2; ky <= 2; ky++) {
          for (int kx = -2; kx <= 2; kx++) {
            final neighbor = src.getPixel(x + kx, y + ky);
            final double nLum = 0.299 * neighbor.r + 0.587 * neighbor.g + 0.114 * neighbor.b;
            
            final double lumDist = (cLum - nLum).abs();
            final double rangeWeight = math.exp(-(lumDist * lumDist) / (2 * sigmaR * sigmaR));
            final double weight = getSpaceWeight(kx, ky) * rangeWeight;

            sumR += neighbor.r * weight;
            sumG += neighbor.g * weight;
            sumB += neighbor.b * weight;
            totalWeight += weight;
          }
        }

        out.setPixel(x, y, img.ColorRgba8(
          (sumR / totalWeight).round().clamp(0, 255),
          (sumG / totalWeight).round().clamp(0, 255),
          (sumB / totalWeight).round().clamp(0, 255),
          center.a.toInt(),
        ));
      }
    }

    return out;
  }

  static img.Image _lightDenoise(img.Image src) {
    return _advancedDenoise(src, sigmaR: 28.0);
  }

  // FILTER 1: AUTO ENHANCE
  static Future<Uint8List> autoEnhance(Uint8List input, {double strength = 0.8}) async {
    return await compute(_autoEnhanceSync, _AutoEnhanceArgs(input, strength));
  }

  static Uint8List _autoEnhanceSync(_AutoEnhanceArgs args) {
    final src = _decode(args.input);
    if (src == null) return args.input;

    final contrastVal = 1.0 + args.strength * 0.45;
    final satVal = 1.0 + args.strength * 0.50;
    final brightVal = 1.0 + args.strength * 0.15;

    var out = img.adjustColor(src, contrast: contrastVal, saturation: satVal, brightness: brightVal);
    
    out = _sharpen(out, amount: args.strength * 2.0);
    
    if (args.strength > 0.5) {
      out = _lightDenoise(out);
    }
    
    src.dispose();
    final result = _encode(out);
    out.dispose();
    return result;
  }

  // FILTER 2: HD UPSCALE (2X AND 4X)
  static Future<Uint8List> upscale(Uint8List input, {int scale = 2}) async {
    return await compute(_upscaleSync, _UpscaleArgs(input, scale.clamp(2, 4)));
  }

  static Uint8List _upscaleSync(_UpscaleArgs args) {
    final src = _decode(args.input);
    if (src == null) return args.input;

    final maxDim = 2400 * args.scale;
    final newW = (src.width * args.scale).clamp(1, maxDim).toInt();
    final newH = (src.height * args.scale).clamp(1, maxDim).toInt();

    final interpolation = args.scale >= 4 ? img.Interpolation.lanczos : img.Interpolation.cubic;
    
    var out = img.copyResize(src, width: newW, height: newH, interpolation: interpolation);
    
    out = _sharpen(out, amount: 1.2);
    
    if (args.scale >= 4) {
      final temp = _sharpen(out, amount: 0.8);
      out.dispose();
      out = temp;
    }
    
    src.dispose();
    final result = _encode(out);
    out.dispose();
    return result;
  }

  // FILTER 3: FACE ENHANCE (UPGRADED WITH EYES/SKIN SEPARATION)
  static Future<Uint8List> faceEnhance(Uint8List input, {double smoothness = 0.5, double strength = 0.8}) async {
    final faceRegions = await OnDeviceMlService.detectFaceRegions(input);
    return await compute(_faceEnhanceSync, _FaceEnhanceArgs(input, smoothness, strength, faceRegions));
  }

  static Uint8List _faceEnhanceSync(_FaceEnhanceArgs args) {
    final src = _decode(args.input);
    if (src == null) return args.input;

    final w = src.width;
    final h = src.height;

    final int rRadius = (args.smoothness * 6 + 1).round().clamp(1, 6);
    
    final clone = _clone(src);
    final blurred = img.gaussianBlur(clone, radius: rRadius);
    clone.dispose();

    final out = img.Image(width: w, height: h, numChannels: 4);
    final int threshold = (12 + args.smoothness * 28).round();

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final orig = src.getPixel(x, y);
        final pOffset = Offset(x.toDouble(), y.toDouble());

        bool inEyeMouth = false;
        bool inFaceSkin = args.faceRegions.isEmpty;

        for (final region in args.faceRegions) {
          if (region.leftEye.inflate(6.0).contains(pOffset) ||
              region.rightEye.inflate(6.0).contains(pOffset) ||
              region.mouth.inflate(6.0).contains(pOffset)) {
            inEyeMouth = true;
            break;
          }
          if (region.boundingBox.inflate(12.0).contains(pOffset)) {
            inFaceSkin = true;
          }
        }

        if (inEyeMouth) {
          // Eye & Lip detail region: high-clarity sharpness boost
          final blur = blurred.getPixel(x, y);
          int detail(int o, int b) {
            final diff = o - b;
            return _clamp((o + diff * (1.5 + args.strength * 1.5)).toInt());
          }
          out.setPixel(x, y, img.ColorRgba8(
            detail(orig.r.toInt(), blur.r.toInt()),
            detail(orig.g.toInt(), blur.g.toInt()),
            detail(orig.b.toInt(), blur.b.toInt()),
            orig.a.toInt(),
          ));
        } else if (inFaceSkin) {
          // Skin region: Edge-preserving smoothing
          final blur = blurred.getPixel(x, y);
          final int rDiff = (orig.r - blur.r).abs().toInt();
          final int gDiff = (orig.g - blur.g).abs().toInt();
          final int bDiff = (orig.b - blur.b).abs().toInt();
          final double diff = (rDiff + gDiff + bDiff) / 3.0;

          double smoothWeight = (1.0 - (diff / threshold)).clamp(0.0, 1.0);
          smoothWeight = smoothWeight * smoothWeight;

          out.setPixel(x, y, img.ColorRgba8(
            (orig.r * (1.0 - smoothWeight) + blur.r * smoothWeight).toInt(),
            (orig.g * (1.0 - smoothWeight) + blur.g * smoothWeight).toInt(),
            (orig.b * (1.0 - smoothWeight) + blur.b * smoothWeight).toInt(),
            orig.a.toInt(),
          ));
        } else {
          out.setPixel(x, y, orig);
        }
      }
    }

    blurred.dispose();

    var adjusted = img.adjustColor(out,
      contrast: 1.08 + args.strength * 0.18,
      brightness: 1.0 + args.strength * 0.08,
      saturation: 1.05 + args.strength * 0.20,
    );
    out.dispose();

    adjusted = _sharpen(adjusted, amount: args.strength * 1.4);
    
    src.dispose();
    final result = _encode(adjusted);
    adjusted.dispose();
    return result;
  }

  // FILTER 4: BACKGROUND BLUR (BOKEH)
  static Future<Uint8List> backgroundBlur(Uint8List input, {double radius = 0.6}) async {
    return await compute(_bgBlurSync, _BgBlurArgs(input, radius));
  }

  static Uint8List _bgBlurSync(_BgBlurArgs args) {
    final src = _decode(args.input);
    if (src == null) return args.input;

    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h, numChannels: 4);

    final int bRadius = (args.radius * 16 + 4).round().clamp(4, 20);
    
    final clone = _clone(src);
    final bgBlur = img.gaussianBlur(clone, radius: bRadius);
    clone.dispose();

    final double centerX = w / 2.0;
    final double centerY = h / 2.0;
    final double maxDist = math.sqrt(centerX * centerX + centerY * centerY);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double dx = x - centerX;
        final double dy = y - centerY;
        final double dist = math.sqrt(dx * dx + dy * dy);
        final double normDist = dist / maxDist;

        double blurWeight = ((normDist - 0.25) / 0.50).clamp(0.0, 1.0);
        blurWeight = 3 * blurWeight * blurWeight - 2 * blurWeight * blurWeight * blurWeight;

        final orig = src.getPixel(x, y);
        final bg = bgBlur.getPixel(x, y);

        out.setPixel(x, y, img.ColorRgba8(
          (orig.r * (1.0 - blurWeight) + bg.r * blurWeight).toInt(),
          (orig.g * (1.0 - blurWeight) + bg.g * blurWeight).toInt(),
          (orig.b * (1.0 - blurWeight) + bg.b * blurWeight).toInt(),
          orig.a.toInt(),
        ));
      }
    }

    bgBlur.dispose();
    src.dispose();
    final result = _encode(out);
    out.dispose();
    return result;
  }

  // FILTER 5: DENOISE (UPGRADED WITH 5X5 BILATERAL FILTERING)
  static Future<Uint8List> denoise(Uint8List input) async {
    return await compute(_denoiseSync, input);
  }

  static Uint8List _denoiseSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    var denoised = _advancedDenoise(src, sigmaR: 35.0);
    src.dispose();

    final clone = _clone(denoised);
    final blurred = img.gaussianBlur(clone, radius: 1);
    var sharpened = _unsharpMask(denoised, blurred, amount: 1.3, noiseThreshold: 3.0);
    clone.dispose();
    blurred.dispose();
    denoised.dispose();

    final result = _encode(sharpened);
    sharpened.dispose();
    return result;
  }

  // FILTER 6: UNBLUR
  static Future<Uint8List> unblur(Uint8List input) async {
    return await compute(_unblurSync, input);
  }

  static Uint8List _unblurSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final clone = _clone(src);
    final blurred = img.gaussianBlur(clone, radius: 2);
    var out = _unsharpMask(src, blurred, amount: 2.5);
    
    clone.dispose();
    blurred.dispose();
    
    final clone2 = _clone(out);
    final blurred2 = img.gaussianBlur(clone2, radius: 1);
    final out2 = _unsharpMask(out, blurred2, amount: 1.5);
    
    clone2.dispose();
    blurred2.dispose();
    out.dispose();
    
    out = img.adjustColor(out2, contrast: 1.22);
    out2.dispose();
    
    src.dispose();
    final result = _encode(out);
    out.dispose();
    return result;
  }

  // FILTER 7: COLORIZE
  static Future<Uint8List> colorize(Uint8List input) async {
    return await compute(_colorizeSync, input);
  }

  static Uint8List _colorizeSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h, numChannels: 4);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).toInt();

        int r, g, b;
        if (lum < 60) {
          r = (lum * 0.70).round();
          g = (lum * 0.82).round();
          b = (lum * 1.15).round().clamp(0, 255);
        } else if (lum < 185) {
          r = (lum * 1.28).round().clamp(0, 255);
          g = (lum * 0.98).round().clamp(0, 255);
          b = (lum * 0.78).round().clamp(0, 255);
        } else {
          r = (lum * 1.06).round().clamp(0, 255);
          g = (lum * 1.02).round().clamp(0, 255);
          b = (lum * 0.92).round().clamp(0, 255);
        }

        out.setPixel(x, y, img.ColorRgba8(r, g, b, p.a.toInt()));
      }
    }

    src.dispose();
    
    var colorEnhanced = img.adjustColor(out, saturation: 1.55, contrast: 1.22);
    out.dispose();
    
    final result = _encode(colorEnhanced);
    colorEnhanced.dispose();
    return result;
  }

  // FILTER 8: OLD PHOTO RESTORE (UPGRADED PERCENTILE & GRAY-WORLD)
  static Future<Uint8List> restoreOldPhoto(Uint8List input) async {
    return await compute(_restoreOldPhotoSync, input);
  }

  static Uint8List _restoreOldPhotoSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final w = src.width;
    final h = src.height;

    // 1. Robust Percentile Histogram Analysis (ignores dust/scratches)
    final hist = List<int>.filled(256, 0);
    int sampleCount = 0;
    double sumR = 0, sumG = 0, sumB = 0;

    for (int y = 0; y < h; y += 2) {
      for (int x = 0; x < w; x += 2) {
        final p = src.getPixel(x, y);
        final int lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).toInt().clamp(0, 255);
        hist[lum]++;
        sampleCount++;
        sumR += p.r;
        sumG += p.g;
        sumB += p.b;
      }
    }

    int count = 0;
    int lowCut = 0;
    final int lowThresh = (sampleCount * 0.015).round();
    for (int i = 0; i < 256; i++) {
      count += hist[i];
      if (count >= lowThresh) {
        lowCut = i;
        break;
      }
    }

    count = 0;
    int highCut = 255;
    final int highThresh = (sampleCount * 0.015).round();
    for (int i = 255; i >= 0; i--) {
      count += hist[i];
      if (count >= highThresh) {
        highCut = i;
        break;
      }
    }

    final double range = (highCut - lowCut).clamp(15, 255).toDouble();

    // 2. Automatic Gray-World White Balance Correction
    final avgR = sumR / sampleCount;
    final avgG = sumG / sampleCount;
    final avgB = sumB / sampleCount;
    final avgAll = (avgR + avgG + avgB) / 3.0;

    final double gainR = (avgAll / avgR.clamp(1.0, 255.0)).clamp(0.85, 1.25);
    final double gainG = (avgAll / avgG.clamp(1.0, 255.0)).clamp(0.85, 1.25);
    final double gainB = (avgAll / avgB.clamp(1.0, 255.0)).clamp(0.85, 1.35);

    final restored = img.Image(width: w, height: h, numChannels: 4);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        int proc(num val, double gain) {
          double balanced = val * gain;
          return _clamp((((balanced - lowCut) / range) * 255).round());
        }
        restored.setPixel(x, y, img.ColorRgba8(
          proc(p.r, gainR),
          proc(p.g, gainG),
          proc(p.b, gainB),
          p.a.toInt(),
        ));
      }
    }

    src.dispose();

    // 3. Advanced Denoise & Multi-Scale Sharpening
    var denoised = _advancedDenoise(restored, sigmaR: 30.0);
    restored.dispose();

    var enhanced = _sharpen(denoised, amount: 1.8);
    denoised.dispose();

    final result = _encode(enhanced);
    enhanced.dispose();
    return result;
  }

  // FILTER 9: CARTOON EFFECT
  static Future<Uint8List> cartoonEffect(Uint8List input) async {
    return await compute(_cartoonSync, input);
  }

  static Uint8List _cartoonSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final w = src.width;
    final h = src.height;

    var quantized = img.quantize(src, numberOfColors: 16);
    quantized = img.adjustColor(quantized, contrast: 1.25, saturation: 1.45);

    final out = img.Image(width: w, height: h, numChannels: 4);

    const int threshold = 25;

    for (int y = 0; y < h - 1; y++) {
      for (int x = 0; x < w - 1; x++) {
        final orig = quantized.getPixel(x, y);
        final pRight = quantized.getPixel(x + 1, y);
        final pBottom = quantized.getPixel(x, y + 1);

        final int lum = (0.299 * orig.r + 0.587 * orig.g + 0.114 * orig.b).toInt();
        final int lumR = (0.299 * pRight.r + 0.587 * pRight.g + 0.114 * pRight.b).toInt();
        final int lumB = (0.299 * pBottom.r + 0.587 * pBottom.g + 0.114 * pBottom.b).toInt();

        if ((lum - lumR).abs() > threshold || (lum - lumB).abs() > threshold) {
          out.setPixel(x, y, img.ColorRgba8(10, 10, 20, orig.a.toInt()));
        } else {
          out.setPixel(x, y, orig);
        }
      }
    }
    
    for (int x = 0; x < w; x++) {
      out.setPixel(x, h - 1, quantized.getPixel(x, h - 1));
    }
    for (int y = 0; y < h; y++) {
      out.setPixel(w - 1, y, quantized.getPixel(w - 1, y));
    }

    quantized.dispose();
    src.dispose();
    final result = _encode(out);
    out.dispose();
    return result;
  }

  // FILTER 10: BACKGROUND CLEANUP
  static Future<Uint8List> backgroundCleanup(Uint8List input) async {
    return await compute(_bgCleanupSync, input);
  }

  static Uint8List _bgCleanupSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h, numChannels: 4);

    final double centerX = w / 2.0;
    final double centerY = h / 2.0;
    final double maxDist = math.sqrt(centerX * centerX + centerY * centerY);

    final blurred = img.gaussianBlur(_clone(src), radius: 8);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double dx = x - centerX;
        final double dy = y - centerY;
        final double dist = math.sqrt(dx * dx + dy * dy);
        final double normDist = dist / maxDist;

        final orig = src.getPixel(x, y);

        if (normDist > 0.40) {
          final double factor = ((normDist - 0.40) / 0.60).clamp(0.0, 1.0);
          
          final int r = (orig.r * (1.0 - factor) + 15 * factor).round();
          final int g = (orig.g * (1.0 - factor) + 17 * factor).round();
          final int b = (orig.b * (1.0 - factor) + 25 * factor).round();
          
          out.setPixel(x, y, img.ColorRgba8(r, g, b, orig.a.toInt()));
        } else {
          out.setPixel(x, y, orig);
        }
      }
    }

    blurred.dispose();
    src.dispose();
    final result = _encode(out);
    out.dispose();
    return result;
  }

  // WATERMARK
  static Future<Uint8List> applyWatermark(Uint8List input) async {
    return await compute(_applyWatermarkSync, input);
  }

  static Uint8List _applyWatermarkSync(Uint8List input) {
    final src = _decode(input);
    if (src == null) return input;

    final out = _clone(src);
    final font = img.arial14;
    const text = 'PixelRevive';

    final x = 24;
    final y = out.height - 40;

    img.drawString(out, text, font: font, x: x + 1, y: y + 1, color: img.ColorRgba8(0, 0, 0, 150));
    img.drawString(out, text, font: font, x: x, y: y, color: img.ColorRgba8(255, 255, 255, 180));

    src.dispose();
    final result = _encode(out);
    out.dispose();
    return result;
  }

  // FAST PREVIEW
  static Future<Uint8List> fastPreview(Uint8List input, {double contrast = 1.3, double saturation = 1.3, double sharpness = 1.0}) async {
    return await compute(_fastPreviewSync, _FastPreviewArgs(input, contrast, saturation, sharpness));
  }

  static Uint8List _fastPreviewSync(_FastPreviewArgs args) {
    final src = _decode(args.input);
    if (src == null) return args.input;

    var out = img.adjustColor(src, contrast: args.contrast, saturation: args.saturation);
    
    if (args.sharpness > 0) {
      out = _sharpen(out, amount: args.sharpness);
    }
    
    src.dispose();
    final result = _encode(out, forPreview: true);
    out.dispose();
    return result;
  }
}

// ARGUMENT CLASSES
class _AutoEnhanceArgs {
  final Uint8List input;
  final double strength;
  _AutoEnhanceArgs(this.input, this.strength);
}

class _FaceEnhanceArgs {
  final Uint8List input;
  final double smoothness;
  final double strength;
  final List<FaceRegion> faceRegions;
  _FaceEnhanceArgs(this.input, this.smoothness, this.strength, this.faceRegions);
}

class _BgBlurArgs {
  final Uint8List input;
  final double radius;
  _BgBlurArgs(this.input, this.radius);
}

class _UpscaleArgs {
  final Uint8List input;
  final int scale;
  _UpscaleArgs(this.input, this.scale);
}

class _FastPreviewArgs {
  final Uint8List input;
  final double contrast;
  final double saturation;
  final double sharpness;
  _FastPreviewArgs(this.input, this.contrast, this.saturation, this.sharpness);
}

void debugPrint(String message) {
  assert(() {
    // ignore: avoid_print
    print(message);
    return true;
  }());
}
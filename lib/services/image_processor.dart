import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart' show Size, Rect, Offset;
import 'package:pixel_revive/services/on_device_ml_service.dart';

/// =============================================
/// IMAGE PROCESSOR (optimised for speed)
/// =============================================
/// Performance notes:
/// • All heavy inner loops operate on flat RGBA8 [Uint8List] buffers via direct
///   index math instead of img.getPixel/setPixel (which allocate a Pixel object
///   per call and are ~10–50× slower in tight loops).
/// • Large inputs are downscaled to a working resolution before local-only
///   features run. A 1920px image is ~3.5× more pixels than needed for on-phone
///   viewing; capping it removes that cost with negligible visible quality loss.
/// • Gaussian blur is approximated by separable running-sum box blur (O(n)
///   regardless of radius) — far faster than the package implementation.
/// • Bilateral denoise uses a 3×3 (9-tap) kernel instead of 5×5 (25-tap).
/// • Redundant passes were collapsed (e.g. unblur: 5 passes → 2).
/// =============================================

class ImageProcessor {
  static const int _jpgQuality = 92;
  static const int _pngCompression = 6;

  /// Max working dimension (longest side) for local-only features.
  /// Keep local/offline tools responsive on budget phones. Cloud/HD export still
  /// uses its own higher quality pipeline; these caps only affect on-device tools.
  static const int _maxWorkDim = 1400;
  static const int _fastWorkDim = 1200;
  static const int _heavyWorkDim = 1100;
  static const int _mlWorkDim = 1000;
  static const int _cartoonWorkDim = 850;

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
      return Uint8List.fromList(
        img.encodeJpg(image, quality: forPreview ? 70 : _jpgQuality),
      );
    } catch (e) {
      debugPrint("❌ Image encode failed: $e");
      return Uint8List.fromList(img.encodePng(image, level: _pngCompression));
    }
  }

  static int _clampByte(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

  // ── DECODE / NORMALISE / DOWNSCALE ──────────────────
  /// Decodes + (optionally) downscales to <= [maxDim] longest side.
  /// Returns null if decode fails (caller returns original input).
  /// Creates a lightweight preview copy for fast UI/cloud preview processing.
  /// This keeps the original full/HD bytes available for final export.
  static Future<Uint8List> preparePreview(
    Uint8List input, {
    int maxDimension = 1024,
    int quality = 76,
  }) async {
    return await compute(
      _preparePreviewSync,
      _PreviewPrepareArgs(input, maxDimension, quality),
    );
  }

  static Uint8List _preparePreviewSync(_PreviewPrepareArgs args) {
    final src = _prepare(args.input, maxDim: args.maxDimension);
    if (src == null) return args.input;
    try {
      return Uint8List.fromList(img.encodeJpg(src, quality: args.quality.clamp(50, 95).toInt()));
    } catch (_) {
      return Uint8List.fromList(img.encodePng(src, level: _pngCompression));
    }
  }

  static img.Image? _prepare(Uint8List bytes, {int maxDim = _maxWorkDim}) {
    final src = _decode(bytes);
    if (src == null) return null;

    // Normalise to a plain 4-channel image (JPGs decode to 3 channels).
    if (src.numChannels != 4) {
      try {
        final converted = src.convert(numChannels: 4);
        if (converted != null) {
          return _processPrepared(converted, maxDim);
        }
      } catch (_) {
        // Fallback: manual conversion pixel by pixel
      }
      // Manual fallback if convert() returned null or threw
      final w = src.width;
      final h = src.height;
      final conv = img.Image(width: w, height: h, numChannels: 4);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = src.getPixel(x, y);
          conv.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 255);
        }
      }
      return _processPrepared(conv, maxDim);
    }

    return _processPrepared(src, maxDim);
  }

  static img.Image _processPrepared(img.Image src, int maxDim) {
    final longest = math.max(src.width, src.height);
    if (longest > maxDim) {
      final scale = maxDim / longest;
      return img.copyResize(
        src,
        width: (src.width * scale).round(),
        height: (src.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }
    return src;
  }

  // ── FLAT BUFFER HELPERS (fast, allocation-free inner loops) ──
  static Uint8List _toRgba8(img.Image image) {
    return image.getBytes(); // numChannels == 4 → interleaved RGBA8
  }

  static img.Image _fromRgba8(int w, int h, Uint8List bytes) {
    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: bytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  // ── SEPARABLE RUNNING-SUM BOX BLUR (O(n), gaussian approximation) ──
  static void _boxBlurH(Uint8List src, Uint8List dst, int w, int h, int r) {
    final div = (2 * r + 1).toDouble();
    for (int y = 0; y < h; y++) {
      int sr = 0, sg = 0, sb = 0;
      final rowStart = y * w;
      // init window
      for (int k = -r; k <= r; k++) {
        final xi = k < 0 ? 0 : (k >= w ? w - 1 : k);
        final idx = (rowStart + xi) * 4;
        sr += src[idx];
        sg += src[idx + 1];
        sb += src[idx + 2];
      }
      for (int x = 0; x < w; x++) {
        final o = (rowStart + x) * 4;
        dst[o] = (sr / div).round();
        dst[o + 1] = (sg / div).round();
        dst[o + 2] = (sb / div).round();
        dst[o + 3] = src[o + 3];
        final xOut = (x - r) < 0 ? 0 : x - r;
        final xIn = (x + r + 1) >= w ? w - 1 : x + r + 1;
        final iOut = (rowStart + xOut) * 4;
        final iIn = (rowStart + xIn) * 4;
        sr += src[iIn] - src[iOut];
        sg += src[iIn + 1] - src[iOut + 1];
        sb += src[iIn + 2] - src[iOut + 2];
      }
    }
  }

  static void _boxBlurV(Uint8List src, Uint8List dst, int w, int h, int r) {
    final div = (2 * r + 1).toDouble();
    for (int x = 0; x < w; x++) {
      int sr = 0, sg = 0, sb = 0;
      for (int k = -r; k <= r; k++) {
        final yi = k < 0 ? 0 : (k >= h ? h - 1 : k);
        final idx = (yi * w + x) * 4;
        sr += src[idx];
        sg += src[idx + 1];
        sb += src[idx + 2];
      }
      for (int y = 0; y < h; y++) {
        final o = (y * w + x) * 4;
        dst[o] = (sr / div).round();
        dst[o + 1] = (sg / div).round();
        dst[o + 2] = (sb / div).round();
        dst[o + 3] = src[o + 3];
        final yOut = (y - r) < 0 ? 0 : y - r;
        final yIn = (y + r + 1) >= h ? h - 1 : y + r + 1;
        final iOut = (yOut * w + x) * 4;
        final iIn = (yIn * w + x) * 4;
        sr += src[iIn] - src[iOut];
        sg += src[iIn + 1] - src[iOut + 1];
        sb += src[iIn + 2] - src[iOut + 2];
      }
    }
  }

  /// 3-pass box blur ≈ gaussian. Returns a new buffer.
  static Uint8List _gaussianBlurFlat(Uint8List src, int w, int h, int radius) {
    if (radius < 1) radius = 1;
    var a = Uint8List(src.length);
    var b = Uint8List(src.length);
    _boxBlurH(src, a, w, h, radius);
    _boxBlurV(a, b, w, h, radius);
    _boxBlurH(b, a, w, h, radius);
    _boxBlurV(a, b, w, h, radius);
    _boxBlurH(b, a, w, h, radius);
    _boxBlurV(a, b, w, h, radius);
    return b;
  }

  // ── UNSHARP MASK (fast, flat) ───────────────────────
  static Uint8List _unsharpFlat(
    Uint8List orig,
    Uint8List blur,
    int w,
    int h,
    double amount,
    double noiseThreshold,
  ) {
    final n = w * h;
    final out = Uint8List(n * 4);
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      for (int c = 0; c < 3; c++) {
        final ov = orig[o + c];
        final diff = ov - blur[o + c];
        out[o + c] = diff.abs() < noiseThreshold
            ? ov
            : _clampByte((ov + diff * amount).toInt());
      }
      out[o + 3] = orig[o + 3];
    }
    return out;
  }

  static Uint8List _sharpenFlat(Uint8List src, int w, int h, double amount) {
    final blur = _gaussianBlurFlat(src, w, h, 2);
    return _unsharpFlat(src, blur, w, h, amount, 2.0);
  }

  // ── 3×3 BILATERAL DENOISE (fast, flat) ──────────────
  static Uint8List _bilateralFlat(Uint8List src, int w, int h, double sigmaR) {
    final n = w * h;
    final out = Uint8List(n * 4);
    // precompute spatial weights for the 3×3 kernel
    const taps = [
      [0, 0, 1.0],
      [1, 0, 0.857], [-1, 0, 0.857], [0, 1, 0.857], [0, -1, 0.857],
      [1, 1, 0.735], [1, -1, 0.735], [-1, 1, 0.735], [-1, -1, 0.735],
    ];
    final inv2s2 = 1.0 / (2 * sigmaR * sigmaR);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final ci = (y * w + x) * 4;
        if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
          out[ci] = src[ci];
          out[ci + 1] = src[ci + 1];
          out[ci + 2] = src[ci + 2];
          out[ci + 3] = src[ci + 3];
          continue;
        }
        final cR = src[ci];
        final cG = src[ci + 1];
        final cB = src[ci + 2];
        final cLum = 0.299 * cR + 0.587 * cG + 0.114 * cB;
        double sR = 0.0, sG = 0.0, sB = 0.0, tw = 0.0;
        for (final t in taps) {
          final ni = ((y + t[1].toInt()) * w + (x + t[0].toInt())) * 4;
          final nLum =
              0.299 * src[ni].toDouble() + 0.587 * src[ni + 1].toDouble() + 0.114 * src[ni + 2].toDouble();
          final ld = (cLum - nLum).abs();
          final rw = math.exp(-(ld * ld) * inv2s2);
          final weight = t[2] * rw;
          sR += src[ni].toDouble() * weight;
          sG += src[ni + 1].toDouble() * weight;
          sB += src[ni + 2].toDouble() * weight;
          tw += weight;
        }
        out[ci] = (sR / tw).round().clamp(0, 255);
        out[ci + 1] = (sG / tw).round().clamp(0, 255);
        out[ci + 2] = (sB / tw).round().clamp(0, 255);
      }
    }
    // alpha is copied here so we never touch it inside the weighted loop.
    for (int i = 0; i < n; i++) {
      out[i * 4 + 3] = src[i * 4 + 3];
    }
    return out;
  }

  // ── COLOR ADJUST (brightness/contrast/saturation) via precomputed LUT ──
  static Uint8List _adjustFlat(
    Uint8List src,
    int w,
    int h,
    double brightness,
    double contrast,
    double saturation,
  ) {
    final n = w * h;
    final out = Uint8List(n * 4);
    final lut = Uint8List(256);
    for (int i = 0; i < 256; i++) {
      final v = ((i * brightness) - 128) * contrast + 128;
      lut[i] = v.round().clamp(0, 255);
    }
    final doSat = (saturation - 1.0).abs() > 0.001;
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      int r = lut[src[o]];
      int g = lut[src[o + 1]];
      int b = lut[src[o + 2]];
      if (doSat) {
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        r = (lum + (r - lum) * saturation).round().clamp(0, 255);
        g = (lum + (g - lum) * saturation).round().clamp(0, 255);
        b = (lum + (b - lum) * saturation).round().clamp(0, 255);
      }
      out[o] = r;
      out[o + 1] = g;
      out[o + 2] = b;
      out[o + 3] = src[o + 3];
    }
    return out;
  }


  // ── PROFESSIONAL LOCAL ENHANCEMENT HELPERS ─────────
  /// Gray-world white balance with clamped gains. Removes common yellow/blue
  /// casts without the heavy cost of full color-science pipelines.
  static Uint8List _grayWorldWhiteBalanceFlat(Uint8List src, int w, int h) {
    final n = w * h;
    double sumR = 1, sumG = 1, sumB = 1;
    int samples = 1;
    // sample every other pixel for speed
    for (int i = 0; i < n; i += 2) {
      final o = i * 4;
      final r = src[o], g = src[o + 1], b = src[o + 2];
      // skip near-black/near-white pixels; they skew white balance
      final lum = (r + g + b) ~/ 3;
      if (lum > 18 && lum < 238) {
        sumR += r;
        sumG += g;
        sumB += b;
        samples++;
      }
    }
    final avgR = sumR / samples;
    final avgG = sumG / samples;
    final avgB = sumB / samples;
    final avg = (avgR + avgG + avgB) / 3.0;
    final gainR = (avg / avgR).clamp(0.82, 1.22);
    final gainG = (avg / avgG).clamp(0.88, 1.14);
    final gainB = (avg / avgB).clamp(0.82, 1.28);

    final out = Uint8List(src.length);
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      out[o] = _clampByte((src[o] * gainR).round());
      out[o + 1] = _clampByte((src[o + 1] * gainG).round());
      out[o + 2] = _clampByte((src[o + 2] * gainB).round());
      out[o + 3] = src[o + 3];
    }
    return out;
  }

  /// Vibrance boosts dull colors more than already-saturated colors. This looks
  /// more natural than a simple saturation multiplier, especially for faces.
  static Uint8List _vibranceFlat(Uint8List src, int w, int h, double amount) {
    final n = w * h;
    final out = Uint8List(src.length);
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      final r = src[o].toDouble();
      final g = src[o + 1].toDouble();
      final b = src[o + 2].toDouble();
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final sat = (maxC - minC) / 255.0;
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      final boost = amount * (1.0 - sat).clamp(0.0, 1.0);
      out[o] = (lum + (r - lum) * (1.0 + boost)).round().clamp(0, 255);
      out[o + 1] = (lum + (g - lum) * (1.0 + boost)).round().clamp(0, 255);
      out[o + 2] = (lum + (b - lum) * (1.0 + boost)).round().clamp(0, 255);
      out[o + 3] = src[o + 3];
    }
    return out;
  }

  /// Local contrast / clarity. Adds mid-size detail without changing global
  /// exposure too aggressively. Radius is capped for mobile speed.
  static Uint8List _clarityFlat(Uint8List src, int w, int h, double amount, int radius) {
    final blur = _gaussianBlurFlat(src, w, h, radius.clamp(2, 8));
    final n = w * h;
    final out = Uint8List(src.length);
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      for (int c = 0; c < 3; c++) {
        final v = src[o + c];
        final diff = v - blur[o + c];
        // Avoid boosting tiny noise; enhance real mid-tone texture.
        out[o + c] = diff.abs() < 3 ? v : _clampByte((v + diff * amount).round());
      }
      out[o + 3] = src[o + 3];
    }
    return out;
  }

  /// Gentle gamma lift/darken via LUT. gamma < 1 brightens shadows, gamma > 1 darkens.
  static Uint8List _gammaFlat(Uint8List src, int w, int h, double gamma) {
    final lut = Uint8List(256);
    final inv = 1.0 / gamma.clamp(0.35, 2.5);
    for (int i = 0; i < 256; i++) {
      lut[i] = (math.pow(i / 255.0, inv) * 255.0).round().clamp(0, 255);
    }
    final out = Uint8List(src.length);
    final n = w * h;
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      out[o] = lut[src[o]];
      out[o + 1] = lut[src[o + 1]];
      out[o + 2] = lut[src[o + 2]];
      out[o + 3] = src[o + 3];
    }
    return out;
  }

  // ── CLAHE: Contrast Limited Adaptive Histogram Equalization ──
  static Uint8List _claheFlat(
    Uint8List src,
    int w,
    int h, {
    double clipLimit = 2.0,
    int tileSize = 64,
  }) {
    final n = w * h;

    int tx = w ~/ tileSize;
    int ty = h ~/ tileSize;
    if (tx < 2) tx = 2;
    if (ty < 2) ty = 2;
    final tileW = w / tx;
    final tileH = h / ty;

    final mappings = List.generate(
        ty, (_) => List.generate(tx, (_) => Float64List(256)));

    for (int tyi = 0; tyi < ty; tyi++) {
      for (int txi = 0; txi < tx; txi++) {
        final x0 = (txi * tileW).floor();
        final y0 = (tyi * tileH).floor();
        final x1 = (txi == tx - 1) ? w : ((txi + 1) * tileW).floor();
        final y1 = (tyi == ty - 1) ? h : ((tyi + 1) * tileH).floor();
        final tilePixels = (x1 - x0) * (y1 - y0);

        final hist = List<int>.filled(256, 0);
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            final o = (y * w + x) * 4;
            final lum = (0.299 * src[o] +
                    0.587 * src[o + 1] +
                    0.114 * src[o + 2])
                .round()
                .clamp(0, 255);
            hist[lum]++;
          }
        }

        final clipCount = (tilePixels * clipLimit / 256.0).floor();
        int excess = 0;
        for (int i = 0; i < 256; i++) {
          if (hist[i] > clipCount) {
            excess += hist[i] - clipCount;
            hist[i] = clipCount;
          }
        }
        final redistrib = excess ~/ 256;
        for (int i = 0; i < 256; i++) {
          hist[i] += redistrib;
        }

        int sum = 0;
        final scale = 255.0 / tilePixels;
        for (int i = 0; i < 256; i++) {
          sum += hist[i];
          mappings[tyi][txi][i] = sum * scale;
        }
      }
    }

    final out = Uint8List(n * 4);
    for (int y = 0; y < h; y++) {
      final fy = (y / tileH) - 0.5;
      int tyi0, tyi1;
      double way;
      if (fy <= 0) {
        tyi0 = 0;
        tyi1 = 0;
        way = 0;
      } else if (fy >= ty - 1) {
        tyi0 = ty - 1;
        tyi1 = ty - 1;
        way = 0;
      } else {
        tyi0 = fy.floor();
        tyi1 = tyi0 + 1;
        way = fy - tyi0;
      }

      for (int x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        final r = src[o];
        final g = src[o + 1];
        final b = src[o + 2];
        final oldLum =
            (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

        final fx = (x / tileW) - 0.5;
        int txi0, txi1;
        double wax;
        if (fx <= 0) {
          txi0 = 0;
          txi1 = 0;
          wax = 0;
        } else if (fx >= tx - 1) {
          txi0 = tx - 1;
          txi1 = tx - 1;
          wax = 0;
        } else {
          txi0 = fx.floor();
          txi1 = txi0 + 1;
          wax = fx - txi0;
        }

        final m00 = mappings[tyi0][txi0][oldLum];
        final m01 = mappings[tyi0][txi1][oldLum];
        final m10 = mappings[tyi1][txi0][oldLum];
        final m11 = mappings[tyi1][txi1][oldLum];
        final top = m00 + (m01 - m00) * wax;
        final bot = m10 + (m11 - m10) * wax;
        final newLum = top + (bot - top) * way;

        if (oldLum > 0) {
          final ratio = newLum / oldLum;
          out[o] = (r * ratio).round().clamp(0, 255);
          out[o + 1] = (g * ratio).round().clamp(0, 255);
          out[o + 2] = (b * ratio).round().clamp(0, 255);
        } else {
          final v = newLum.round().clamp(0, 255);
          out[o] = v;
          out[o + 1] = v;
          out[o + 2] = v;
        }
        out[o + 3] = src[o + 3];
      }
    }
    return out;
  }

  // ── 3×3 MEDIAN FILTER ──
  static Uint8List _median3x3Flat(Uint8List src, int w, int h) {
    final out = Uint8List(src.length);
    final n = w * h;
    final p = List<int>.filled(9, 0);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final ci = (y * w + x) * 4;
        if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
          out[ci] = src[ci];
          out[ci + 1] = src[ci + 1];
          out[ci + 2] = src[ci + 2];
          out[ci + 3] = src[ci + 3];
          continue;
        }
        for (int c = 0; c < 3; c++) {
          p[0] = src[((y - 1) * w + (x - 1)) * 4 + c];
          p[1] = src[((y - 1) * w + x) * 4 + c];
          p[2] = src[((y - 1) * w + (x + 1)) * 4 + c];
          p[3] = src[(y * w + (x - 1)) * 4 + c];
          p[4] = src[ci + c];
          p[5] = src[(y * w + (x + 1)) * 4 + c];
          p[6] = src[((y + 1) * w + (x - 1)) * 4 + c];
          p[7] = src[((y + 1) * w + x) * 4 + c];
          p[8] = src[((y + 1) * w + (x + 1)) * 4 + c];
          p.sort();
          out[ci + c] = p[4];
        }
        out[ci + 3] = src[ci + 3];
      }
    }
    return out;
  }

  // ── LANCZOS RESAMPLING ──
  static Uint8List _lanczosResizeRGB(Uint8List src, int sw, int sh, int dstW, int dstH, {int a = 3}) {
    final xScale = sw / dstW;
    final xWeights = List.generate(dstW, (ox) {
      final center = (ox + 0.5) * xScale - 0.5;
      final left = (center - a).ceil();
      final right = (center + a).floor();
      final ws = <int, double>{};
      double sum = 0;
      for (int ix = left; ix <= right; ix++) {
        final sx = ix < 0 ? 0 : (ix >= sw ? sw - 1 : ix);
        final d = (ix - center).abs();
        if (d < 1e-6) {
          ws[sx] = 1.0;
          sum += 1.0;
        } else if (d < a) {
          final pi = math.pi;
          final v = a * math.sin(pi * d) * math.sin(pi * d / a) / (pi * pi * d * d);
          ws[sx] = v;
          sum += v;
        }
      }
      if (sum != 0) {
        for (final k in ws.keys.toList()) {
          ws[k] = ws[k]! / sum;
        }
      }
      return ws;
    });

    final tmp = Float64List(sh * dstW * 3);
    for (int y = 0; y < sh; y++) {
      for (int ox = 0; ox < dstW; ox++) {
        final ws = xWeights[ox];
        double r = 0, g = 0, b = 0;
        ws.forEach((sx, w) {
          final si = (y * sw + sx) * 3;
          r += src[si] * w;
          g += src[si + 1] * w;
          b += src[si + 2] * w;
        });
        final di = (y * dstW + ox) * 3;
        tmp[di] = r;
        tmp[di + 1] = g;
        tmp[di + 2] = b;
      }
    }

    final yScale = sh / dstH;
    final yWeights = List.generate(dstH, (oy) {
      final center = (oy + 0.5) * yScale - 0.5;
      final left = (center - a).ceil();
      final right = (center + a).floor();
      final ws = <int, double>{};
      double sum = 0;
      for (int iy = left; iy <= right; iy++) {
        final sy = iy < 0 ? 0 : (iy >= sh ? sh - 1 : iy);
        final d = (iy - center).abs();
        if (d < 1e-6) {
          ws[sy] = 1.0;
          sum += 1.0;
        } else if (d < a) {
          final pi = math.pi;
          final v = a * math.sin(pi * d) * math.sin(pi * d / a) / (pi * pi * d * d);
          ws[sy] = v;
          sum += v;
        }
      }
      if (sum != 0) {
        for (final k in ws.keys.toList()) {
          ws[k] = ws[k]! / sum;
        }
      }
      return ws;
    });

    final out = Uint8List(dstW * dstH * 3);
    for (int oy = 0; oy < dstH; oy++) {
      final ws = yWeights[oy];
      for (int x = 0; x < dstW; x++) {
        double r = 0, g = 0, b = 0;
        ws.forEach((sy, w) {
          final si = (sy * dstW + x) * 3;
          r += tmp[si] * w;
          g += tmp[si + 1] * w;
          b += tmp[si + 2] * w;
        });
        final di = (oy * dstW + x) * 3;
        out[di] = r.round().clamp(0, 255);
        out[di + 1] = g.round().clamp(0, 255);
        out[di + 2] = b.round().clamp(0, 255);
      }
    }
    return out;
  }

  // ── EDGE-AWARE UNSHARP ──
  static Uint8List _smartUnsharpFlat(Uint8List src, int w, int h, double amount, double radius) {
    final blur = _gaussianBlurFlat(src, w, h, radius.round().clamp(1, 4));
    final n = w * h;
    final out = Uint8List(n * 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
          out[o] = src[o];
          out[o + 1] = src[o + 1];
          out[o + 2] = src[o + 2];
          out[o + 3] = src[o + 3];
          continue;
        }
        double mn = 255, mx = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final ni = ((y + dy) * w + (x + dx)) * 4;
            final lum = 0.299 * src[ni] + 0.587 * src[ni + 1] + 0.114 * src[ni + 2];
            if (lum < mn) mn = lum;
            if (lum > mx) mx = lum;
          }
        }
        final edgeStrength = (mx - mn).clamp(0.0, 60.0) / 60.0;
        final amt = amount * edgeStrength;
        for (int c = 0; c < 3; c++) {
          final ov = src[o + c];
          out[o + c] = _clampByte((ov + (ov - blur[o + c]) * amt).round());
        }
        out[o + 3] = src[o + 3];
      }
    }
    return out;
  }

  // ── KUWAHARA FILTER ──
  static Uint8List _kuwaharaFlat(Uint8List src, int w, int h, {int radius = 3}) {
    final out = Uint8List(src.length);
    final n = w * h;

    final lum = Float64List(n);
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      lum[i] = 0.299 * src[o] + 0.587 * src[o + 1] + 0.114 * src[o + 2];
    }

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final ci = (y * w + x) * 4;
        if (x < radius || y < radius || x >= w - radius || y >= h - radius) {
          out[ci] = src[ci];
          out[ci + 1] = src[ci + 1];
          out[ci + 2] = src[ci + 2];
          out[ci + 3] = src[ci + 3];
          continue;
        }

        double bestVar = 1e18;
        int bestCx = x, bestCy = y;
        for (int qy = 0; qy < 2; qy++) {
          for (int qx = 0; qx < 2; qx++) {
            final x0 = x - radius + qx * radius;
            final y0 = y - radius + qy * radius;
            final x1 = x0 + radius;
            final y1 = y0 + radius;
            double sum = 0, sumSq = 0;
            final count = (radius + 1) * (radius + 1);
            for (int yy = y0; yy <= y1; yy++) {
              for (int xx = x0; xx <= x1; xx++) {
                final lv = lum[yy * w + xx];
                sum += lv;
                sumSq += lv * lv;
              }
            }
            final mean = sum / count;
            final variance = (sumSq / count) - mean * mean;
            if (variance < bestVar) {
              bestVar = variance;
              bestCx = x0 + (radius ~/ 2);
              bestCy = y0 + (radius ~/ 2);
            }
          }
        }

        final si = (bestCy * w + bestCx) * 4;
        out[ci] = src[si];
        out[ci + 1] = src[si + 1];
        out[ci + 2] = src[si + 2];
        out[ci + 3] = src[ci + 3];
      }
    }
    return out;
  }

  // =========================================================
  //  PUBLIC FEATURES
  // =========================================================

  static Future<Uint8List> autoEnhance(Uint8List input, {double strength = 0.8}) async {
    return await compute(_autoEnhanceSync, _AutoEnhanceArgs(input, strength));
  }

  static Uint8List _autoEnhanceSync(_AutoEnhanceArgs args) {
    final sw = Stopwatch()..start();
    final src = _prepare(args.input, maxDim: _fastWorkDim);
    if (src == null) return args.input;
    final w = src.width, h = src.height;
    var buf = _toRgba8(src);

    // Stronger local auto pipeline: white balance → denoise → CLAHE → clarity → vibrance → sharpen.
    buf = _grayWorldWhiteBalanceFlat(buf, w, h);
    if (args.strength > 0.35) {
      buf = _bilateralFlat(buf, w, h, 34.0);
    }
    final cl = 1.7 + args.strength * 2.0;
    buf = _claheFlat(buf, w, h, clipLimit: cl.clamp(1.3, 4.2));
    buf = _gammaFlat(buf, w, h, 0.96);
    buf = _clarityFlat(buf, w, h, 0.20 + args.strength * 0.22, 5);
    buf = _vibranceFlat(buf, w, h, 0.18 + args.strength * 0.30);
    buf = _smartUnsharpFlat(buf, w, h, 0.9 + args.strength * 1.0, 1.5);

    sw.stop();
    debugPrint("⚡ autoEnhance ${w}x${h} in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> upscale(Uint8List input, {int scale = 2}) async {
    return await compute(_upscaleSync, _UpscaleArgs(input, scale.clamp(2, 4)));
  }

  static Uint8List _upscaleSync(_UpscaleArgs args) {
    final sw = Stopwatch()..start();
    var src = _decode(args.input);
    if (src == null) return args.input;
    if (src.numChannels != 4) {
      src = src.convert(numChannels: 4);
    }

    // Local upscale must stay responsive. Keep 2x under ~3200px and 4x under
    // ~4096px; cloud HD export is used for higher quality/larger premium output.
    final maxOutputDim = args.scale >= 4 ? 4096 : 3200;
    final longest = math.max(src.width, src.height);
    final maxInputDim = (maxOutputDim / args.scale).floor();
    if (longest > maxInputDim) {
      final factor = maxInputDim / longest;
      src = img.copyResize(
        src,
        width: (src.width * factor).round().clamp(1, maxInputDim),
        height: (src.height * factor).round().clamp(1, maxInputDim),
        interpolation: img.Interpolation.cubic,
      );
      if (src.numChannels != 4) src = src.convert(numChannels: 4);
    }

    final newW = (src.width * args.scale).clamp(1, maxOutputDim).toInt();
    final newH = (src.height * args.scale).clamp(1, maxOutputDim).toInt();

    final sw0 = src.width, sh0 = src.height;
    final rgbIn = Uint8List(sw0 * sh0 * 3);
    final rgba = src.getBytes();
    for (int i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
      rgbIn[j] = rgba[i];
      rgbIn[j + 1] = rgba[i + 1];
      rgbIn[j + 2] = rgba[i + 2];
    }
    final rgbOut = _lanczosResizeRGB(rgbIn, sw0, sh0, newW, newH, a: 3);

    final out = Uint8List(newW * newH * 4);
    for (int i = 0, j = 0; i < out.length; i += 4, j += 3) {
      out[i] = rgbOut[j];
      out[i + 1] = rgbOut[j + 1];
      out[i + 2] = rgbOut[j + 2];
      out[i + 3] = 255;
    }
    var buf = _smartUnsharpFlat(out, newW, newH, args.scale >= 4 ? 0.8 : 0.6, 2.0);

    sw.stop();
    debugPrint("⚡ upscale ${newW}x$newH (Lanczos) in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(newW, newH, buf));
  }

  static Future<Uint8List> faceEnhance(
    Uint8List input, {
    double smoothness = 0.5,
    double strength = 0.8,
  }) async {
    final prepared = _prepare(input, maxDim: _mlWorkDim);
    if (prepared == null) return input;
    final preparedBytes = Uint8List.fromList(img.encodeJpg(prepared, quality: 88));
    final faceRegions = await OnDeviceMlService.detectFaceRegions(preparedBytes);
    return await compute(
      _faceEnhanceSync,
      _FaceEnhanceArgs(preparedBytes, smoothness, strength, faceRegions),
    );
  }

  static Uint8List _faceEnhanceSync(_FaceEnhanceArgs args) {
    final sw = Stopwatch()..start();
    final src = _prepare(args.input, maxDim: _mlWorkDim);
    if (src == null) return args.input;
    final w = src.width, h = src.height;

    final rRadius = (args.smoothness * 6 + 1).round().clamp(1, 6);
    final blur = _gaussianBlurFlat(_toRgba8(src), w, h, rRadius);
    final orig = _toRgba8(src);
    final out = Uint8List(w * h * 4);
    final threshold = (12 + args.smoothness * 28).round();
    final detailAmt = 1.5 + args.strength * 1.5;

    final List<List<double>> boxes = args.faceRegions.map((r) {
      final b = r.boundingBox;
      final pad = (w * 0.05) + 12.0;
      return [b.left - pad, b.top - pad, b.right + pad, b.bottom + pad];
    }).toList();
    final List<List<double>> eyesMouth = [];
    for (final r in args.faceRegions) {
      for (final e in [r.leftEye, r.rightEye, r.mouth]) {
        final pad = e.width * 3 + 12.0;
        eyesMouth.add([e.left - pad, e.top - pad, e.right + pad, e.bottom + pad]);
      }
    }

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        final oR = orig[o];
        final oG = orig[o + 1];
        final oB = orig[o + 2];
        final a = orig[o + 3];

        bool inEyeMouth = false;
        for (final em in eyesMouth) {
          if (x >= em[0] && x <= em[2] && y >= em[1] && y <= em[3]) {
            inEyeMouth = true;
            break;
          }
        }
        bool inFace = args.faceRegions.isEmpty;
        if (!inEyeMouth) {
          for (final b in boxes) {
            if (x >= b[0] && x <= b[2] && y >= b[1] && y <= b[3]) {
              inFace = true;
              break;
            }
          }
        }

        if (inEyeMouth) {
          out[o] = _clampByte((oR + (oR - blur[o]) * detailAmt).round());
          out[o + 1] = _clampByte((oG + (oG - blur[o + 1]) * detailAmt).round());
          out[o + 2] = _clampByte((oB + (oB - blur[o + 2]) * detailAmt).round());
          out[o + 3] = a;
        } else if (inFace) {
          final diff = (((oR - blur[o]).abs()) +
                  ((oG - blur[o + 1]).abs()) +
                  ((oB - blur[o + 2]).abs())) /
              3.0;
          var sw2 = (1.0 - diff / threshold).clamp(0.0, 1.0);
          sw2 *= sw2;
          out[o] = (oR * (1 - sw2) + blur[o] * sw2).round();
          out[o + 1] = (oG * (1 - sw2) + blur[o + 1] * sw2).round();
          out[o + 2] = (oB * (1 - sw2) + blur[o + 2] * sw2).round();
          out[o + 3] = a;
        } else {
          out[o] = oR;
          out[o + 1] = oG;
          out[o + 2] = oB;
          out[o + 3] = a;
        }
      }
    }

    var buf = _adjustFlat(out, w, h,
        1.0 + args.strength * 0.08, 1.08 + args.strength * 0.18, 1.05 + args.strength * 0.20);
    buf = _sharpenFlat(buf, w, h, args.strength * 1.4);

    sw.stop();
    debugPrint("⚡ faceEnhance ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> backgroundBlur(Uint8List input, {double radius = 0.6}) async {
    final prepared = _prepare(input, maxDim: _mlWorkDim);
    if (prepared == null) return input;
    final preparedBytes = Uint8List.fromList(img.encodeJpg(prepared, quality: 88));
    final faceRegions = await OnDeviceMlService.detectFaceRegions(preparedBytes);
    return await compute(_bgBlurSync, _BgBlurArgs(preparedBytes, radius, faceRegions));
  }

  static Uint8List _bgBlurSync(_BgBlurArgs args) {
    final sw = Stopwatch()..start();
    final src = _prepare(args.input, maxDim: _mlWorkDim);
    if (src == null) return args.input;
    final w = src.width, h = src.height;
    final orig = _toRgba8(src);

    final bRadius = (args.radius * 16 + 4).round().clamp(4, 20);
    final bgBlur = _gaussianBlurFlat(orig, w, h, bRadius);

    final centerX = w / 2.0, centerY = h / 2.0;
    final maxDist = math.sqrt(centerX * centerX + centerY * centerY);

    final faceBoxes = <List<double>>[];
    final facePad = (w * 0.04) + 20.0;
    for (final r in args.faceRegions) {
      final b = r.boundingBox;
      faceBoxes.add([
        b.left - facePad,
        b.top - facePad,
        b.right + facePad,
        b.bottom + facePad,
      ]);
    }
    final hasFaces = faceBoxes.isNotEmpty;

    final out = Uint8List(w * h * 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final o = (y * w + x) * 4;

        double faceKeep = 0.0;
        if (hasFaces) {
          for (final b in faceBoxes) {
            final insideX = (x - b[0]) / (b[2] - b[0]);
            final insideY = (y - b[1]) / (b[3] - b[1]);
            if (insideX > 0 && insideX < 1 && insideY > 0 && insideY < 1) {
              final dx = (insideX - 0.5) * 2.0;
              final dy = (insideY - 0.5) * 2.0;
              final d = math.sqrt(dx * dx + dy * dy).clamp(0.0, 1.0);
              final feathered = (1.0 - d / 0.9).clamp(0.0, 1.0);
              if (feathered > faceKeep) faceKeep = feathered;
            }
          }
        }

        final dx = x - centerX, dy = y - centerY;
        final nd = math.sqrt(dx * dx + dy * dy) / maxDist;
        var bw = ((nd - 0.22) / 0.55).clamp(0.0, 1.0);
        bw = 3 * bw * bw - 2 * bw * bw * bw;
        bw = bw * (1.0 - faceKeep);

        final inv = 1.0 - bw;
        out[o] = (orig[o] * inv + bgBlur[o] * bw).round();
        out[o + 1] = (orig[o + 1] * inv + bgBlur[o + 1] * bw).round();
        out[o + 2] = (orig[o + 2] * inv + bgBlur[o + 2] * bw).round();
        out[o + 3] = orig[o + 3];
      }
    }

    sw.stop();
    debugPrint("⚡ backgroundBlur (feathered) ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, out));
  }

  static Future<Uint8List> denoise(Uint8List input) async {
    return await compute(_denoiseSync, input);
  }

  static Uint8List _denoiseSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input, maxDim: _heavyWorkDim);
    if (src == null) return input;
    final w = src.width, h = src.height;
    var buf = _toRgba8(src);
    // Two-stage denoise: remove salt/pepper noise, then smooth color noise while
    // restoring edges with a conservative detail pass.
    buf = _median3x3Flat(buf, w, h);
    buf = _bilateralFlat(buf, w, h, 42.0);
    buf = _clarityFlat(buf, w, h, 0.18, 4);
    final blur = _gaussianBlurFlat(buf, w, h, 1);
    buf = _unsharpFlat(buf, blur, w, h, 0.9, 4.0);

    sw.stop();
    debugPrint("⚡ denoise ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> unblur(Uint8List input) async {
    return await compute(_unblurSync, input);
  }

  static Uint8List _unblurSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input, maxDim: _fastWorkDim);
    if (src == null) return input;
    final w = src.width, h = src.height;
    var buf = _toRgba8(src);
    buf = _grayWorldWhiteBalanceFlat(buf, w, h);
    buf = _clarityFlat(buf, w, h, 0.28, 4);
    buf = _smartUnsharpFlat(buf, w, h, 2.2, 2.0);
    buf = _smartUnsharpFlat(buf, w, h, 0.9, 1.0);
    buf = _adjustFlat(buf, w, h, 1.0, 1.16, 1.06);

    sw.stop();
    debugPrint("⚡ unblur ${w}x$h (deconv) in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> colorize(Uint8List input) async {
    return await compute(_colorizeSync, input);
  }

  static Uint8List _colorizeSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input, maxDim: _fastWorkDim);
    if (src == null) return input;
    final w = src.width, h = src.height;
    final n = w * h;
    final out = Uint8List(n * 4);
    final inBytes = _toRgba8(src);

    const stops = <List<double>>[
      [0, 16, 20, 34],
      [45, 78, 58, 40],
      [110, 168, 128, 96],
      [175, 206, 178, 150],
      [225, 236, 218, 196],
      [255, 250, 246, 238],
    ];
    final palR = Float64List(256);
    final palG = Float64List(256);
    final palB = Float64List(256);
    for (int L = 0; L < 256; L++) {
      final l = L.toDouble();
      int s = 0;
      for (int i = 0; i < stops.length - 1; i++) {
        if (l >= stops[i][0] && l <= stops[i + 1][0]) {
          s = i;
          break;
        }
        if (l > stops[i][0]) s = i;
      }
      final a0 = stops[s];
      final a1 = stops[s + 1];
      final span = (a1[0] - a0[0]);
      final t = span == 0 ? 0.0 : (l - a0[0]) / span;
      palR[L] = a0[1] + (a1[1] - a0[1]) * t;
      palG[L] = a0[2] + (a1[2] - a0[2]) * t;
      palB[L] = a0[3] + (a1[3] - a0[3]) * t;
    }

    for (int i = 0; i < n; i++) {
      final o = i * 4;
      final lum = (0.299 * inBytes[o] + 0.587 * inBytes[o + 1] + 0.114 * inBytes[o + 2])
          .round()
          .clamp(0, 255);
      var tR = palR[lum];
      var tG = palG[lum];
      var tB = palB[lum];
      final tLum = 0.299 * tR + 0.587 * tG + 0.114 * tB;
      if (tLum > 0) {
        final k = lum / tLum;
        tR *= k;
        tG *= k;
        tB *= k;
      }
      out[o] = tR.round().clamp(0, 255);
      out[o + 1] = tG.round().clamp(0, 255);
      out[o + 2] = tB.round().clamp(0, 255);
      out[o + 3] = inBytes[o + 3];
    }

    var buf = _adjustFlat(out, w, h, 1.0, 1.12, 1.35);
    sw.stop();
    debugPrint("⚡ colorize ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> restoreOldPhoto(Uint8List input) async {
    return await compute(_restoreOldPhotoSync, input);
  }

  static Uint8List _restoreOldPhotoSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input, maxDim: _heavyWorkDim);
    if (src == null) return input;
    final w = src.width, h = src.height;
    final inBytes = _toRgba8(src);

    final hist = List<int>.filled(256, 0);
    int sampleCount = 0;
    double sumR = 0, sumG = 0, sumB = 0;
    for (int y = 0; y < h; y += 2) {
      for (int x = 0; x < w; x += 2) {
        final o = (y * w + x) * 4;
        final lum = (0.299 * inBytes[o] + 0.587 * inBytes[o + 1] + 0.114 * inBytes[o + 2])
            .toInt()
            .clamp(0, 255);
        hist[lum]++;
        sampleCount++;
        sumR += inBytes[o];
        sumG += inBytes[o + 1];
        sumB += inBytes[o + 2];
      }
    }
    int count = 0, lowCut = 0;
    final lowThresh = (sampleCount * 0.015).round();
    for (int i = 0; i < 256; i++) {
      count += hist[i];
      if (count >= lowThresh) {
        lowCut = i;
        break;
      }
    }
    count = 0;
    int highCut = 255;
    final highThresh = (sampleCount * 0.015).round();
    for (int i = 255; i >= 0; i--) {
      count += hist[i];
      if (count >= highThresh) {
        highCut = i;
        break;
      }
    }
    final range = (highCut - lowCut).clamp(15, 255).toDouble();
    final avgAll = (sumR + sumG + sumB) / (3.0 * sampleCount);
    final gainR = (avgAll / sumR * sampleCount).clamp(0.85, 1.25);
    final gainG = (avgAll / sumG * sampleCount).clamp(0.85, 1.25);
    final gainB = (avgAll / sumB * sampleCount).clamp(0.85, 1.35);
    final invRange = 255.0 / range;

    final n = w * h;
    final balanced = Uint8List(n * 4);
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      balanced[o] = _clampByte((((inBytes[o] * gainR) - lowCut) * invRange).round());
      balanced[o + 1] = _clampByte((((inBytes[o + 1] * gainG) - lowCut) * invRange).round());
      balanced[o + 2] = _clampByte((((inBytes[o + 2] * gainB) - lowCut) * invRange).round());
      balanced[o + 3] = inBytes[o + 3];
    }

    var buf = _grayWorldWhiteBalanceFlat(balanced, w, h);
    buf = _claheFlat(buf, w, h, clipLimit: 2.7);
    buf = _median3x3Flat(buf, w, h);
    buf = _bilateralFlat(buf, w, h, 36.0);
    buf = _clarityFlat(buf, w, h, 0.22, 5);
    buf = _vibranceFlat(buf, w, h, 0.18);
    buf = _smartUnsharpFlat(buf, w, h, 1.4, 1.6);

    sw.stop();
    debugPrint("⚡ restoreOldPhoto ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> cartoonEffect(Uint8List input) async {
    return await compute(_cartoonSync, input);
  }

  static Uint8List _cartoonSync(Uint8List input) {
    final sw = Stopwatch()..start();
    var src = _prepare(input, maxDim: _cartoonWorkDim);
    if (src == null) return input;
    final w = src.width, h = src.height;

    var kuwa = _toRgba8(src);
    kuwa = _kuwaharaFlat(kuwa, w, h, radius: 3);

    final smoothed = _fromRgba8(w, h, kuwa);
    var quantized = img.quantize(smoothed, numberOfColors: 14);
    quantized = img.adjustColor(quantized, contrast: 1.18, saturation: 1.5);
    if (quantized.numChannels != 4) quantized = quantized.convert(numChannels: 4);

    final q = quantized.getBytes();
    final out = Uint8List(w * h * 4);
    const threshold = 22;

    for (int y = 0; y < h - 1; y++) {
      for (int x = 0; x < w - 1; x++) {
        final o = (y * w + x) * 4;
        final or = (y * w + x + 1) * 4;
        final ob = ((y + 1) * w + x) * 4;
        final lum = (0.299 * q[o] + 0.587 * q[o + 1] + 0.114 * q[o + 2]).toInt();
        final lumR = (0.299 * q[or] + 0.587 * q[or + 1] + 0.114 * q[or + 2]).toInt();
        final lumB = (0.299 * q[ob] + 0.587 * q[ob + 1] + 0.114 * q[ob + 2]).toInt();
        if ((lum - lumR).abs() > threshold || (lum - lumB).abs() > threshold) {
          out[o] = 12;
          out[o + 1] = 12;
          out[o + 2] = 22;
        } else {
          out[o] = q[o];
          out[o + 1] = q[o + 1];
          out[o + 2] = q[o + 2];
        }
        out[o + 3] = 255;
      }
    }
    for (int x = 0; x < w; x++) {
      final o = ((h - 1) * w + x) * 4;
      out[o] = q[o];
      out[o + 1] = q[o + 1];
      out[o + 2] = q[o + 2];
      out[o + 3] = 255;
    }
    for (int y = 0; y < h; y++) {
      final o = (y * w + w - 1) * 4;
      out[o] = q[o];
      out[o + 1] = q[o + 1];
      out[o + 2] = q[o + 2];
      out[o + 3] = 255;
    }

    sw.stop();
    debugPrint("⚡ cartoonEffect (Kuwahara) ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, out));
  }

  static Future<Uint8List> backgroundCleanup(Uint8List input) async {
    return await compute(_bgCleanupSync, input);
  }

  static Uint8List _bgCleanupSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input, maxDim: _heavyWorkDim);
    if (src == null) return input;
    final w = src.width, h = src.height;
    final inBytes = _toRgba8(src);
    final out = Uint8List(w * h * 4);
    final centerX = w / 2.0, centerY = h / 2.0;
    final maxDist = math.sqrt(centerX * centerX + centerY * centerY);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        final dx = x - centerX, dy = y - centerY;
        final nd = math.sqrt(dx * dx + dy * dy) / maxDist;
        if (nd > 0.40) {
          final f = ((nd - 0.40) / 0.60).clamp(0.0, 1.0);
          final inv = 1.0 - f;
          out[o] = (inBytes[o] * inv + 15 * f).round();
          out[o + 1] = (inBytes[o + 1] * inv + 17 * f).round();
          out[o + 2] = (inBytes[o + 2] * inv + 25 * f).round();
        } else {
          out[o] = inBytes[o];
          out[o + 1] = inBytes[o + 1];
          out[o + 2] = inBytes[o + 2];
        }
        out[o + 3] = inBytes[o + 3];
      }
    }

    sw.stop();
    debugPrint("⚡ backgroundCleanup ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, out));
  }

  static Future<Uint8List> applyWatermark(Uint8List input) async {
    return await compute(_applyWatermarkSync, input);
  }

  static Uint8List _applyWatermarkSync(Uint8List input) {
    var src = _decode(input);
    if (src == null) return input;
    final out = src.clone();
    img.drawString(
      out,
      'PixelRevive',
      font: img.arial14,
      x: 25,
      y: out.height - 40,
      color: img.ColorRgba8(0, 0, 0, 150),
    );
    img.drawString(
      out,
      'PixelRevive',
      font: img.arial14,
      x: 24,
      y: out.height - 41,
      color: img.ColorRgba8(255, 255, 255, 180),
    );
    return _encode(out);
  }

  static Future<Size?> getImageSize(Uint8List input) async {
    final src = _decode(input);
    if (src == null) return null;
    return Size(src.width.toDouble(), src.height.toDouble());
  }

  static Future<Uint8List> editImage({
    required Uint8List input,
    double cropLeft = 0.0,
    double cropTop = 0.0,
    double cropWidth = 1.0,
    double cropHeight = 1.0,
    int rotateDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
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

  static Uint8List _editImageSync(_EditImageArgs args) {
    var edited = _decode(args.input);
    if (edited == null) return args.input;

    final deg = (((args.rotateDegrees % 360) + 360) % 360).toInt();
    if (deg != 0) {
      edited = img.copyRotate(
        edited,
        angle: deg,
        interpolation: img.Interpolation.linear,
      );
    }
    if (args.flipHorizontal) edited = img.flipHorizontal(edited);
    if (args.flipVertical) edited = img.flipVertical(edited);

    final leftN = args.cropLeft.clamp(0.0, 1.0);
    final topN = args.cropTop.clamp(0.0, 1.0);
    final widthN = args.cropWidth.clamp(0.0, 1.0 - leftN);
    final heightN = args.cropHeight.clamp(0.0, 1.0 - topN);
    final x = (leftN * edited.width).round().clamp(0, edited.width - 1);
    final y = (topN * edited.height).round().clamp(0, edited.height - 1);
    final cropW = math.max(1, (widthN * edited.width).round()).clamp(1, edited.width - x);
    final cropH = math.max(1, (heightN * edited.height).round()).clamp(1, edited.height - y);
    final cropped = img.copyCrop(edited, x: x, y: y, width: cropW, height: cropH);
    return _encode(cropped);
  }

  static Future<Uint8List> blendTextures({
    required Uint8List original,
    required Uint8List enhanced,
    double blendFactor = 0.25,
  }) async {
    return await compute(
      _blendTexturesSync,
      _BlendTexturesArgs(
        original: original,
        enhanced: enhanced,
        blendFactor: blendFactor,
      ),
    );
  }

  static Uint8List _blendTexturesSync(_BlendTexturesArgs args) {
    var original = _decode(args.original);
    var enhanced = _decode(args.enhanced);
    if (original == null) return args.enhanced;
    if (enhanced == null) return args.original;
    if (original.numChannels != 4) original = original.convert(numChannels: 4);
    if (enhanced.numChannels != 4) enhanced = enhanced.convert(numChannels: 4);

    if (original.width != enhanced.width || original.height != enhanced.height) {
      original = img.copyResize(original,
          width: enhanced.width, height: enhanced.height, interpolation: img.Interpolation.linear);
    }

    final w = enhanced.width, h = enhanced.height;
    final oBytes = original.getBytes();
    final eBytes = enhanced.getBytes();
    final n = w * h;
    final out = Uint8List(n * 4);
    final ow = args.blendFactor.clamp(0.0, 1.0);
    final ew = 1.0 - ow;
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      out[o] = _clampByte((eBytes[o] * ew + oBytes[o] * ow).round());
      out[o + 1] = _clampByte((eBytes[o + 1] * ew + oBytes[o + 1] * ow).round());
      out[o + 2] = _clampByte((eBytes[o + 2] * ew + oBytes[o + 2] * ow).round());
      out[o + 3] = 255;
    }
    return _encode(_fromRgba8(w, h, out));
  }

  static Future<Uint8List> fastPreview(
    Uint8List input, {
    double contrast = 1.3,
    double saturation = 1.3,
    double sharpness = 1.0,
  }) async {
    return await compute(
      _fastPreviewSync,
      _FastPreviewArgs(input, contrast, saturation, sharpness),
    );
  }

  static Uint8List _fastPreviewSync(_FastPreviewArgs args) {
    final src = _prepare(args.input, maxDim: 900);
    if (src == null) return args.input;
    final w = src.width, h = src.height;
    var buf = _toRgba8(src);
    buf = _adjustFlat(buf, w, h, 1.0, args.contrast, args.saturation);
    if (args.sharpness > 0) buf = _sharpenFlat(buf, w, h, args.sharpness);
    return _encode(_fromRgba8(w, h, buf), forPreview: true);
  }
}

// ── ARGS CLASSES ───────────────────────────────────────
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
  final List<FaceRegion> faceRegions;
  _BgBlurArgs(this.input, this.radius, this.faceRegions);
}

class _UpscaleArgs {
  final Uint8List input;
  final int scale;
  _UpscaleArgs(this.input, this.scale);
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

class _BlendTexturesArgs {
  final Uint8List original;
  final Uint8List enhanced;
  final double blendFactor;
  _BlendTexturesArgs({
    required this.original,
    required this.enhanced,
    required this.blendFactor,
  });
}

class _FastPreviewArgs {
  final Uint8List input;
  final double contrast;
  final double saturation;
  final double sharpness;
  _FastPreviewArgs(this.input, this.contrast, this.saturation, this.sharpness);
}
class _PreviewPrepareArgs {
  final Uint8List input;
  final int maxDimension;
  final int quality;
  _PreviewPrepareArgs(this.input, this.maxDimension, this.quality);
}

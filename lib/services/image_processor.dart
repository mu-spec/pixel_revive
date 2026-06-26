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
  static const int _maxWorkDim = 1400;

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
  static img.Image? _prepare(Uint8List bytes, {int maxDim = _maxWorkDim}) {
    var src = _decode(bytes);
    if (src == null) return null;

    // Normalise to a plain 4-channel image (JPGs decode to 3 channels).
    if (src.numChannels != 4) {
      try {
        src = src.convert(numChannels: 4);
      } catch (_) {
        final conv = img.Image(width: src.width, height: src.height, numChannels: 4);
        for (final p in src) {
          conv.setPixelRgba(p.x, p.y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
        }
        src = conv;
      }
    }

    final longest = math.max(src.width, src.height);
    if (longest > maxDim) {
      final scale = maxDim / longest;
      src = img.copyResize(
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
    return image.toBytes(); // numChannels == 4 → interleaved RGBA8
  }

  static img.Image _fromRgba8(int w, int h, Uint8List bytes) {
    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: bytes,
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
        final cR = src[ci], cG = src[ci + 1], cB = src[ci + 2];
        final cLum = 0.299 * cR + 0.587 * cG + 0.114 * cB;
        double sR = 0, sG = 0, sB = 0, tw = 0;
        for (final t in taps) {
          final ni = ((y + t[1]) * w + (x + t[0])) * 4;
          final nLum =
              0.299 * src[ni] + 0.587 * src[ni + 1] + 0.114 * src[ni + 2];
          final ld = (cLum - nLum).abs();
          final rw = math.exp(-(ld * ld) * inv2s2);
          final weight = t[2] * rw;
          sR += src[ni] * weight;
          sG += src[ni + 1] * weight;
          sB += src[ni + 2] * weight;
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

  // ── COLOR ADJUST (brightness/contrast/saturation) in one flat pass ──
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
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      double r = src[o], g = src[o + 1], b = src[o + 2];
      // brightness
      r *= brightness;
      g *= brightness;
      b *= brightness;
      // contrast around 128
      r = (r - 128) * contrast + 128;
      g = (g - 128) * contrast + 128;
      b = (b - 128) * contrast + 128;
      // saturation toward luma
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      r = lum + (r - lum) * saturation;
      g = lum + (g - lum) * saturation;
      b = lum + (b - lum) * saturation;
      out[o] = _clampByte(r.round());
      out[o + 1] = _clampByte(g.round());
      out[o + 2] = _clampByte(b.round());
      out[o + 3] = src[o + 3];
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
    final src = _prepare(args.input);
    if (src == null) return args.input;
    final w = src.width, h = src.height;
    var buf = _toRgba8(src);

    buf = _adjustFlat(
      buf,
      w,
      h,
      1.0 + args.strength * 0.15,
      1.0 + args.strength * 0.45,
      1.0 + args.strength * 0.50,
    );
    buf = _sharpenFlat(buf, w, h, args.strength * 2.0);
    if (args.strength > 0.5) {
      buf = _bilateralFlat(buf, w, h, 28.0); // light denoise
    }

    sw.stop();
    debugPrint("⚡ autoEnhance ${w}x${h} in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> upscale(Uint8List input, {int scale = 2}) async {
    return await compute(_upscaleSync, _UpscaleArgs(input, scale.clamp(2, 4)));
  }

  static Uint8List _upscaleSync(_UpscaleArgs args) {
    final sw = Stopwatch()..start();
    // Decode at FULL resolution (do not cap — this is an upscale feature).
    var src = _decode(args.input);
    if (src == null) return args.input;
    if (src.numChannels != 4) {
      src = src.convert(numChannels: 4);
    }

    final maxDim = 2400 * args.scale;
    final newW = (src.width * args.scale).clamp(1, maxDim).toInt();
    final newH = (src.height * args.scale).clamp(1, maxDim).toInt();

    var out = img.copyResize(
      src,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.linear, // linear ~6× faster than cubic, fine for upscale
    );

    // Light single-pass sharpen on flat buffer.
    final w = out.width, h = out.height;
    var buf = _toRgba8(out);
    buf = _sharpenFlat(buf, w, h, args.scale >= 4 ? 1.1 : 1.0);

    sw.stop();
    debugPrint("⚡ upscale ${newW}x$newH in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> faceEnhance(
    Uint8List input, {
    double smoothness = 0.5,
    double strength = 0.8,
  }) async {
    // Prepare (downscale) FIRST so face detection coordinates match the
    // working-resolution image that the isolate processes.
    final prepared = _prepare(input);
    if (prepared == null) return input;
    final preparedBytes = Uint8List.fromList(img.encodeJpg(prepared, quality: 92));
    final faceRegions = await OnDeviceMlService.detectFaceRegions(preparedBytes);
    return await compute(
      _faceEnhanceSync,
      _FaceEnhanceArgs(preparedBytes, smoothness, strength, faceRegions),
    );
  }

  static Uint8List _faceEnhanceSync(_FaceEnhanceArgs args) {
    final sw = Stopwatch()..start();
    final src = _prepare(args.input);
    if (src == null) return args.input;
    final w = src.width, h = src.height;

    final rRadius = (args.smoothness * 6 + 1).round().clamp(1, 6);
    final blur = _gaussianBlurFlat(_toRgba8(src), w, h, rRadius);
    final orig = _toRgba8(src);
    final out = Uint8List(w * h * 4);
    final threshold = (12 + args.smoothness * 28).round();
    final detailAmt = 1.5 + args.strength * 1.5;

    // Precompute inflated face rects in pixel space for fast inside-tests.
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
        final oR = orig[o], oG = orig[o + 1], oB = orig[o + 2];
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

    // One combined colour/sharpen pass.
    var buf = _adjustFlat(out, w, h,
        1.0 + args.strength * 0.08, 1.08 + args.strength * 0.18, 1.05 + args.strength * 0.20);
    buf = _sharpenFlat(buf, w, h, args.strength * 1.4);

    sw.stop();
    debugPrint("⚡ faceEnhance ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> backgroundBlur(Uint8List input, {double radius = 0.6}) async {
    // Prepare (downscale) FIRST so face coordinates match the working image.
    final prepared = _prepare(input);
    if (prepared == null) return input;
    final preparedBytes = Uint8List.fromList(img.encodeJpg(prepared, quality: 92));
    final faceRegions = await OnDeviceMlService.detectFaceRegions(preparedBytes);
    return await compute(_bgBlurSync, _BgBlurArgs(preparedBytes, radius, faceRegions));
  }

  static Uint8List _bgBlurSync(_BgBlurArgs args) {
    final sw = Stopwatch()..start();
    final src = _prepare(args.input);
    if (src == null) return args.input;
    final w = src.width, h = src.height;
    final orig = _toRgba8(src);

    final bRadius = (args.radius * 16 + 4).round().clamp(4, 20);
    final bgBlur = _gaussianBlurFlat(orig, w, h, bRadius);

    final centerX = w / 2.0, centerY = h / 2.0;
    final maxDist = math.sqrt(centerX * centerX + centerY * centerY);
    final facePad = (w * 0.05) + 24.0;
    final boxes = args.faceRegions.map((r) {
      final b = r.boundingBox;
      return [b.left - facePad, b.top - facePad, b.right + facePad, b.bottom + facePad];
    }).toList();

    final out = Uint8List(w * h * 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        bool keep = false;
        for (final b in boxes) {
          if (x >= b[0] && x <= b[2] && y >= b[1] && y <= b[3]) {
            keep = true;
            break;
          }
        }
        double bw;
        if (keep) {
          bw = 0.0;
        } else {
          final dx = x - centerX, dy = y - centerY;
          final nd = math.sqrt(dx * dx + dy * dy) / maxDist;
          bw = ((nd - 0.25) / 0.50).clamp(0.0, 1.0);
          bw = 3 * bw * bw - 2 * bw * bw * bw;
        }
        final inv = 1.0 - bw;
        out[o] = (orig[o] * inv + bgBlur[o] * bw).round();
        out[o + 1] = (orig[o + 1] * inv + bgBlur[o + 1] * bw).round();
        out[o + 2] = (orig[o + 2] * inv + bgBlur[o + 2] * bw).round();
        out[o + 3] = orig[o + 3];
      }
    }

    sw.stop();
    debugPrint("⚡ backgroundBlur ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, out));
  }

  static Future<Uint8List> denoise(Uint8List input) async {
    return await compute(_denoiseSync, input);
  }

  static Uint8List _denoiseSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input);
    if (src == null) return input;
    final w = src.width, h = src.height;
    var buf = _toRgba8(src);
    buf = _bilateralFlat(buf, w, h, 35.0);
    // light unsharp using the denoised buffer's own blur (single extra blur).
    final blur = _gaussianBlurFlat(buf, w, h, 1);
    buf = _unsharpFlat(buf, blur, w, h, 1.3, 3.0);

    sw.stop();
    debugPrint("⚡ denoise ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> unblur(Uint8List input) async {
    return await compute(_unblurSync, input);
  }

  static Uint8List _unblurSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input);
    if (src == null) return input;
    final w = src.width, h = src.height;
    var buf = _toRgba8(src);
    // Collapse the old 5-pass pipeline into: blur → unsharp(strong) → contrast.
    final blur = _gaussianBlurFlat(buf, w, h, 2);
    buf = _unsharpFlat(buf, blur, w, h, 2.8, 2.0);
    buf = _adjustFlat(buf, w, h, 1.0, 1.22, 1.0);

    sw.stop();
    debugPrint("⚡ unblur ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> colorize(Uint8List input) async {
    return await compute(_colorizeSync, input);
  }

  static Uint8List _colorizeSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input);
    if (src == null) return input;
    final w = src.width, h = src.height;
    final n = w * h;
    final out = Uint8List(n * 4);
    final inBytes = _toRgba8(src);

    for (int i = 0; i < n; i++) {
      final o = i * 4;
      final lum = (0.299 * inBytes[o] + 0.587 * inBytes[o + 1] + 0.114 * inBytes[o + 2]).toInt();
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
      out[o] = r;
      out[o + 1] = g;
      out[o + 2] = b;
      out[o + 3] = inBytes[o + 3];
    }

    var buf = _adjustFlat(out, w, h, 1.0, 1.22, 1.55);
    sw.stop();
    debugPrint("⚡ colorize ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> restoreOldPhoto(Uint8List input) async {
    return await compute(_restoreOldPhotoSync, input);
  }

  static Uint8List _restoreOldPhotoSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input);
    if (src == null) return input;
    final w = src.width, h = src.height;
    final inBytes = _toRgba8(src);

    // ---- 1. histogram + channel balance on a 2× sub-sample ----
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

    // ---- 2. balance + stretch in one flat pass ----
    final n = w * h;
    final balanced = Uint8List(n * 4);
    for (int i = 0; i < n; i++) {
      final o = i * 4;
      balanced[o] = _clampByte((((inBytes[o] * gainR) - lowCut) * invRange).round());
      balanced[o + 1] = _clampByte((((inBytes[o + 1] * gainG) - lowCut) * invRange).round());
      balanced[o + 2] = _clampByte((((inBytes[o + 2] * gainB) - lowCut) * invRange).round());
      balanced[o + 3] = inBytes[o + 3];
    }

    // ---- 3. denoise + sharpen ----
    var buf = _bilateralFlat(balanced, w, h, 30.0);
    buf = _sharpenFlat(buf, w, h, 1.8);

    sw.stop();
    debugPrint("⚡ restoreOldPhoto ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, buf));
  }

  static Future<Uint8List> cartoonEffect(Uint8List input) async {
    return await compute(_cartoonSync, input);
  }

  static Uint8List _cartoonSync(Uint8List input) {
    final sw = Stopwatch()..start();
    var src = _prepare(input);
    if (src == null) return input;
    // quantise + colour-pop via package (single op, acceptable cost at capped size)
    var quantized = img.quantize(src, numberOfColors: 16);
    quantized = img.adjustColor(quantized, contrast: 1.25, saturation: 1.45);
    if (quantized.numChannels != 4) quantized = quantized.convert(numChannels: 4);

    final w = quantized.width, h = quantized.height;
    final q = quantized.toBytes();
    final out = Uint8List(w * h * 4);
    const threshold = 25;

    for (int y = 0; y < h - 1; y++) {
      for (int x = 0; x < w - 1; x++) {
        final o = (y * w + x) * 4;
        final or = (y * w + x + 1) * 4;       // right
        final ob = ((y + 1) * w + x) * 4;     // bottom
        final lum = (0.299 * q[o] + 0.587 * q[o + 1] + 0.114 * q[o + 2]).toInt();
        final lumR = (0.299 * q[or] + 0.587 * q[or + 1] + 0.114 * q[or + 2]).toInt();
        final lumB = (0.299 * q[ob] + 0.587 * q[ob + 1] + 0.114 * q[ob + 2]).toInt();
        if ((lum - lumR).abs() > threshold || (lum - lumB).abs() > threshold) {
          out[o] = 10;
          out[o + 1] = 10;
          out[o + 2] = 20;
        } else {
          out[o] = q[o];
          out[o + 1] = q[o + 1];
          out[o + 2] = q[o + 2];
        }
        out[o + 3] = 255;
      }
    }
    // last row/col passthrough
    for (int x = 0; x < w; x++) {
      final o = ((h - 1) * w + x) * 4;
      out[o] = q[o]; out[o + 1] = q[o + 1]; out[o + 2] = q[o + 2]; out[o + 3] = 255;
    }
    for (int y = 0; y < h; y++) {
      final o = (y * w + w - 1) * 4;
      out[o] = q[o]; out[o + 1] = q[o + 1]; out[o + 2] = q[o + 2]; out[o + 3] = 255;
    }

    sw.stop();
    debugPrint("⚡ cartoonEffect ${w}x$h in ${sw.elapsedMilliseconds}ms");
    return _encode(_fromRgba8(w, h, out));
  }

  static Future<Uint8List> backgroundCleanup(Uint8List input) async {
    return await compute(_bgCleanupSync, input);
  }

  static Uint8List _bgCleanupSync(Uint8List input) {
    final sw = Stopwatch()..start();
    final src = _prepare(input);
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
    final oBytes = original.toBytes();
    final eBytes = enhanced.toBytes();
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

// ── ARGS CLASSES (unchanged signatures) ───────────────
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

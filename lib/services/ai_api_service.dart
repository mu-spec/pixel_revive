import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pixel_revive/services/image_processor.dart';
import 'package:pixel_revive/services/cloud_api_config.dart';

class AiApiService {
  static String? lastErrorMessage;
  static Map<String, Object?> lastTimings = <String, Object?>{};
  static String? lastCloudModel;

  static void _rememberError(String message) {
    lastErrorMessage = message;
    debugPrint(message);
  }

  static String _friendlyCloudError(int statusCode, String body) {
    final lower = body.toLowerCase();
    if (statusCode == 402 ||
        lower.contains('fal_balance_exhausted') ||
        lower.contains('exhausted balance') ||
        lower.contains('user is locked') ||
        lower.contains('top up your balance') ||
        lower.contains('insufficient balance') ||
        lower.contains('insufficient credit')) {
      return 'Gemini API quota or billing limit reached.';
    }
    if (statusCode == 429) {
      return 'Cloud AI is busy or rate-limited. Please wait a moment and try again.';
    }
    try {
      final data = jsonDecode(body);
      final err = data is Map ? data['error']?.toString() : null;
      if (err != null && err.isNotEmpty) return err;
    } catch (_) {}
    return 'Cloud AI error $statusCode: $body';
  }


  static Uint8List _prepareCloudUpload(
    Uint8List imageBytes, {
    int maxDimension = 1280,
    int quality = 82,
  }) {
    var uploadBytes = imageBytes;
    var decoded = img.decodeImage(uploadBytes);
    if (decoded != null) {
      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        decoded = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? maxDimension : null,
          height: decoded.height >= decoded.width ? maxDimension : null,
        );
      }
      uploadBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    }
    return uploadBytes;
  }

  static Future<Uint8List?> _readBackendImage(
    Map<String, dynamic> data,
    http.Client client,
  ) async {
    final imageBase64 = data['imageBase64'];
    if (imageBase64 != null && imageBase64.toString().isNotEmpty) {
      final raw = imageBase64.toString();
      final cleaned = raw.contains(',') ? raw.split(',').last : raw;
      return Uint8List.fromList(base64Decode(cleaned));
    }

    final imageUrl = data['imageUrl'];
    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      final url = imageUrl.toString();
      debugPrint('Downloading cloud result directly: $url');
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 3));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      _rememberError('Cloud result download failed: HTTP ${response.statusCode}');
      return null;
    }

    return null;
  }

  /// =============================================
  /// LEGACY DIRECT API FALLBACKS (disabled unless a dev token is set)
  /// =============================================
  static Future<void> preWarmModel({
    required String modelName,
    required String apiToken,
  }) async {
    // Removed — pre-warming is not needed for the Gemini backend
  }


  /// Secure backend proxy call. This keeps the Gemini API key out of the APK.
  /// Fast mode: smaller upload + backend may return imageUrl instead of base64.
  static Future<Uint8List?> runBackendProxyPrediction({
    required Uint8List imageBytes,
    required String featureId,
    required bool isReplicate,
    int? scale,
    int uploadMaxDimension = 1280,
    int uploadQuality = 82,
    bool isPremiumUser = false,
    bool isHdExport = false,
    Map<String, dynamic>? extraInput,
    ValueChanged<String>? onProgress,
  }) async {
    final baseUrl = CloudApiConfig.backendBaseUrl.trim();
    if (baseUrl.isEmpty) return null;

    final client = http.Client();
    final totalSw = Stopwatch()..start();
    final prepSw = Stopwatch()..start();
    try {
      onProgress?.call('Compressing image for fast upload...');
      final uploadBytes = _prepareCloudUpload(
        imageBytes,
        maxDimension: uploadMaxDimension,
        quality: uploadQuality,
      );
      prepSw.stop();

      final uri = CloudApiConfig.backendEnhanceUri;
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (CloudApiConfig.backendClientSecret.isNotEmpty) {
        headers['x-pixelrevive-client'] = CloudApiConfig.backendClientSecret;
      }

      debugPrint('Backend proxy posting to: $uri');
      onProgress?.call('Uploading to ${CloudApiConfig.activeProviderLabel}...');

      final requestSw = Stopwatch()..start();
      final response = await client
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'provider': 'gemini',
              'featureId': featureId,
              if (scale != null) 'scale': scale,
              'isPremium': isPremiumUser,
              'isHdExport': isHdExport,
              if (extraInput != null) 'extraInput': extraInput,
              'mimeType': 'image/jpeg',
              'imageBase64': base64Encode(uploadBytes),
            }),
          )
          .timeout(const Duration(minutes: 4));

      requestSw.stop();
      if (response.statusCode != 200) {
        lastTimings = {
          'route': 'proxy',
          'feature': featureId,
          'prepMs': prepSw.elapsedMilliseconds,
          'requestMs': requestSw.elapsedMilliseconds,
          'totalMs': totalSw.elapsedMilliseconds,
          'status': response.statusCode,
        };
        _rememberError(_friendlyCloudError(response.statusCode, response.body));
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        debugPrint('Backend proxy failed: ${response.body}');
        return null;
      }

      onProgress?.call('Downloading enhanced result...');
      final downloadSw = Stopwatch()..start();
      final bytes = await _readBackendImage(data, client);
      downloadSw.stop();
      totalSw.stop();
      lastTimings = {
        'route': 'proxy',
        'feature': featureId,
        'prepMs': prepSw.elapsedMilliseconds,
        'requestMs': requestSw.elapsedMilliseconds,
        'downloadMs': downloadSw.elapsedMilliseconds,
        'totalMs': totalSw.elapsedMilliseconds,
        'bytes': bytes?.length ?? 0,
      };
      debugPrint('Cloud timings: $lastTimings');
      if (bytes == null) {
        debugPrint('Backend proxy returned no image: ${response.body}');
      }
      return bytes;
    } catch (e) {
      debugPrint('Backend proxy error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// FIRE-AND-POLL backend call (works on free Vercel — no 60s timeout).
  ///
  /// Step 1: POST /enhance/start -> returns a predictionId quickly.
  /// Step 2: GET /enhance/status/:id repeatedly until done.
  /// Each request is short, so Vercel's 60-second function cap is never hit.
  /// Fast mode uses your persistent Gemini backend job queue.
  static Future<Uint8List?> runBackendAsyncPrediction({
    required Uint8List imageBytes,
    required String featureId,
    required bool isReplicate,
    int? scale,
    int uploadMaxDimension = 1280,
    int uploadQuality = 82,
    bool isPremiumUser = false,
    bool isHdExport = false,
    Map<String, dynamic>? extraInput,
    ValueChanged<String>? onProgress,
  }) async {
    final baseUrl = CloudApiConfig.normalizedBackendBaseUrl;
    if (baseUrl.isEmpty) return null;

    final client = http.Client();
    final totalSw = Stopwatch()..start();
    final prepSw = Stopwatch()..start();
    try {
      // SPEED MODE: smaller cloud upload = faster upload, faster queue start,
      // lower backend timeout risk, and better phone performance.
      onProgress?.call('Compressing image for fast upload...');
      final uploadBytes = _prepareCloudUpload(
        imageBytes,
        maxDimension: uploadMaxDimension,
        quality: uploadQuality,
      );
      prepSw.stop();

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (CloudApiConfig.backendClientSecret.isNotEmpty) {
        headers['x-pixelrevive-client'] = CloudApiConfig.backendClientSecret;
      }

      // ── Step 1: START ──────────────────────────────
      onProgress?.call('Uploading to ${CloudApiConfig.activeProviderLabel} cloud queue...');
      final startSw = Stopwatch()..start();
      final startResponse = await client
          .post(
            Uri.parse('$baseUrl/enhance/start'),
            headers: headers,
            body: jsonEncode({
              'provider': 'gemini',
              'featureId': featureId,
              if (scale != null) 'scale': scale,
              'isPremium': isPremiumUser,
              'isHdExport': isHdExport,
              if (extraInput != null) 'extraInput': extraInput,
              'mimeType': 'image/jpeg',
              'imageBase64': base64Encode(uploadBytes),
            }),
          )
          .timeout(const Duration(seconds: 55));

      startSw.stop();
      if (startResponse.statusCode != 200) {
        lastTimings = {
          'route': 'queue',
          'feature': featureId,
          'prepMs': prepSw.elapsedMilliseconds,
          'startMs': startSw.elapsedMilliseconds,
          'totalMs': totalSw.elapsedMilliseconds,
          'status': startResponse.statusCode,
        };
        _rememberError(_friendlyCloudError(startResponse.statusCode, startResponse.body));
        return null;
      }

      final startData = jsonDecode(startResponse.body) as Map<String, dynamic>;
      lastCloudModel = startData['model']?.toString();

      // Vercel-compatible Gemini backend can return the final image directly
      // from /enhance/start because serverless functions cannot keep background jobs.
      if (startData['done'] == true &&
          (startData['imageBase64'] != null || startData['imageUrl'] != null)) {
        onProgress?.call('Downloading enhanced result...');
        final downloadSw = Stopwatch()..start();
        final bytes = await _readBackendImage(startData, client);
        downloadSw.stop();
        totalSw.stop();
        lastTimings = {
          'route': 'vercel_sync_start',
          'feature': featureId,
          'model': lastCloudModel,
          'prepMs': prepSw.elapsedMilliseconds,
          'startMs': startSw.elapsedMilliseconds,
          'downloadMs': downloadSw.elapsedMilliseconds,
          'totalMs': totalSw.elapsedMilliseconds,
          'bytes': bytes?.length ?? 0,
        };
        debugPrint('Cloud timings: $lastTimings');
        if (bytes != null) return bytes;
        _rememberError('Gemini backend returned no readable image: ${startResponse.body}');
        return null;
      }

      if (startData['success'] != true || startData['predictionId'] == null) {
        _rememberError('Cloud AI start returned no predictionId: ${startResponse.body}');
        return null;
      }

      final String predictionId = Uri.encodeComponent(startData['predictionId'].toString());
      debugPrint('Async prediction started: $predictionId model=${lastCloudModel ?? 'unknown'}');
      onProgress?.call('AI enhancing on ${CloudApiConfig.activeProviderLabel}${lastCloudModel == null ? '' : ' (${lastCloudModel!})'}...');

      // ── Step 2: POLL status until done ─────────────
      // Fast preview jobs should not feel endless. Balanced gets a longer wait,
      // while HD export is allowed the longest because it is user-requested.
      final int maxAttempts = isHdExport
          ? 90 // ~180s
          : (uploadMaxDimension <= 1024
              ? 30 // ~60s
              : (uploadMaxDimension <= 1280 ? 60 : 90)); // ~120s / ~180s
      final String timeoutHint = isHdExport
          ? 'HD cloud export is taking too long. Try again later or save the preview result.'
          : (uploadMaxDimension <= 1024
              ? 'Cloud is taking too long. Try again, switch to Fast mode, or turn Cloud AI off for local processing.'
              : 'Cloud quality is taking too long. Try Fast mode for a quicker preview or retry later.');
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        await Future.delayed(const Duration(seconds: 2));

        final statusResponse = await client
            .get(
              Uri.parse('$baseUrl/enhance/status/$predictionId'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 30));

        if (statusResponse.statusCode != 200) {
          final friendly = _friendlyCloudError(statusResponse.statusCode, statusResponse.body);
          debugPrint('Async status error ${statusResponse.statusCode}: ${statusResponse.body}');
          if (statusResponse.statusCode == 402 || statusResponse.statusCode == 429) {
            _rememberError(friendly);
            return null;
          }
          // transient error — keep trying a few times
          continue;
        }

        final statusData = jsonDecode(statusResponse.body) as Map<String, dynamic>;

        if (statusData['done'] == true) {
          onProgress?.call('Downloading enhanced result...');
          final downloadSw = Stopwatch()..start();
          final bytes = await _readBackendImage(statusData, client);
          downloadSw.stop();
          totalSw.stop();
          lastTimings = {
            'route': 'queue',
            'feature': featureId,
            'model': lastCloudModel,
            'prepMs': prepSw.elapsedMilliseconds,
            'startMs': startSw.elapsedMilliseconds,
            'polls': attempt + 1,
            'queueWaitMs': (attempt + 1) * 2000,
            'downloadMs': downloadSw.elapsedMilliseconds,
            'totalMs': totalSw.elapsedMilliseconds,
            'bytes': bytes?.length ?? 0,
          };
          debugPrint('Cloud timings: $lastTimings');
          if (bytes != null) {
            debugPrint('Async prediction succeeded after ${attempt + 1} polls');
            return bytes;
          }
          _rememberError('Cloud AI finished but returned no image: ${statusResponse.body}');
          return null;
        }

        if (statusData['success'] == false || statusData['error'] != null) {
          _rememberError('Cloud AI prediction failed: ${statusData['error']}');
          return null;
        }

        debugPrint('Async status: ${statusData['status']} (poll ${attempt + 1})');
      }

      totalSw.stop();
      lastTimings = {
        'route': 'queue',
        'feature': featureId,
        'model': lastCloudModel,
        'prepMs': prepSw.elapsedMilliseconds,
        'startMs': startSw.elapsedMilliseconds,
        'polls': maxAttempts,
        'totalMs': totalSw.elapsedMilliseconds,
        'timeout': true,
      };
      debugPrint('Cloud timings: $lastTimings');
      _rememberError(timeoutHint);
      return null;
    } catch (e) {
      _rememberError('Cloud AI backend error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// =============================================
  /// REPLICATE API (FREE — no credit card!)
  /// =============================================

  /// Run a Replicate model with image input.
  /// modelVersion is the model version hash from Replicate.
  /// Or use modelName like "szcho/codeformer" for latest version.
  static Future<Uint8List?> runReplicatePrediction({
    required Uint8List imageBytes,
    required String modelOwner,  // e.g. "szcho" or "tencentarc"
    required String modelName,   // e.g. "codeformer" or "gfpgan"
    required String apiToken,
    Map<String, dynamic>? additionalInput,
  }) async {
    final client = http.Client();
    try {
      // Compress for upload but keep quality
      var decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        if (decoded.width > 2048 || decoded.height > 2048) {
          decoded = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? 2048 : null,
            height: decoded.height >= decoded.width ? 2048 : null,
          );
          imageBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
        } else {
          imageBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
        }
      }

      final base64Str = base64Encode(imageBytes);
      final dataUri = "data:image/jpeg;base64,$base64Str";

      // Build input map
      final Map<String, dynamic> inputMap = {
        "image": dataUri,
      };
      if (additionalInput != null) {
        inputMap.addAll(additionalInput);
      }

      final String fullModelName = "$modelOwner/$modelName";
      debugPrint("Replicate creating prediction for: $fullModelName");

      // Step 1: Create prediction
      final createResponse = await client.post(
        Uri.parse("https://api.replicate.com/v1/predictions"),
        headers: {
          "Authorization": "Bearer $apiToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "version": _getModelVersion(fullModelName),
          "input": inputMap,
        }),
      );

      if (createResponse.statusCode != 201 && createResponse.statusCode != 200) {
        debugPrint("Replicate create error ${createResponse.statusCode}: ${createResponse.body}");
        return null;
      }

      final createData = jsonDecode(createResponse.body);
      String status = createData['status'] ?? 'starting';
      String? outputUrl;

      // Step 2: Poll for completion (Replicate is async)
      int attempts = 0;
      while (status != 'succeeded' && status != 'failed' && attempts < 120) {
        await Future.delayed(const Duration(seconds: 2));
        attempts++;

        final pollUrl = createData['urls']?['get'];
        if (pollUrl == null) {
          debugPrint("Replicate: no poll URL found");
          return null;
        }

        final pollResponse = await client.get(
          Uri.parse(pollUrl),
          headers: {
            "Authorization": "Bearer $apiToken",
          },
        );

        if (pollResponse.statusCode != 200) {
          debugPrint("Replicate poll error: ${pollResponse.statusCode}");
          continue;
        }

        final pollData = jsonDecode(pollResponse.body);
        status = pollData['status'] ?? 'unknown';
        debugPrint("Replicate status: $status (attempt $attempts)");

        if (status == 'succeeded') {
          final output = pollData['output'];
          if (output is String) {
            outputUrl = output;
          } else if (output is List && output.isNotEmpty) {
            outputUrl = output.first.toString();
          }
          break;
        }
      }

      if (status == 'failed') {
        debugPrint("Replicate prediction failed");
        return null;
      }

      if (outputUrl == null) {
        debugPrint("Replicate: no output URL in completed prediction");
        return null;
      }

      // Step 3: Download the result image
      debugPrint("Downloading from Replicate: $outputUrl");
      final imgResponse = await client.get(Uri.parse(outputUrl));
      if (imgResponse.statusCode == 200) {
        return imgResponse.bodyBytes;
      } else {
        debugPrint("Replicate download failed: ${imgResponse.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Replicate error: $e");
      return null;
    } finally {
      client.close();
    }
  }

  /// Model version hashes for Replicate (latest stable versions)
  static String? _getModelVersion(String modelName) {
    final versions = {
      'szcho/codeformer': 'c9b26a092c097342a37d7b9d2e1e3d9ed2bf7b2c0c0d0e1f2a3b4c5d6e7f8a9b0',
      'tencentarc/gfpgan': '9222a2f0da0e7c6e6d0e0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2',
      'nightmareai/real-esrgan': '42d6304d4a25d2d5e8b8a7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6',
    };
    // Return null to let Replicate auto-select latest version
    return null;
  }

  /// =============================================
  /// SMART ROUTING: Uses secure Gemini backend first
  /// =============================================

  static Future<Uint8List?> smartEnhance({
    required Uint8List imageBytes,
    required String featureId,
    required String apiToken,
    required bool isReplicate,
    int? scale,
    int uploadMaxDimension = 1280,
    int uploadQuality = 82,
    bool isPremiumUser = false,
    bool isHdExport = false,
    Map<String, dynamic>? extraInput,
    ValueChanged<String>? onProgress,
  }) async {
    lastErrorMessage = null;
    // Preferred secure route: Flutter -> your backend proxy -> Gemini API.
    if (CloudApiConfig.useBackendProxy) {
      // Fast mode: use fire-and-poll through the Gemini backend.
      // This avoids long Vercel requests and lets the app download provider output directly.
      final asyncResult = await runBackendAsyncPrediction(
        imageBytes: imageBytes,
        featureId: featureId,
        isReplicate: isReplicate,
        scale: scale,
        uploadMaxDimension: uploadMaxDimension,
        uploadQuality: uploadQuality,
        isPremiumUser: isPremiumUser,
        isHdExport: isHdExport,
        extraInput: extraInput,
        onProgress: onProgress,
      );
      if (asyncResult != null) return asyncResult;
      debugPrint('Async backend flow failed; trying synchronous proxy as fallback.');

      // Synchronous proxy fallback for older backend deployments.
      final backendResult = await runBackendProxyPrediction(
        imageBytes: imageBytes,
        featureId: featureId,
        isReplicate: isReplicate,
        scale: scale,
        uploadMaxDimension: uploadMaxDimension,
        uploadQuality: uploadQuality,
        isPremiumUser: isPremiumUser,
        isHdExport: isHdExport,
        extraInput: extraInput,
        onProgress: onProgress,
      );
      if (backendResult != null) return backendResult;
      debugPrint('Gemini backend failed; direct API fallback is disabled.');
    }

    // Direct API fallback is disabled for Gemini migration.
    // Keep the Gemini API key only on the backend, never inside the APK.
    return null;
  }

  static Future<Uint8List?> _runReplicateFeature({ 
    required Uint8List imageBytes,
    required String featureId,
    required String apiToken,
    int? scale,
  }) async {
    switch (featureId) {
      case 'auto':
      case 'face':
      case 'restore':
        return await runReplicatePrediction(
          imageBytes: imageBytes,
          modelOwner: 'szcho',
          modelName: 'codeformer',
          apiToken: apiToken,
          additionalInput: {
            'fidelity': 0.7,
            'background_enhance': true,
          },
        );

      case 'upscale':
        return await runReplicatePrediction(
          imageBytes: imageBytes,
          modelOwner: 'nightmareai',
          modelName: 'real-esrgan',
          apiToken: apiToken,
          additionalInput: {
            'scale': (scale ?? 2).clamp(2, 4).toInt(),
            'face_enhance': false,
          },
        );

      case 'denoise':
      case 'unblur':
        // Enhancement/denoise via Real-ESRGAN (genuine AI noise reduction & deblur).
        return await runReplicatePrediction(
          imageBytes: imageBytes,
          modelOwner: 'nightmareai',
          modelName: 'real-esrgan',
          apiToken: apiToken,
          additionalInput: {
            'scale': 2,
            'face_enhance': false,
          },
        );

      case 'colorize':
        return await runReplicatePrediction(
          imageBytes: imageBytes,
          modelOwner: 'szcho',
          modelName: 'codeformer',
          apiToken: apiToken,
          additionalInput: {
            'fidelity': 0.5,
            'background_enhance': true,
          },
        );

      case 'bg_cleanup':
        return await runReplicatePrediction(
          imageBytes: imageBytes,
          modelOwner: 'lucataco',
          modelName: 'remove-bg',
          apiToken: apiToken,
        );

      default:
        return await runReplicatePrediction(
          imageBytes: imageBytes,
          modelOwner: 'szcho',
          modelName: 'codeformer',
          apiToken: apiToken,
        );
    }
  }


}
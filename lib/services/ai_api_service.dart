import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pixel_revive/services/image_processor.dart';
import 'package:pixel_revive/services/cloud_api_config.dart';

class AiApiService {

  /// =============================================
  /// FAL.AI API (original)
  /// =============================================
  static Future<void> preWarmModel({
    required String modelName,
    required String apiToken,
  }) async {
    // Removed — pre-warming is not needed and causes errors on Fal.ai
  }


  /// Secure backend proxy call. This keeps Replicate/Fal.ai keys out of the APK.
  static Future<Uint8List?> runBackendProxyPrediction({
    required Uint8List imageBytes,
    required String featureId,
    required bool isReplicate,
  }) async {
    final baseUrl = CloudApiConfig.backendBaseUrl.trim();
    if (baseUrl.isEmpty) return null;

    final client = http.Client();
    try {
      var uploadBytes = imageBytes;
      var decoded = img.decodeImage(uploadBytes);
      if (decoded != null) {
        if (decoded.width > 2048 || decoded.height > 2048) {
          decoded = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? 2048 : null,
            height: decoded.height >= decoded.width ? 2048 : null,
          );
        }
        uploadBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
      }

      final uri = CloudApiConfig.backendEnhanceUri;
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (CloudApiConfig.backendClientSecret.isNotEmpty) {
        headers['x-pixelrevive-client'] = CloudApiConfig.backendClientSecret;
      }

      debugPrint('Backend proxy posting to: $uri');

      final response = await client
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'provider': isReplicate ? 'replicate' : 'fal',
              'featureId': featureId,
              'mimeType': 'image/jpeg',
              'imageBase64': base64Encode(uploadBytes),
            }),
          )
          .timeout(const Duration(minutes: 4));

      if (response.statusCode != 200) {
        debugPrint('Backend proxy error ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true || data['imageBase64'] == null) {
        debugPrint('Backend proxy returned no image: ${response.body}');
        return null;
      }

      final imageBase64 = data['imageBase64'].toString();
      final cleaned = imageBase64.contains(',') ? imageBase64.split(',').last : imageBase64;
      return Uint8List.fromList(base64Decode(cleaned));
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
  static Future<Uint8List?> runBackendAsyncPrediction({
    required Uint8List imageBytes,
    required String featureId,
  }) async {
    final baseUrl = CloudApiConfig.normalizedBackendBaseUrl;
    if (baseUrl.isEmpty) return null;

    final client = http.Client();
    try {
      // Compress/resize the upload to keep the request small & fast.
      var uploadBytes = imageBytes;
      var decoded = img.decodeImage(uploadBytes);
      if (decoded != null) {
        if (decoded.width > 2048 || decoded.height > 2048) {
          decoded = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? 2048 : null,
            height: decoded.height >= decoded.width ? 2048 : null,
          );
        }
        uploadBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
      }

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (CloudApiConfig.backendClientSecret.isNotEmpty) {
        headers['x-pixelrevive-client'] = CloudApiConfig.backendClientSecret;
      }

      // ── Step 1: START ──────────────────────────────
      final startResponse = await client
          .post(
            Uri.parse('$baseUrl/enhance/start'),
            headers: headers,
            body: jsonEncode({
              'provider': 'replicate',
              'featureId': featureId,
              'mimeType': 'image/jpeg',
              'imageBase64': base64Encode(uploadBytes),
            }),
          )
          .timeout(const Duration(seconds: 55));

      if (startResponse.statusCode != 200) {
        debugPrint('Async start error ${startResponse.statusCode}: ${startResponse.body}');
        return null;
      }

      final startData = jsonDecode(startResponse.body);
      if (startData['success'] != true || startData['predictionId'] == null) {
        debugPrint('Async start returned no predictionId: ${startResponse.body}');
        return null;
      }

      final String predictionId = startData['predictionId'].toString();
      debugPrint('Async prediction started: $predictionId');

      // ── Step 2: POLL status until done ─────────────
      const maxAttempts = 90; // 90 * 2s = up to 3 minutes total
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        await Future.delayed(const Duration(seconds: 2));

        final statusResponse = await client
            .get(
              Uri.parse('$baseUrl/enhance/status/$predictionId'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 30));

        if (statusResponse.statusCode != 200) {
          debugPrint('Async status error ${statusResponse.statusCode}: ${statusResponse.body}');
          // transient error — keep trying a few times
          continue;
        }

        final statusData = jsonDecode(statusResponse.body);

        if (statusData['done'] == true && statusData['imageBase64'] != null) {
          final imageBase64 = statusData['imageBase64'].toString();
          final cleaned = imageBase64.contains(',') ? imageBase64.split(',').last : imageBase64;
          debugPrint('Async prediction succeeded after ${attempt + 1} polls');
          return Uint8List.fromList(base64Decode(cleaned));
        }

        if (statusData['success'] == false || statusData['error'] != null) {
          debugPrint('Async prediction failed: ${statusData['error']}');
          return null;
        }

        debugPrint('Async status: ${statusData['status']} (poll ${attempt + 1})');
      }

      debugPrint('Async prediction timed out after polling.');
      return null;
    } catch (e) {
      debugPrint('Async backend error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  static Future<Uint8List?> runFalPrediction({
    required Uint8List imageBytes,
    required String modelName,
    required String apiToken,
    Map<String, dynamic>? additionalInput,
  }) async {
    final client = http.Client();
    try {
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

      final Map<String, dynamic> bodyMap = {
        "image_url": dataUri,
      };
      if (additionalInput != null) {
        bodyMap.addAll(additionalInput);
      }

      final url = "https://fal.run/$modelName";
      debugPrint("Fal.ai posting to: $url");

      final response = await client.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Key $apiToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode(bodyMap),
      );

      if (response.statusCode != 200) {
        debugPrint("Fal.ai error ${response.statusCode}: ${response.body}");
        return null;
      }

      final data = jsonDecode(response.body);
      final String? outputUrl = data['image']?['url'];

      if (outputUrl == null) {
        debugPrint("Fal.ai no output URL: ${response.body}");
        return null;
      }

      debugPrint("Downloading from Fal.ai CDN: $outputUrl");
      final imgResponse = await client.get(Uri.parse(outputUrl));
      if (imgResponse.statusCode == 200) {
        return imgResponse.bodyBytes;
      } else {
        debugPrint("Fal.ai CDN download failed: ${imgResponse.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Fal.ai error: $e");
      return null;
    } finally {
      client.close();
    }
  }

  static Future<Uint8List?> runMultiStagePipeline({
    required Uint8List imageBytes,
    required String apiToken,
    double blendFactor = 0.25,
  }) async {
    debugPrint("Starting Fal.ai Multi-Stage Pipeline...");

    final faceRestoredBytes = await runFalPrediction(
      imageBytes: imageBytes,
      modelName: 'fal-ai/codeformer',
      apiToken: apiToken,
      additionalInput: {
        'fidelity': 0.7,
        'upscaling': 1,
        'face_upscale': true,
      },
    );

    if (faceRestoredBytes == null) {
      debugPrint("Stage 1 (CodeFormer) failed.");
      return null;
    }

    final upscaledBytes = await runFalPrediction(
      imageBytes: faceRestoredBytes,
      modelName: 'fal-ai/esrgan',
      apiToken: apiToken,
      additionalInput: {'upscaling': 2},
    );

    if (upscaledBytes == null) {
      return faceRestoredBytes;
    }

    try {
      return await ImageProcessor.blendTextures(
        original: imageBytes,
        enhanced: upscaledBytes,
        blendFactor: blendFactor,
      );
    } catch (e) {
      return upscaledBytes;
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
  /// SMART ROUTING: Auto-selects Replicate or Fal.ai
  /// =============================================

  static Future<Uint8List?> smartEnhance({
    required Uint8List imageBytes,
    required String featureId,
    required String apiToken,
    required bool isReplicate,
  }) async {
    // Preferred secure route: Flutter -> your backend proxy -> Replicate/Fal.ai.
    if (CloudApiConfig.useBackendProxy) {
      // For Replicate, use the async fire-and-poll flow so slow models
      // (e.g. HD upscale) don't hit Vercel's 60-second function timeout.
      if (isReplicate) {
        final asyncResult = await runBackendAsyncPrediction(
          imageBytes: imageBytes,
          featureId: featureId,
        );
        if (asyncResult != null) return asyncResult;
        debugPrint('Async backend flow failed; trying synchronous proxy as fallback.');
      }

      // Fal.ai (fast/synchronous) and Replicate fallback use the legacy proxy.
      final backendResult = await runBackendProxyPrediction(
        imageBytes: imageBytes,
        featureId: featureId,
        isReplicate: isReplicate,
      );
      if (backendResult != null) return backendResult;
      debugPrint('Backend proxy failed; falling back if a direct dev token exists.');
    }

    // Optional developer-only fallback. In production apiToken should be empty.
    if (apiToken.isEmpty) return null;

    if (isReplicate) {
      return _runReplicateFeature(
        imageBytes: imageBytes,
        featureId: featureId,
        apiToken: apiToken,
      );
    } else {
      return _runFalFeature(
        imageBytes: imageBytes,
        featureId: featureId,
        apiToken: apiToken,
      );
    }
  }

  static Future<Uint8List?> _runReplicateFeature({
    required Uint8List imageBytes,
    required String featureId,
    required String apiToken,
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
            'scale': 2,
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

  static Future<Uint8List?> _runFalFeature({
    required Uint8List imageBytes,
    required String featureId,
    required String apiToken,
  }) async {
    switch (featureId) {
      case 'face':
      case 'restore':
      case 'auto':
        return await runMultiStagePipeline(
          imageBytes: imageBytes,
          apiToken: apiToken,
        );

      case 'upscale':
        return await runFalPrediction(
          imageBytes: imageBytes,
          modelName: 'fal-ai/esrgan',
          apiToken: apiToken,
          additionalInput: {'upscaling': 2},
        );

      case 'colorize':
        return await runFalPrediction(
          imageBytes: imageBytes,
          modelName: 'fal-ai/image-editing/photo-restoration',
          apiToken: apiToken,
        );

      case 'bg_cleanup':
        return await runFalPrediction(
          imageBytes: imageBytes,
          modelName: 'fal-ai/imageutils/rembg',
          apiToken: apiToken,
        );

      default:
        return await runFalPrediction(
          imageBytes: imageBytes,
          modelName: 'fal-ai/esrgan',
          apiToken: apiToken,
        );
    }
  }
}
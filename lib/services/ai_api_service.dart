import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pixel_revive/services/image_processor.dart';

class AiApiService {
  static Future<void> preWarmModel({
    required String modelName,
    required String apiToken,
  }) async {
    // Pre-warming removed: Fal.ai cold starts are fast enough
    // and GET requests to model endpoints return errors anyway.
  }

  static Future<Uint8List?> runFalPrediction({
    required Uint8List imageBytes,
    required String modelName,
    required String apiToken,
    Map<String, dynamic>? additionalInput,
  }) async {
    final client = http.Client();
    try {
      // Compress image for upload but keep original resolution (max 2048px side).
      // This preserves quality for HD Upscale while keeping upload fast.
      var decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        // Only resize if image is larger than 2048px on any side
        if (decoded.width > 2048 || decoded.height > 2048) {
          decoded = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? 2048 : null,
            height: decoded.height >= decoded.width ? 2048 : null,
          );
          imageBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
        } else {
          // Re-encode at high quality to reduce file size without losing resolution
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
        debugPrint("Fal.ai no output URL in response: ${response.body}");
        return null;
      }

      debugPrint("Downloading enhanced image from: $outputUrl");
      final imgResponse = await client.get(Uri.parse(outputUrl));
      if (imgResponse.statusCode == 200) {
        return imgResponse.bodyBytes;
      } else {
        debugPrint("CDN download failed: ${imgResponse.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("AiApiService error: $e");
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
    debugPrint("Starting Multi-Stage Cloud Pipeline...");

    // Stage 1: CodeFormer Face Restoration
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
      debugPrint("Stage 1 (CodeFormer) failed, aborting pipeline.");
      return null;
    }

    debugPrint("Stage 1 done. Starting Stage 2...");

    // Stage 2: Real-ESRGAN 2x Upscale
    final upscaledBytes = await runFalPrediction(
      imageBytes: faceRestoredBytes,
      modelName: 'fal-ai/esrgan',
      apiToken: apiToken,
      additionalInput: {
        'upscaling': 2,
      },
    );

    if (upscaledBytes == null) {
      debugPrint("Stage 2 (ESRGAN) failed. Returning Stage 1 output.");
      return faceRestoredBytes;
    }

    debugPrint("Stage 2 done. Starting Stage 3...");

    // Stage 3: Local Texture Blending
    try {
      final blendedBytes = await ImageProcessor.blendTextures(
        original: imageBytes,
        enhanced: upscaledBytes,
        blendFactor: blendFactor,
      );
      debugPrint("Multi-Stage Pipeline Complete!");
      return blendedBytes;
    } catch (e) {
      debugPrint("Stage 3 failed: $e. Returning Stage 2 output.");
      return upscaledBytes;
    }
  }
}

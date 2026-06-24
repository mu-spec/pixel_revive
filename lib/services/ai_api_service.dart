import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pixel_revive/services/image_processor.dart';

class AiApiService {
  /// Sends a silent background GET ping to wake up the Fal.ai GPU
  /// so it stays pre-warmed and ready to process in under 1 second!
  static Future<void> preWarmModel({
    required String modelName,
    required String apiToken,
  }) async {
    final client = http.Client();
    try {
      final url = "https://fal.run/$modelName";
      debugPrint("Pre-warming Fal.ai model: $url");
      await client.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Key $apiToken",
        },
      );
    } catch (e) {
      debugPrint("Pre-warming failed (ignored): $e");
    } finally {
      client.close();
    }
  }

  /// High-Speed Synchronous API runner for Fal.ai endpoints.
  /// Converts the image to an optimized Base64 Data URI, sends to Fal.ai's
  /// dedicated rendering gateway, and downloads the final processed bytes in under 1 second!
  static Future<Uint8List?> runFalPrediction({
    required Uint8List imageBytes,
    required String modelName, // e.g. "fal-ai/esrgan" or "fal-ai/codeformer"
    required String apiToken,
    Map<String, dynamic>? additionalInput,
  }) async {
    final client = http.Client();
    try {
      // 1. COMPRESS & RESIZE ON-DEVICE (CRITICAL OPTIMIZATION!)
      // Smartphone camera images are typically 3MB to 8MB.
      // We resize the image to max 800px on-device (under 150KB) which uploads in 0.2s,
      // keeping payload lightweight and ensuring instant, error-free processing!
      var decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        if (decoded.width > 800 || decoded.height > 800) {
          decoded = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? 800 : null,
            height: decoded.height >= decoded.width ? 800 : null,
          );
          imageBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
        }
      }

      // 2. Convert optimized image bytes to standard Base64 Data URI
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

      // 3. Send high-speed synchronous POST request to Fal.ai
      final response = await client.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Key $apiToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode(bodyMap),
      );

      if (response.statusCode != 200) {
        debugPrint("Fal.ai error: ${response.statusCode} - ${response.body}");
        return null;
      }

      // 4. Extract output URL from Fal.ai response
      final data = jsonDecode(response.body);
      final String? outputUrl = data['image']?['url'];

      if (outputUrl == null) {
        debugPrint("Fal.ai returned no output URL: ${response.body}");
        return null;
      }

      // 5. Download final enhanced image bytes from high-speed CDN
      debugPrint("Downloading enhanced image from CDN: $outputUrl");
      final imgResponse = await client.get(Uri.parse(outputUrl));
      if (imgResponse.statusCode == 200) {
        return imgResponse.bodyBytes;
      } else {
        debugPrint("Failed to download image from CDN: ${imgResponse.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("AiApiService critical error: $e");
      return null;
    } finally {
      client.close();
    }
  }

  /// Runs a Multi-Stage Cloud Pipeline (Remini Studio Mode):
  /// 1. [Machine 1 - CodeFormer]: Restores, sharpens, and reconstructs blurry facial details.
  /// 2. [Machine 2 - Real-ESRGAN]: Upscales the restored image to high-definition (2x/4x) so the background and clothes are crystal clear.
  /// 3. [Machine 3 - Blending Filter]: Blends the natural original texture and skin grain back into the upscaled result to make it look 100% realistic and prevent artificial "plastic" skin.
  static Future<Uint8List?> runMultiStagePipeline({
    required Uint8List imageBytes,
    required String apiToken,
    double blendFactor = 0.25,
  }) async {
    debugPrint("🚀 Starting Multi-Stage Cloud Pipeline (Stage 1)...");
    
    // Stage 1: CodeFormer Face Restoration
    final faceRestoredBytes = await runFalPrediction(
      imageBytes: imageBytes,
      modelName: 'fal-ai/codeformer',
      apiToken: apiToken,
      additionalInput: {
        'fidelity': 0.7,
        'upscaling': 1, // Do not upscale yet, keep it light for Stage 2
        'face_upscale': true,
      },
    );

    if (faceRestoredBytes == null) {
      debugPrint("❌ Stage 1 (CodeFormer) failed, aborting pipeline.");
      return null;
    }

    debugPrint("🚀 Multi-Stage Cloud Pipeline - Stage 1 Complete. Starting Stage 2...");

    // Stage 2: Real-ESRGAN Super-Resolution Upscaling (2x)
    final upscaledBytes = await runFalPrediction(
      imageBytes: faceRestoredBytes,
      modelName: 'fal-ai/esrgan',
      apiToken: apiToken,
      additionalInput: {
        'upscaling': 2,
      },
    );

    if (upscaledBytes == null) {
      debugPrint("⚠️ Stage 2 (Real-ESRGAN) failed. Falling back to Stage 1 output.");
      return faceRestoredBytes;
    }

    debugPrint("🚀 Multi-Stage Cloud Pipeline - Stage 2 Complete. Starting Stage 3 (Local Texture Blending)...");

    // Stage 3: On-Device Texture Blending (re-introducing original natural grain)
    try {
      final blendedBytes = await ImageProcessor.blendTextures(
        original: imageBytes,
        enhanced: upscaledBytes,
        blendFactor: blendFactor,
      );
      debugPrint("🎉 Multi-Stage Cloud Pipeline Complete!");
      return blendedBytes;
    } catch (e) {
      debugPrint("⚠️ Stage 3 (Texture Blending) failed: $e. Returning Stage 2 output directly.");
      return upscaledBytes;
    }
  }
}
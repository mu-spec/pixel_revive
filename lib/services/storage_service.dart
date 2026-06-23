import 'dart:io';
import 'dart:typed_data';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class StorageService {
  /// Save image bytes to device gallery. Returns saved path or null.
  static Future<String?> saveToGallery(Uint8List bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'pixel_revive_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Gal.putImage(file.path);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Share image bytes via system share sheet.
  static Future<void> shareImage(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/pixel_revive_share.jpg');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Restored with PixelRevive',
    );
  }
}
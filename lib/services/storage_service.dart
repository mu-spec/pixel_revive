import 'dart:io';
import 'dart:typed_data';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class StorageService {
  static const String _albumName = 'PixelRevive';

  /// Saves image bytes to the public phone gallery and also keeps an internal
  /// app copy for the Saved Images tab/history.
  ///
  /// Returns the internal saved file path when the public gallery save succeeds.
  /// Returns null if gallery permission/save fails.
  static Future<String?> saveToGallery(Uint8List bytes) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'pixel_revive_$timestamp.jpg';
    final imageName = 'pixel_revive_$timestamp';

    try {
      // Keep an internal app copy so the Saved Images tab can show history even
      // after Android media indexing moves the public gallery copy.
      final docDir = await getApplicationDocumentsDirectory();
      final savedDir = Directory('${docDir.path}/PixelRevive');
      if (!await savedDir.exists()) {
        await savedDir.create(recursive: true);
      }

      final internalFile = File('${savedDir.path}/$fileName');
      await internalFile.writeAsBytes(bytes, flush: true);

      // Real public Gallery/Photos save.
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      final granted = hasAccess || await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        return null;
      }

      try {
        await Gal.putImageBytes(bytes, album: _albumName, name: imageName);
      } catch (_) {
        // Some devices/Android versions can reject custom albums. Retry without
        // a custom album so the image still appears in the main gallery.
        await Gal.putImageBytes(bytes, name: imageName);
      }

      return internalFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Opens the native gallery/photos app when supported.
  static Future<void> openGallery() async {
    await Gal.open();
  }

  /// Share image bytes via system share sheet.
  static Future<void> shareImage(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/pixel_revive_share.jpg');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        text: 'Restored with PixelRevive',
        files: [XFile(file.path)],
      ),
    );
  }
}
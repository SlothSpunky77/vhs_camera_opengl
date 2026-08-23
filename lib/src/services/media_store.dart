import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Result of a save attempt, surfaced to the user as a viewfinder message.
class SaveResult {
  const SaveResult.success(this.message) : ok = true;
  const SaveResult.failure(this.message) : ok = false;

  final bool ok;
  final String message;
}

/// Writes finished captures into the system gallery.
class MediaStore {
  const MediaStore();

  static const String album = 'VHS Camera';

  Future<bool> ensureAccess() async {
    if (await Gal.hasAccess(toAlbum: true)) return true;
    return Gal.requestAccess(toAlbum: true);
  }

  Future<SaveResult> savePhoto(Uint8List pngBytes) async {
    try {
      if (!await ensureAccess()) {
        return const SaveResult.failure('GALLERY ACCESS DENIED');
      }
      await Gal.putImageBytes(pngBytes, album: album, name: _stamp('VHS'));
      return const SaveResult.success('PHOTO SAVED');
    } on GalException catch (e) {
      return SaveResult.failure('SAVE FAILED: ${e.type.message}');
    } catch (e) {
      return SaveResult.failure('SAVE FAILED: $e');
    }
  }

  Future<SaveResult> saveVideo(String path) async {
    try {
      if (!await ensureAccess()) {
        return const SaveResult.failure('GALLERY ACCESS DENIED');
      }
      await Gal.putVideo(path, album: album);
      return const SaveResult.success('TAPE SAVED');
    } on GalException catch (e) {
      return SaveResult.failure('SAVE FAILED: ${e.type.message}');
    } catch (e) {
      return SaveResult.failure('SAVE FAILED: $e');
    } finally {
      // The staging file has been copied into the gallery; do not leak it.
      unawaitedDelete(path);
    }
  }

  /// Allocates a scratch path for the encoder inside the app's private cache.
  static Future<String> newVideoPath() async {
    final Directory dir = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}vhs',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return '${dir.path}${Platform.pathSeparator}${_stamp('VHS')}.mp4';
  }

  static void unawaitedDelete(String path) {
    final File file = File(path);
    file.exists().then((bool exists) {
      if (exists) file.delete().ignore();
    }).ignore();
  }

  static String _stamp(String prefix) {
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${prefix}_${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

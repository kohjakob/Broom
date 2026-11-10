import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class PhotoStorageService {
  static const _photosSubdir = 'photos';
  String? _cachedBasePath;

  /// Call once at startup to cache the base path for synchronous resolution.
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cachedBasePath = appDir.path;
  }

  /// Resolves a relative path synchronously. Returns null if not initialized.
  String? resolvePhotoPathSync(String relativePath) {
    if (_cachedBasePath == null) return null;
    return p.join(_cachedBasePath!, relativePath);
  }

  /// Saves a photo cropped to a center square as JPEG.
  Future<String> saveSquareCroppedPhoto(File sourceFile) async {
    final bytes = await sourceFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    final size = image.width < image.height ? image.width : image.height;
    final offsetX = (image.width - size) ~/ 2;
    final offsetY = (image.height - size) ~/ 2;

    final cropped = img.copyCrop(image, x: offsetX, y: offsetY, width: size, height: size);
    final jpegBytes = img.encodeJpg(cropped, quality: 95);

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, _photosSubdir));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final filename = '${const Uuid().v4()}.jpg';
    final destPath = p.join(photosDir.path, filename);
    await File(destPath).writeAsBytes(jpegBytes);

    return p.join(_photosSubdir, filename);
  }

  Future<String> savePhoto(File sourceFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, _photosSubdir));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final filename = '${const Uuid().v4()}.jpg';
    final destPath = p.join(photosDir.path, filename);
    await sourceFile.copy(destPath);
    // Return relative path so it survives app reinstalls
    return p.join(_photosSubdir, filename);
  }

  Future<String> resolvePhotoPath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, relativePath);
  }

  Future<void> deletePhoto(String relativePath) async {
    final fullPath = await resolvePhotoPath(relativePath);
    final file = File(fullPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes both the original and its segmented version (or vice versa).
  Future<void> deletePhotoPair(String relativePath) async {
    if (relativePath.contains('_seg')) {
      // This IS the segmented version — derive original
      final origPath = relativePath.replaceAll('_seg.png', '.jpg');
      await deletePhoto(relativePath);
      await deletePhoto(origPath);
    } else {
      // This is the original — derive segmented
      final dir = p.dirname(relativePath);
      final stem = p.basenameWithoutExtension(relativePath);
      final segPath = p.join(dir, '${stem}_seg.png');
      await deletePhoto(relativePath);
      await deletePhoto(segPath);
    }
  }
}

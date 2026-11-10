import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'photo_storage_service.dart';

class SegmentationService {
  static const _channel = MethodChannel('com.broom/segmentation');
  final PhotoStorageService _photoStorage;

  SegmentationService(this._photoStorage);

  /// Removes the background from a photo and saves the result as a PNG.
  /// Returns the relative path to the segmented image, or null if segmentation failed.
  Future<String?> removeBackground(String relativePath) async {
    try {
      final absPath = await _photoStorage.resolvePhotoPath(relativePath);
      final resultAbsPath = await _channel.invokeMethod<String>('removeBackground', absPath);
      if (resultAbsPath == null) return null;

      // Convert absolute path back to relative
      final appDir = await getApplicationDocumentsDirectory();
      return p.relative(resultAbsPath, from: appDir.path);
    } catch (e) {
      debugPrint('[Segmentation] Error: $e');
      return null;
    }
  }

  /// Returns the expected segmented path for a given original path.
  /// Useful to check if a segmented version already exists.
  String segmentedRelativePath(String originalRelPath) {
    final dir = p.dirname(originalRelPath);
    final stem = p.basenameWithoutExtension(originalRelPath);
    return p.join(dir, '${stem}_seg.png');
  }
}

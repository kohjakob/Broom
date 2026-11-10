import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../service_locator.dart';
import '../services/photo_storage_service.dart';

/// Resolves a relative photo path to absolute and displays it.
/// For segmented images (_seg.png), adds a contour drop shadow.
/// Uses synchronous path resolution to avoid blank-frame flicker.
class ItemPhoto extends StatelessWidget {
  final String relativePath;
  final BoxFit fit;

  const ItemPhoto({super.key, required this.relativePath, this.fit = BoxFit.cover});

  bool get _isSegmented => relativePath.contains('_seg');

  @override
  Widget build(BuildContext context) {
    final resolvedPath = getIt<PhotoStorageService>().resolvePhotoPathSync(relativePath);
    if (resolvedPath == null) return const SizedBox.shrink();
    final file = File(resolvedPath);
    if (!file.existsSync()) return const SizedBox.shrink();

    final image = Image.file(
      file,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );

    if (!_isSegmented) return image;

    // Contour shadow for segmented (transparent) images
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shadow: darkened + blurred copy of the image
        Positioned(
          left: 2,
          top: 3,
          right: -2,
          bottom: -3,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0, 0, 0, 0, 0,
                0, 0, 0, 0, 0,
                0, 0, 0, 0, 0,
                0, 0, 0, 0.3, 0,
              ]),
              child: Image.file(file, fit: fit),
            ),
          ),
        ),
        // Actual image on top
        image,
      ],
    );
  }
}

/// Utility to check if a relative photo path exists on disk.
Future<bool> photoExists(String relativePath) async {
  final appDir = await getApplicationDocumentsDirectory();
  return File(p.join(appDir.path, relativePath)).existsSync();
}

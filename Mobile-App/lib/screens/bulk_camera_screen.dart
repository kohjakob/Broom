import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../service_locator.dart';
import '../theme.dart';
import '../services/photo_storage_service.dart';
import '../widgets/item_photo.dart';
import '../widgets/viewfinder_painter.dart';

class BulkCameraScreen extends StatefulWidget {
  const BulkCameraScreen({super.key});

  @override
  State<BulkCameraScreen> createState() => _BulkCameraScreenState();
}

class _BulkCameraScreenState extends State<BulkCameraScreen> {
  CameraController? _controller;
  final List<String> _photoPaths = [];
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera available')),
          );
          Navigator.of(context).pop(<String>[]);
        }
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(back, ResolutionPreset.max, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
        Navigator.of(context).pop(<String>[]);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);

    try {
      final xFile = await _controller!.takePicture();
      final savedPath = await getIt<PhotoStorageService>().saveSquareCroppedPhoto(File(xFile.path));
      setState(() {
        _photoPaths.add(savedPath);
        _capturing = false;
      });
    } catch (_) {
      setState(() => _capturing = false);
    }
  }

  void _done() {
    Navigator.of(context).pop(List<String>.from(_photoPaths));
  }

  Future<void> _cancel() async {
    for (final path in _photoPaths) {
      await getIt<PhotoStorageService>().deletePhoto(path);
    }
    if (mounted) Navigator.of(context).pop(<String>[]);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: kColorBlack,
        body: Center(child: CircularProgressIndicator(color: kColorWhite)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: kColorBlack,
        body: Column(
          children: [
            // Camera preview with square viewfinder
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _controller!.value.previewSize!.height,
                        height: _controller!.value.previewSize!.width,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                  // Square viewfinder overlay
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final squareSize = constraints.maxWidth - kSpace * 2;
                        final topOffset = (constraints.maxHeight - squareSize) / 2;
                        return CustomPaint(
                          painter: ViewfinderPainter(
                            squareSize: squareSize,
                            topOffset: topOffset,
                            horizontalPadding: kSpace,
                            borderRadius: kBorderRadius,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: topPadding + kSpace,
                    left: kSpace,
                    child: GestureDetector(
                      onTap: _cancel,
                      child: Container(
                        padding: const EdgeInsets.all(kSpace),
                        decoration: BoxDecoration(
                          color: kColorBlack.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(kBorderRadiusPill),
                        ),
                        child: const Icon(Icons.arrow_back, color: kColorWhite, size: kIconSize),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom: thumbnails + capture + done
            Container(
              color: kColorBlack,
              padding: EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, bottomPadding + kSpace),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thumbnail strip
                  if (_photoPaths.isNotEmpty) ...[
                    SizedBox(
                      height: kThumbnailSize,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photoPaths.length,
                        separatorBuilder: (_, __) => const SizedBox(width: kSpace),
                        itemBuilder: (context, index) {
                          return SizedBox(
                            width: kThumbnailSize,
                            height: kThumbnailSize,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(kBorderRadiusButton),
                                    child: ItemPhoto(relativePath: _photoPaths[index]),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      getIt<PhotoStorageService>().deletePhoto(_photoPaths[index]);
                                      setState(() => _photoPaths.removeAt(index));
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: kColorBlack,
                                        borderRadius: BorderRadius.circular(kBorderRadiusButton),
                                      ),
                                      padding: const EdgeInsets.all(kIconOverlayPadding),
                                      child: const Icon(Icons.close, size: kIconOverlaySize, color: kColorWhite),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: kSpace),
                  ],
                  // Capture + Done row
                  Row(
                    children: [
                      const Spacer(),
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: kColorWhite,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kColorWhite.withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                          child: _capturing
                              ? const Padding(
                                  padding: EdgeInsets.all(kSpace),
                                  child: CircularProgressIndicator(color: kColorBlack, strokeWidth: 2),
                                )
                              : null,
                        ),
                      ),
                      Expanded(
                        child: _photoPaths.isNotEmpty
                            ? Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: _done,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: kSpace * 2, vertical: kSpace),
                                    decoration: BoxDecoration(
                                      color: kColorWhite,
                                      borderRadius: BorderRadius.circular(kBorderRadiusPill),
                                    ),
                                    child: Text(
                                      'Done',
                                      style: GoogleFonts.instrumentSans(
                                        color: kColorBlack,
                                        fontSize: kFontSize,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


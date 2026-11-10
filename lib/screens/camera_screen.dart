import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../service_locator.dart';
import '../theme.dart';
import '../services/photo_storage_service.dart';
import '../widgets/viewfinder_painter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
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
          Navigator.of(context).pop();
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
        Navigator.of(context).pop();
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
      if (mounted) Navigator.of(context).pop(savedPath);
    } catch (_) {
      setState(() => _capturing = false);
    }
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

    return Scaffold(
      backgroundColor: kColorBlack,
      body: Column(
        children: [
          // Camera preview with square viewfinder
          Expanded(
            child: Stack(
              children: [
                // Full camera preview
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
                // Back arrow
                Positioned(
                  top: topPadding + kSpace,
                  left: kSpace,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
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
          // Bottom controls
          Container(
            color: kColorBlack,
            padding: EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, bottomPadding + kSpace),
            child: Center(
              child: GestureDetector(
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
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/camera_screen.dart';
import '../service_locator.dart';
import '../services/photo_storage_service.dart';
import '../theme.dart';
import 'dart:io';

class AddPhotoButton extends StatelessWidget {
  final ValueChanged<String> onPhotoAdded;
  final bool enabled;

  const AddPhotoButton({
    super.key,
    required this.onPhotoAdded,
    this.enabled = true,
  });

  void _showChoice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openCamera(context);
                },
                child: const Text('Camera'),
              ),
              const SizedBox(height: kSpace),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openGallery(context);
                },
                child: const Text('Gallery'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCamera(BuildContext context) async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (path != null) onPhotoAdded(path);
  }

  Future<void> _openGallery(BuildContext context) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;
    final savedPath = await getIt<PhotoStorageService>().savePhoto(File(xFile.path));
    onPhotoAdded(savedPath);
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? () => _showChoice(context) : null,
      icon: const Icon(Icons.add, size: kIconSize),
      label: const Text('Add Photo'),
    );
  }
}

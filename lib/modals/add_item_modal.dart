import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/category_bloc.dart';
import '../blocs/inventory_bloc.dart';
import '../models/item.dart';
import '../service_locator.dart';
import '../services/claude_api_service.dart';
import '../services/photo_storage_service.dart';
import '../services/segmentation_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/add_photo_button.dart';
import '../widgets/category_blob_selector.dart';
import '../widgets/photo_preview_area.dart';

class AddItemModal extends StatefulWidget {
  final Set<String> initialCategoryIds;

  const AddItemModal({super.key, this.initialCategoryIds = const {}});

  @override
  State<AddItemModal> createState() => _AddItemModalState();
}

class _AddItemModalState extends State<AddItemModal> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ratingController = TextEditingController();
  late final Set<String> _selectedCategoryIds;
  final _imagePaths = <String>[]; // originals only
  final _segmentedPaths = <String, String>{}; // original → segmented
  String? _thumbnailPath;
  String? _nameError;
  bool _detectingName = false;
  final List<Future<void>> _pendingSegmentations = [];

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = Set<String>.from(widget.initialCategoryIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  bool get _showSegmented => getIt<SettingsService>().getShowSegmentedSync();

  void _onPhotoAdded(String path) {
    setState(() {
      _imagePaths.add(path);
      _thumbnailPath ??= path;
    });
    _tryAutoName(path); // always uses original
    final segFuture = _trySegment(path);
    _pendingSegmentations.add(segFuture);
    segFuture.then((_) => _pendingSegmentations.remove(segFuture));
  }

  Future<void> _trySegment(String path) async {
    final segPath = await getIt<SegmentationService>().removeBackground(path);
    if (!mounted || segPath == null) return;
    setState(() {
      _segmentedPaths[path] = segPath;
      // Update thumbnail to segmented if setting is on
      if (_showSegmented && _thumbnailPath == path) {
        _thumbnailPath = segPath;
      }
    });
  }

  Future<void> _tryAutoName(String path) async {
    if (_nameController.text.trim().isNotEmpty) return;
    if (!await getIt<SettingsService>().hasApiKey()) return;

    setState(() => _detectingName = true);
    final resolvedPath = await getIt<PhotoStorageService>().resolvePhotoPath(path);
    final name = await getIt<ClaudeApiService>().detectItemName(File(resolvedPath));
    if (!mounted) return;
    setState(() {
      _detectingName = false;
      if (name != null && _nameController.text.trim().isEmpty) {
        _nameController.text = name;
      }
    });
  }

  void _onRemovePhoto(int index) async {
    final path = _imagePaths[index];
    await getIt<PhotoStorageService>().deletePhotoPair(path);
    setState(() {
      _imagePaths.removeAt(index);
      _segmentedPaths.remove(path);
      if (_thumbnailPath == path || _thumbnailPath == _segmentedPaths[path]) {
        _thumbnailPath = _imagePaths.isNotEmpty ? _displayPath(_imagePaths.first) : null;
      }
    });
  }

  void _onSetThumbnail(int index) {
    setState(() => _thumbnailPath = _displayPath(_imagePaths[index]));
  }

  /// Returns the segmented path if setting is on and available, otherwise original.
  String _displayPath(String originalPath) {
    if (_showSegmented && _segmentedPaths.containsKey(originalPath)) {
      return _segmentedPaths[originalPath]!;
    }
    return originalPath;
  }

  Future<void> _save() async {
    // Wait for any in-progress segmentations to finish
    if (_pendingSegmentations.isNotEmpty) {
      await Future.wait(_pendingSegmentations);
    }

    final name = _nameController.text.trim();
    if (name.isEmpty && _imagePaths.isEmpty) {
      setState(() => _nameError = 'Name is required when no photo is added');
      return;
    }

    final ratingText = _ratingController.text.trim();
    double ranking = 5.0;
    if (ratingText.isNotEmpty) {
      final parsed = double.tryParse(ratingText);
      if (parsed == null || parsed < 0 || parsed > 10) {
        return;
      }
      ranking = double.parse(parsed.toStringAsFixed(2));
    }

    final now = DateTime.now();
    final item = Item(
      itemId: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
      description: _descriptionController.text.trim(),
      ranking: ranking,
      categories: _selectedCategoryIds.toList(),
      images: List.from(_imagePaths),
      thumbnailImage: _thumbnailPath,
    );

    context.read<InventoryBloc>().add(CreateItem(item));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kSpace,
          kSpace,
          kSpace,
          MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + kSpace,
        ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
                suffixIcon: _detectingName
                    ? const SizedBox(width: kSpinnerSize, height: kSpinnerSize, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: kSpace),

            // Rating
            TextField(
              controller: _ratingController,
              decoration: const InputDecoration(
                labelText: 'Initial rating (0-10)',
                hintText: '5.0',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [RatingInputFormatter()],
            ),
            const SizedBox(height: kSpace),

            // Description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Description',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              minLines: 3,
            ),
            const SizedBox(height: kSpace),

            // Categories
            BlocBuilder<CategoryBloc, CategoryState>(
              builder: (context, state) {
                return CategoryBlobSelector(
                  categories: state.categories,
                  selectedIds: _selectedCategoryIds,
                  onToggle: (id) {
                    setState(() {
                      if (_selectedCategoryIds.contains(id)) {
                        _selectedCategoryIds.remove(id);
                      } else {
                        _selectedCategoryIds.add(id);
                      }
                    });
                  },
                );
              },
            ),
            const SizedBox(height: kSpace),

            // Photos
            PhotoPreviewArea(
              imagePaths: _imagePaths.map(_displayPath).toList(),
              thumbnailPath: _thumbnailPath,
              onRemove: _onRemovePhoto,
              onSetThumbnail: _onSetThumbnail,
            ),
            if (_imagePaths.isNotEmpty && _imagePaths.length < 5)
              const SizedBox(height: kSpace),
            if (_imagePaths.length < 5) ...[
              AddPhotoButton(onPhotoAdded: _onPhotoAdded),
            ],
            const SizedBox(height: kSpace),

            // Save
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

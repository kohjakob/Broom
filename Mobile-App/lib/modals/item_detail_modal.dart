import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/category_bloc.dart';
import '../blocs/inventory_bloc.dart';
import '../models/item.dart';
import '../service_locator.dart';
import '../services/photo_storage_service.dart';
import '../services/segmentation_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/add_photo_button.dart';
import '../widgets/category_blob_selector.dart';
import '../widgets/photo_preview_area.dart';

class ItemDetailModal extends StatefulWidget {
  final Item item;

  const ItemDetailModal({super.key, required this.item});

  @override
  State<ItemDetailModal> createState() => _ItemDetailModalState();
}

class _ItemDetailModalState extends State<ItemDetailModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _ratingController;
  late final Set<String> _selectedCategoryIds;
  late final List<String> _imagePaths; // originals only
  final _segmentedPaths = <String, String>{}; // original → segmented
  late String? _thumbnailPath;
  final List<String> _pendingPhotoDeletes = [];
  String? _nameError;

  bool get _hasChanges {
    if (_nameController.text != widget.item.name) return true;
    if (_descriptionController.text != widget.item.description) return true;
    if (_ratingController.text != widget.item.ranking.toStringAsFixed(2)) return true;
    if (!_setEquals(_selectedCategoryIds, Set<String>.from(widget.item.categories))) return true;
    if (!_listEquals(_imagePaths, widget.item.images)) return true;
    final origThumb = widget.item.thumbnailImage ?? (widget.item.images.isNotEmpty ? widget.item.images.first : null);
    if (_thumbnailPath != origThumb) return true;
    return false;
  }

  bool _setEquals(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _descriptionController = TextEditingController(text: widget.item.description);
    _ratingController = TextEditingController(text: widget.item.ranking.toStringAsFixed(2));
    _selectedCategoryIds = Set<String>.from(widget.item.categories);
    // Originals only — segmented paths are tracked separately
    _imagePaths = widget.item.images.where((p) => !p.contains('_seg')).toList();
    // Build segmented map — only for files that actually exist
    _buildSegmentedMap();
    _thumbnailPath = widget.item.thumbnailImage ??
        (_imagePaths.isNotEmpty ? _displayPath(_imagePaths.first) : null);
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _ratingController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _descriptionController.removeListener(_onFieldChanged);
    _ratingController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  bool get _showSegmented => getIt<SettingsService>().getShowSegmentedSync();

  Future<void> _buildSegmentedMap() async {
    _segmentedPaths.clear();
    for (final path in _imagePaths) {
      final segPath = getIt<SegmentationService>().segmentedRelativePath(path);
      final absPath = await getIt<PhotoStorageService>().resolvePhotoPath(segPath);
      if (File(absPath).existsSync()) {
        _segmentedPaths[path] = segPath;
      }
    }
    if (mounted) {
      setState(() {
        // Re-evaluate thumbnail with correct segmented map
        _thumbnailPath = widget.item.thumbnailImage ??
            (_imagePaths.isNotEmpty ? _displayPath(_imagePaths.first) : null);
      });
    }
  }

  String _displayPath(String originalPath) {
    if (_showSegmented && _segmentedPaths.containsKey(originalPath)) {
      return _segmentedPaths[originalPath]!;
    }
    return originalPath;
  }

  void _onPhotoAdded(String path) {
    setState(() {
      _imagePaths.add(path);
      _thumbnailPath ??= path;
    });
    _trySegment(path);
  }

  Future<void> _trySegment(String path) async {
    final segPath = await getIt<SegmentationService>().removeBackground(path);
    if (!mounted || segPath == null) return;
    setState(() {
      _segmentedPaths[path] = segPath;
      if (_showSegmented && _thumbnailPath == path) {
        _thumbnailPath = segPath;
      }
    });
  }

  void _onRemovePhoto(int index) {
    final path = _imagePaths[index];
    setState(() {
      _imagePaths.removeAt(index);
      _pendingPhotoDeletes.add(path);
      _segmentedPaths.remove(path);
      if (_thumbnailPath == path || _thumbnailPath == _segmentedPaths[path]) {
        _thumbnailPath = _imagePaths.isNotEmpty ? _displayPath(_imagePaths.first) : null;
      }
    });
  }

  void _onSetThumbnail(int index) {
    setState(() => _thumbnailPath = _displayPath(_imagePaths[index]));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty && _imagePaths.isEmpty) {
      setState(() => _nameError = 'Name is required when no photo exists');
      return;
    }

    final ratingText = _ratingController.text.trim();
    double ranking = widget.item.ranking;
    if (ratingText.isNotEmpty) {
      final parsed = double.tryParse(ratingText);
      if (parsed == null || parsed < 0 || parsed > 10) {
        return;
      }
      ranking = double.parse(parsed.toStringAsFixed(2));
    }

    final updated = widget.item.copyWith(
      name: name,
      description: _descriptionController.text.trim(),
      ranking: ranking,
      updatedAt: DateTime.now(),
      categories: _selectedCategoryIds.toList(),
      images: List.from(_imagePaths),
      thumbnailImage: _thumbnailPath,
    );

    // Delete photos that were removed (both original + segmented)
    for (final path in _pendingPhotoDeletes) {
      await getIt<PhotoStorageService>().deletePhotoPair(path);
    }

    context.read<InventoryBloc>().add(UpdateItem(updated));
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('Are you sure you want to delete this item?'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: kSpace),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final path in widget.item.images) {
        await getIt<PhotoStorageService>().deletePhoto(path);
      }
      if (mounted) {
        context.read<InventoryBloc>().add(DeleteItem(widget.item.itemId));
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kSpace, kSpace, kSpace,
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
                labelText: 'Rating (0-10)',
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
            if (_imagePaths.length < 5)
              AddPhotoButton(onPhotoAdded: _onPhotoAdded),
            const SizedBox(height: kSpace),

            // Save
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _hasChanges ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
              secondChild: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: const Text('Save'),
                ),
              ),
            ),
            const SizedBox(height: kSpace),

            // Delete
            OutlinedButton(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(foregroundColor: kColorBlack),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

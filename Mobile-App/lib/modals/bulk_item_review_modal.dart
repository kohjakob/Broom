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
import '../screens/bulk_camera_screen.dart';
import '../widgets/chip.dart';
import '../widgets/item_photo.dart';

class _BulkItemData {
  final String photoPath;
  final TextEditingController nameController;
  final TextEditingController ratingController;
  final Set<String> categoryIds;
  bool detectingName;
  String? segmentedPath;

  _BulkItemData({required this.photoPath})
      : nameController = TextEditingController(),
        ratingController = TextEditingController(text: '5.0'),
        categoryIds = {},
        detectingName = false;

  void dispose() {
    nameController.dispose();
    ratingController.dispose();
  }
}

class BulkItemReviewModal extends StatefulWidget {
  final List<String> photoPaths;
  final Set<String> initialCategoryIds;

  const BulkItemReviewModal({super.key, required this.photoPaths, this.initialCategoryIds = const {}});

  @override
  State<BulkItemReviewModal> createState() => _BulkItemReviewModalState();
}

class _BulkItemReviewModalState extends State<BulkItemReviewModal> {
  late final List<_BulkItemData> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.photoPaths.map((p) {
      final data = _BulkItemData(photoPath: p);
      data.categoryIds.addAll(widget.initialCategoryIds);
      return data;
    }).toList();
    _tryAutoDetectAll();
    _trySegmentAll(_items);
  }

  Future<void> _tryAutoDetectAll() async {
    if (!await getIt<SettingsService>().hasApiKey()) return;
    final claude = getIt<ClaudeApiService>();

    // Get category names for Claude to pick from
    final categoryState = context.read<CategoryBloc>().state;
    final categoryNames = categoryState.categories.map((c) => c.name).toList();
    final categoryNameToId = <String, String>{};
    for (final cat in categoryState.categories) {
      categoryNameToId[cat.name] = cat.categoryId;
    }

    // Process in batches of 3
    for (int i = 0; i < _items.length; i += 3) {
      final batch = <Future<void>>[];
      for (int j = i; j < i + 3 && j < _items.length; j++) {
        final index = j;
        batch.add(() async {
          if (!mounted) return;
          setState(() => _items[index].detectingName = true);
          final resolvedPath = await getIt<PhotoStorageService>().resolvePhotoPath(_items[index].photoPath);
          final result = await claude.detectItem(File(resolvedPath), categoryNames);
          if (!mounted) return;
          setState(() {
            _items[index].detectingName = false;
            if (result.name != null && _items[index].nameController.text.trim().isEmpty) {
              _items[index].nameController.text = result.name!;
            }
            if (result.category != null) {
              final catId = categoryNameToId[result.category];
              if (catId != null) {
                _items[index].categoryIds.add(catId);
              }
            }
          });
        }());
      }
      await Future.wait(batch);
    }
  }

  Future<void> _trySegmentAll(List<_BulkItemData> items) async {
    final segService = getIt<SegmentationService>();
    for (int i = 0; i < items.length; i += 3) {
      final batch = <Future<void>>[];
      for (int j = i; j < i + 3 && j < items.length; j++) {
        final item = items[j];
        batch.add(() async {
          final segPath = await segService.removeBackground(item.photoPath);
          if (!mounted || segPath == null) return;
          setState(() => item.segmentedPath = segPath);
        }());
      }
      await Future.wait(batch);
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  bool get _canSave {
    return _items.isNotEmpty && _items.every((item) => item.nameController.text.trim().isNotEmpty);
  }

  void _removeItem(int index) async {
    await getIt<PhotoStorageService>().deletePhotoPair(_items[index].photoPath);
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  Future<void> _addMore() async {
    final photoPaths = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const BulkCameraScreen()),
    );
    if (photoPaths == null || photoPaths.isEmpty || !mounted) return;

    final newItems = photoPaths.map((p) => _BulkItemData(photoPath: p)).toList();
    setState(() => _items.addAll(newItems));
    _tryAutoDetectItems(newItems);
    _trySegmentAll(newItems);
  }

  Future<void> _tryAutoDetectItems(List<_BulkItemData> items) async {
    if (!await getIt<SettingsService>().hasApiKey()) return;
    if (!mounted) return;
    final claude = getIt<ClaudeApiService>();

    final categoryState = context.read<CategoryBloc>().state;
    final categoryNames = categoryState.categories.map((c) => c.name).toList();
    final categoryNameToId = <String, String>{};
    for (final cat in categoryState.categories) {
      categoryNameToId[cat.name] = cat.categoryId;
    }

    for (int i = 0; i < items.length; i += 3) {
      final batch = <Future<void>>[];
      for (int j = i; j < i + 3 && j < items.length; j++) {
        final item = items[j];
        batch.add(() async {
          if (!mounted) return;
          setState(() => item.detectingName = true);
          final resolvedPath = await getIt<PhotoStorageService>().resolvePhotoPath(item.photoPath);
          final result = await claude.detectItem(File(resolvedPath), categoryNames);
          if (!mounted) return;
          setState(() {
            item.detectingName = false;
            if (result.name != null && item.nameController.text.trim().isEmpty) {
              item.nameController.text = result.name!;
            }
            if (result.category != null) {
              final catId = categoryNameToId[result.category];
              if (catId != null) {
                item.categoryIds.add(catId);
              }
            }
          });
        }());
      }
      await Future.wait(batch);
    }
  }

  void _saveAll() {
    if (!_canSave) return;

    final now = DateTime.now();
    final items = <Item>[];

    for (final itemData in _items) {
      final ratingText = itemData.ratingController.text.trim();
      double ranking = 5.0;
      if (ratingText.isNotEmpty) {
        final parsed = double.tryParse(ratingText);
        if (parsed != null && parsed >= 0 && parsed <= 10) {
          ranking = double.parse(parsed.toStringAsFixed(2));
        }
      }

      items.add(Item(
        itemId: const Uuid().v4(),
        name: itemData.nameController.text.trim(),
        createdAt: now,
        updatedAt: now,
        ranking: ranking,
        categories: itemData.categoryIds.toList(),
        images: [itemData.photoPath],
        thumbnailImage: (getIt<SettingsService>().getShowSegmentedSync() && itemData.segmentedPath != null)
            ? itemData.segmentedPath
            : itemData.photoPath,
      ));
    }

    context.read<InventoryBloc>().add(CreateItems(items));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace, 0, 0, 0),
          child: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(kElementHeight, kElementHeight),
              ),
              child: const Icon(Icons.arrow_back, size: kIconSize),
            ),
          ),
        ),
        title: const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, kSpace, 0),
            child: OutlinedButton.icon(
              onPressed: _addMore,
              icon: const Icon(Icons.add, size: kIconSize),
              label: const Text('Add more'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, kSpace, 0),
            child: FilledButton(
              onPressed: _canSave ? _saveAll : null,
              child: const Text('Save All'),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildItemRow(context, index),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.fromLTRB(kSpace, 0, kSpace, kSpace),
      decoration: BoxDecoration(
        color: kColorFill,
        borderRadius: BorderRadius.circular(kBorderRadius),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(kBorderRadiusButton),
                  child: SizedBox(
                    width: kThumbnailSize,
                    height: kThumbnailSize,
                    child: ItemPhoto(relativePath: item.photoPath),
                  ),
                ),
                const SizedBox(height: kSpace),
                // Name
                TextField(
                  controller: item.nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    suffixIcon: item.detectingName
                        ? const SizedBox(width: kSpinnerSize, height: kSpinnerSize, child: CircularProgressIndicator(strokeWidth: 2))
                        : null,
                    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: kSpace),
                // Rating
                TextField(
                  controller: item.ratingController,
                  decoration: const InputDecoration(
                    labelText: 'Rating',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [RatingInputFormatter()],
                ),
                const SizedBox(height: kSpace),
                // Category blobs
                BlocBuilder<CategoryBloc, CategoryState>(
                  builder: (context, state) {
                    if (state.categories.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      height: kElementHeight,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: kSpace),
                        itemBuilder: (context, catIndex) {
                          final cat = state.categories[catIndex];
                          final selected = item.categoryIds.contains(cat.categoryId);
                          return AppChip(
                            label: cat.name,
                            emoji: cat.emoji,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  item.categoryIds.remove(cat.categoryId);
                                } else {
                                  item.categoryIds.add(cat.categoryId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          kIconOverlay(icon: Icons.close, onTap: () => _removeItem(index)),
        ],
      ),
    );
  }
}

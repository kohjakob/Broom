import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/category_bloc.dart';
import '../blocs/inventory_bloc.dart';
import '../theme.dart';
import '../widgets/category_list.dart';
import '../models/item.dart';
import '../modals/add_category_modal.dart';
import '../modals/add_item_modal.dart';
import '../modals/bulk_item_review_modal.dart';
import '../modals/category_detail_modal.dart';
import '../modals/item_detail_modal.dart';
import 'bulk_camera_screen.dart';
import '../widgets/fading_scroll_area.dart';
import '../widgets/inventory_grid.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => InventoryScreenState();
}

class InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  InventoryBloc get _inventoryBloc => context.read<InventoryBloc>();

  void refreshItems() {
    _inventoryBloc.add(RefreshItems());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openBulkAddFlow(BuildContext context) async {
    final photoPaths = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const BulkCameraScreen()),
    );
    if (photoPaths == null || photoPaths.isEmpty || !mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<CategoryBloc>(),
          child: BulkItemReviewModal(photoPaths: photoPaths),
        ),
      ),
    );
    if (result == true) {
      _inventoryBloc.add(RefreshItems());
    }
  }

  Future<void> _openAddCategoryModal(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddCategoryModal(),
    );
    if (result == true) {
      if (context.mounted) context.read<CategoryBloc>().add(LoadCategories());
      _inventoryBloc.add(RefreshItems());
    }
  }

  Future<void> _openCategoryDetailModal(BuildContext context, String categoryId) async {
    final bloc = context.read<CategoryBloc>();
    final category = bloc.state.categories.where((c) => c.categoryId == categoryId).firstOrNull;
    if (category == null) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CategoryDetailModal(category: category),
    );
    if (result == true) {
      if (context.mounted) context.read<CategoryBloc>().add(LoadCategories());
      _inventoryBloc.add(RefreshItems());
    }
  }

  Future<void> _openItemDetailModal(BuildContext context, Item item) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<CategoryBloc>(),
        child: ItemDetailModal(item: item),
      ),
    );
    if (result == true) {
      _inventoryBloc.add(RefreshItems());
    }
  }

  Future<void> _openAddItemModal(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<CategoryBloc>(),
        child: const AddItemModal(),
      ),
    );
    if (result == true) {
      _inventoryBloc.add(RefreshItems());
    }
  }

  void _showSortSheet(BuildContext context, SortOption current) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...SortOption.values.map((option) {
              final isSelected = option == current;
              final isLast = option == SortOption.values.last;
              return Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, isLast ? 0 : kSpace),
                child: OutlinedButton(
                  onPressed: () {
                    _inventoryBloc.add(SortItems(option));
                    Navigator.of(ctx).pop();
                  },
                  style: isSelected
                      ? OutlinedButton.styleFrom(side: kBorderSideActive)
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(option.label),
                      if (isSelected)
                        const Icon(Icons.check, size: kIconSize),
                    ],
                  ),
                ),
              );
            }),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToCategoryOptions(BuildContext context, Set<String> categoryIds) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => BlocProvider.value(
                      value: context.read<CategoryBloc>(),
                      child: AddItemModal(initialCategoryIds: categoryIds),
                    ),
                  );
                  if (result == true) _inventoryBloc.add(RefreshItems());
                },
                icon: const Icon(Icons.add, size: kIconSize),
                label: const Text('Item'),
              ),
              const SizedBox(height: kSpace),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final photoPaths = await Navigator.of(context).push<List<String>>(
                    MaterialPageRoute(builder: (_) => const BulkCameraScreen()),
                  );
                  if (photoPaths == null || photoPaths.isEmpty || !context.mounted) return;
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<CategoryBloc>(),
                        child: BulkItemReviewModal(
                          photoPaths: photoPaths,
                          initialCategoryIds: categoryIds,
                        ),
                      ),
                    ),
                  );
                  if (result == true) _inventoryBloc.add(RefreshItems());
                },
                icon: const Icon(Icons.add, size: kIconSize),
                label: const Text('Bulk'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _inventoryBloc.add(SearchItems(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CategoryBloc, CategoryState>(
      listenWhen: (prev, curr) => prev.selectedCategoryIds != curr.selectedCategoryIds,
      listener: (context, categoryState) {
        _inventoryBloc.add(FilterByCategories(categoryState.selectedCategoryIds));
      },
      child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Category List
                BlocBuilder<CategoryBloc, CategoryState>(
                  builder: (context, state) {
                    return CategoryList(
                      categories: state.categories,
                      selectedCategoryIds: state.selectedCategoryIds,
                      onSelectAll: () => context.read<CategoryBloc>().add(SelectAll()),
                      onToggleCategory: (id) => context.read<CategoryBloc>().add(ToggleCategory(id)),
                      onEditCategory: (id) => _openCategoryDetailModal(context, id),
                      onAddCategory: () => _openAddCategoryModal(context),
                    );
                  },
                ),
                // Add buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openAddItemModal(context),
                          icon: const Icon(Icons.add, size: kIconSize),
                          label: const Text('Add Item'),
                        ),
                      ),
                      const SizedBox(width: kSpace),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openBulkAddFlow(context),
                          icon: const Icon(Icons.add, size: kIconSize),
                          label: const Text('Add Bulk'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpace, 0, kSpace, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: kSpace, right: kSpace / 2),
                        child: Icon(Icons.search, size: kIconSize),
                      ),
                      prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
                // Sorting
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, 0),
                  child: BlocBuilder<InventoryBloc, InventoryState>(
                    buildWhen: (prev, curr) => prev.sortOption != curr.sortOption,
                    builder: (context, state) {
                      return OutlinedButton(
                        onPressed: () => _showSortSheet(context, state.sortOption),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(state.sortOption.label),
                            const Icon(Icons.expand_more, size: kIconSize),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: kSpace),
                // Grid with fade edges
                Expanded(
                  child: FadingScrollArea(
                    child: BlocBuilder<InventoryBloc, InventoryState>(
                      builder: (context, invState) {
                        if (invState.status == InventoryStatus.loading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return BlocBuilder<CategoryBloc, CategoryState>(
                          builder: (context, catState) {
                            final activeIds = catState.selectedCategoryIds;
                            final hasSingleCategory = activeIds.length == 1 &&
                                !activeIds.contains(kUncategorizedId);
                            String? addLabel;
                            if (hasSingleCategory) {
                              final cat = catState.categories
                                  .where((c) => activeIds.contains(c.categoryId))
                                  .firstOrNull;
                              if (cat != null) addLabel = 'Add to ${cat.name}';
                            }
                            return InventoryGrid(
                              items: invState.displayedItems,
                              onItemTap: (item) => _openItemDetailModal(context, item),
                              addToCategoryLabel: addLabel,
                              onAddToCategory: addLabel != null
                                  ? () => _showAddToCategoryOptions(context, activeIds)
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

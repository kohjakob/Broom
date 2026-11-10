import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import '../theme.dart';

enum SortOption {
  newestFirst('Newest first'),
  oldestFirst('Oldest first'),
  bestRated('Best rated first'),
  worstRated('Worst rated first'),
  alphabetical('Alphabetical A-Z');

  final String label;
  const SortOption(this.label);
}

sealed class InventoryEvent {}

class LoadItems extends InventoryEvent {}

class RefreshItems extends InventoryEvent {}

class FilterByCategories extends InventoryEvent {
  final Set<String> categoryIds;
  FilterByCategories(this.categoryIds);
}

class SearchItems extends InventoryEvent {
  final String query;
  SearchItems(this.query);
}

class SortItems extends InventoryEvent {
  final SortOption option;
  SortItems(this.option);
}

class CreateItem extends InventoryEvent {
  final Item item;
  CreateItem(this.item);
}

class CreateItems extends InventoryEvent {
  final List<Item> items;
  CreateItems(this.items);
}

class UpdateItem extends InventoryEvent {
  final Item item;
  UpdateItem(this.item);
}

class DeleteItem extends InventoryEvent {
  final String itemId;
  DeleteItem(this.itemId);
}

enum InventoryStatus { loading, loaded, error }

class InventoryState {
  final List<Item> allItems;
  final List<Item> displayedItems;
  final String searchQuery;
  final SortOption sortOption;
  final Set<String> activeCategoryIds;
  final InventoryStatus status;

  const InventoryState({
    this.allItems = const [],
    this.displayedItems = const [],
    this.searchQuery = '',
    this.sortOption = SortOption.newestFirst,
    this.activeCategoryIds = const {},
    this.status = InventoryStatus.loading,
  });

  InventoryState copyWith({
    List<Item>? allItems,
    List<Item>? displayedItems,
    String? searchQuery,
    SortOption? sortOption,
    Set<String>? activeCategoryIds,
    InventoryStatus? status,
  }) {
    return InventoryState(
      allItems: allItems ?? this.allItems,
      displayedItems: displayedItems ?? this.displayedItems,
      searchQuery: searchQuery ?? this.searchQuery,
      sortOption: sortOption ?? this.sortOption,
      activeCategoryIds: activeCategoryIds ?? this.activeCategoryIds,
      status: status ?? this.status,
    );
  }
}

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final DatabaseService _db;

  InventoryBloc(this._db) : super(const InventoryState()) {
    on<LoadItems>(_onLoad);
    on<RefreshItems>(_onRefresh);
    on<FilterByCategories>(_onFilter);
    on<SearchItems>(_onSearch);
    on<SortItems>(_onSort);
    on<CreateItem>(_onCreate);
    on<CreateItems>(_onCreateMany);
    on<UpdateItem>(_onUpdate);
    on<DeleteItem>(_onDelete);
  }

  Future<void> _onLoad(LoadItems event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading));
    final items = await _db.getAllItems();
    emit(state.copyWith(
      allItems: items,
      status: InventoryStatus.loaded,
    ));
    _applyFilters(emit);
  }

  Future<void> _onRefresh(RefreshItems event, Emitter<InventoryState> emit) async {
    final items = await _db.getAllItems();
    emit(state.copyWith(allItems: items));
    _applyFilters(emit);
  }

  void _onFilter(FilterByCategories event, Emitter<InventoryState> emit) {
    emit(state.copyWith(activeCategoryIds: event.categoryIds));
    _applyFilters(emit);
  }

  void _onSearch(SearchItems event, Emitter<InventoryState> emit) {
    emit(state.copyWith(searchQuery: event.query));
    _applyFilters(emit);
  }

  void _onSort(SortItems event, Emitter<InventoryState> emit) {
    emit(state.copyWith(sortOption: event.option));
    _applyFilters(emit);
  }

  Future<void> _onCreate(CreateItem event, Emitter<InventoryState> emit) async {
    await _db.insertItem(event.item);
    final items = await _db.getAllItems();
    emit(state.copyWith(allItems: items));
    _applyFilters(emit);
  }

  Future<void> _onCreateMany(CreateItems event, Emitter<InventoryState> emit) async {
    for (final item in event.items) {
      await _db.insertItem(item);
    }
    final items = await _db.getAllItems();
    emit(state.copyWith(allItems: items));
    _applyFilters(emit);
  }

  Future<void> _onUpdate(UpdateItem event, Emitter<InventoryState> emit) async {
    await _db.updateItem(event.item);
    final items = await _db.getAllItems();
    emit(state.copyWith(allItems: items));
    _applyFilters(emit);
  }

  Future<void> _onDelete(DeleteItem event, Emitter<InventoryState> emit) async {
    await _db.deleteItem(event.itemId);
    final items = await _db.getAllItems();
    emit(state.copyWith(allItems: items));
    _applyFilters(emit);
  }

  void _applyFilters(Emitter<InventoryState> emit) {
    var items = List<Item>.from(state.allItems);

    // 1. Category filter
    if (state.activeCategoryIds.isNotEmpty) {
      final wantUncategorized = state.activeCategoryIds.contains(kUncategorizedId);
      final categoryIds = state.activeCategoryIds.where((id) => id != kUncategorizedId).toSet();
      items = items.where((item) {
        if (wantUncategorized && item.categories.isEmpty) return true;
        if (categoryIds.isNotEmpty && item.categories.any(categoryIds.contains)) return true;
        return false;
      }).toList();
    }

    // 2. Search filter
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      items = items.where((item) {
        return item.name.toLowerCase().contains(query);
      }).toList();
    }

    // 3. Sort
    switch (state.sortOption) {
      case SortOption.newestFirst:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortOption.oldestFirst:
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case SortOption.bestRated:
        items.sort((a, b) => b.ranking.compareTo(a.ranking));
      case SortOption.worstRated:
        items.sort((a, b) => a.ranking.compareTo(b.ranking));
      case SortOption.alphabetical:
        items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    emit(state.copyWith(displayedItems: items));
  }
}

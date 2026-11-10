import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/category.dart';
import '../services/database_service.dart';

sealed class CategoryEvent {}

class LoadCategories extends CategoryEvent {}

class CreateCategory extends CategoryEvent {
  final Category category;
  final Set<String> itemIds;
  CreateCategory(this.category, {this.itemIds = const {}});
}

class UpdateCategoryFull extends CategoryEvent {
  final Category category;
  final Set<String> itemIds;
  UpdateCategoryFull(this.category, {this.itemIds = const {}});
}

class DeleteCategory extends CategoryEvent {
  final String categoryId;
  DeleteCategory(this.categoryId);
}

class ToggleCategory extends CategoryEvent {
  final String categoryId;
  ToggleCategory(this.categoryId);
}

class SelectAll extends CategoryEvent {}

enum CategoryStatus { loading, loaded, error }

class CategoryState {
  final List<Category> categories;
  final Set<String> selectedCategoryIds;
  final CategoryStatus status;

  const CategoryState({
    this.categories = const [],
    this.selectedCategoryIds = const {},
    this.status = CategoryStatus.loading,
  });

  bool get isAllSelected => selectedCategoryIds.isEmpty;

  CategoryState copyWith({
    List<Category>? categories,
    Set<String>? selectedCategoryIds,
    CategoryStatus? status,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      status: status ?? this.status,
    );
  }
}

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final DatabaseService _db;

  CategoryBloc(this._db) : super(const CategoryState()) {
    on<LoadCategories>(_onLoad);
    on<CreateCategory>(_onCreate);
    on<UpdateCategoryFull>(_onUpdate);
    on<DeleteCategory>(_onDelete);
    on<ToggleCategory>(_onToggle);
    on<SelectAll>(_onSelectAll);
  }

  Future<Set<String>> getItemIdsForCategory(String categoryId) async {
    final ids = await _db.getItemIdsForCategory(categoryId);
    return ids.toSet();
  }

  Future<void> _onLoad(LoadCategories event, Emitter<CategoryState> emit) async {
    emit(state.copyWith(status: CategoryStatus.loading));
    final categories = await _db.getAllCategories();
    emit(state.copyWith(categories: categories, status: CategoryStatus.loaded));
  }

  Future<void> _onCreate(CreateCategory event, Emitter<CategoryState> emit) async {
    await _db.insertCategory(event.category);
    if (event.itemIds.isNotEmpty) {
      await _db.syncCategoryItems(event.category.categoryId, event.itemIds.toList());
    }
    final categories = await _db.getAllCategories();
    emit(state.copyWith(categories: categories));
  }

  Future<void> _onUpdate(UpdateCategoryFull event, Emitter<CategoryState> emit) async {
    await _db.updateCategory(event.category);
    await _db.syncCategoryItems(event.category.categoryId, event.itemIds.toList());
    final categories = await _db.getAllCategories();
    emit(state.copyWith(categories: categories));
  }

  Future<void> _onDelete(DeleteCategory event, Emitter<CategoryState> emit) async {
    await _db.deleteCategory(event.categoryId);
    final categories = await _db.getAllCategories();
    final selected = Set<String>.from(state.selectedCategoryIds)
      ..remove(event.categoryId);
    emit(state.copyWith(categories: categories, selectedCategoryIds: selected));
  }

  void _onToggle(ToggleCategory event, Emitter<CategoryState> emit) {
    final selected = Set<String>.from(state.selectedCategoryIds);
    if (selected.contains(event.categoryId)) {
      selected.remove(event.categoryId);
    } else {
      selected.add(event.categoryId);
    }
    emit(state.copyWith(selectedCategoryIds: selected));
  }

  void _onSelectAll(SelectAll event, Emitter<CategoryState> emit) {
    emit(state.copyWith(selectedCategoryIds: {}));
  }
}

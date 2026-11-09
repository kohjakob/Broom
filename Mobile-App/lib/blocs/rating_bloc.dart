import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import '../services/elo_service.dart';
import '../theme.dart';

sealed class RatingEvent {}

class LoadRatingPool extends RatingEvent {
  final Set<String> categoryIds;
  LoadRatingPool(this.categoryIds);
}

class SwipeCard extends RatingEvent {
  final SwipeTarget target;
  SwipeCard(this.target);
}

enum SwipeTarget { top, bottom }

class DrawNewPair extends RatingEvent {}

class RefreshCurrentItems extends RatingEvent {}

enum RatingStatus { loading, ready, empty, animating }

class RatingState {
  final Item? topItem;
  final Item? bottomItem;
  final Item? nextTopItem;
  final Item? nextBottomItem;
  final List<Item> pool;
  final RatingStatus status;

  const RatingState({
    this.topItem,
    this.bottomItem,
    this.nextTopItem,
    this.nextBottomItem,
    this.pool = const [],
    this.status = RatingStatus.loading,
  });

  RatingState copyWith({
    Item? topItem,
    Item? bottomItem,
    Item? nextTopItem,
    Item? nextBottomItem,
    List<Item>? pool,
    RatingStatus? status,
  }) {
    return RatingState(
      topItem: topItem ?? this.topItem,
      bottomItem: bottomItem ?? this.bottomItem,
      nextTopItem: nextTopItem ?? this.nextTopItem,
      nextBottomItem: nextBottomItem ?? this.nextBottomItem,
      pool: pool ?? this.pool,
      status: status ?? this.status,
    );
  }
}

class RatingBloc extends Bloc<RatingEvent, RatingState> {
  final DatabaseService _db;
  final EloService _elo;
  final _random = Random();
  final List<(String, String)> _recentPairs = [];
  Set<String> _currentCategoryIds = {};

  RatingBloc(this._db, this._elo) : super(const RatingState()) {
    on<LoadRatingPool>(_onLoad);
    on<SwipeCard>(_onSwipe);
    on<DrawNewPair>(_onDrawNewPair);
    on<RefreshCurrentItems>(_onRefreshCurrentItems);
  }

  Future<void> _onLoad(LoadRatingPool event, Emitter<RatingState> emit) async {
    _currentCategoryIds = event.categoryIds;
    emit(state.copyWith(status: RatingStatus.loading));

    final items = await _fetchItems(event.categoryIds);

    if (items.length < 2) {
      emit(RatingState(pool: items, status: RatingStatus.empty));
      return;
    }

    emit(state.copyWith(pool: items));
    _drawPair(emit, items);
    _drawNextPair(emit, items);
  }

  Future<List<Item>> _fetchItems(Set<String> categoryIds) async {
    if (categoryIds.isEmpty) return _db.getAllItems();

    final wantUncategorized = categoryIds.contains(kUncategorizedId);
    final realIds = categoryIds.where((id) => id != kUncategorizedId).toList();

    final allItems = await _db.getAllItems();
    return allItems.where((item) {
      if (wantUncategorized && item.categories.isEmpty) return true;
      if (realIds.isNotEmpty && item.categories.any(realIds.contains)) return true;
      return false;
    }).toList();
  }

  Future<void> _onSwipe(SwipeCard event, Emitter<RatingState> emit) async {
    final topItem = state.topItem;
    final bottomItem = state.bottomItem;
    if (topItem == null || bottomItem == null) return;

    final Item winner;
    final Item loser;
    if (event.target == SwipeTarget.top) {
      loser = topItem;
      winner = bottomItem;
    } else {
      loser = bottomItem;
      winner = topItem;
    }

    // Calculate new ratings
    final (newWinnerRating, newLoserRating) = _elo.calculateNewRatings(winner.ranking, loser.ranking);

    // Update in DB (fire-and-forget — don't block the UI)
    final updatedWinner = winner.copyWith(
      ranking: newWinnerRating,
      ratingCount: winner.ratingCount + 1,
      updatedAt: DateTime.now(),
    );
    final updatedLoser = loser.copyWith(
      ranking: newLoserRating,
      ratingCount: loser.ratingCount + 1,
      updatedAt: DateTime.now(),
    );
    _db.updateItem(updatedWinner);
    _db.updateItem(updatedLoser);

    // Track recent pair
    final pairKey = _makePairKey(winner.itemId, loser.itemId);
    _recentPairs.add(pairKey);
    if (_recentPairs.length > 20) {
      _recentPairs.removeAt(0);
    }

    // Emit animating state — next pair is already pre-loaded as back cards
    emit(state.copyWith(status: RatingStatus.animating));
  }

  Future<void> _onDrawNewPair(DrawNewPair event, Emitter<RatingState> emit) async {
    // Promote next pair to current immediately (no DB wait)
    emit(RatingState(
      topItem: state.nextTopItem,
      bottomItem: state.nextBottomItem,
      pool: state.pool,
      status: RatingStatus.ready,
    ));

    // Fetch updated pool and pre-draw next pair in background
    final items = await _fetchItems(_currentCategoryIds);

    if (items.length < 2) {
      emit(RatingState(pool: items, status: RatingStatus.empty));
      return;
    }

    // Pre-draw next pair with fresh pool
    emit(state.copyWith(pool: items));
    _drawNextPair(emit, items);
  }

  void _drawPair(Emitter<RatingState> emit, List<Item> items) {
    final pair = _pickPair(items);
    if (pair != null) {
      emit(state.copyWith(
        topItem: pair.$1,
        bottomItem: pair.$2,
        status: RatingStatus.ready,
      ));
    }
  }

  void _drawNextPair(Emitter<RatingState> emit, List<Item> items) {
    final pair = _pickPair(items);
    if (pair != null) {
      emit(state.copyWith(
        nextTopItem: pair.$1,
        nextBottomItem: pair.$2,
      ));
    }
  }

  (Item, Item)? _pickPair(List<Item> items) {
    if (items.length < 2) return null;
    const maxAttempts = 50;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final i = _random.nextInt(items.length);
      var j = _random.nextInt(items.length);
      while (j == i) {
        j = _random.nextInt(items.length);
      }

      final pair = _makePairKey(items[i].itemId, items[j].itemId);
      if (!_recentPairs.contains(pair) || attempt == maxAttempts - 1) {
        return (items[i], items[j]);
      }
    }
    return null;
  }

  Future<void> _onRefreshCurrentItems(RefreshCurrentItems event, Emitter<RatingState> emit) async {
    final items = await _fetchItems(_currentCategoryIds);

    // If we had no pair but now have enough items, draw a fresh pair
    if (state.topItem == null || state.bottomItem == null) {
      if (items.length < 2) {
        emit(RatingState(pool: items, status: RatingStatus.empty));
      } else {
        emit(state.copyWith(pool: items));
        _drawPair(emit, items);
        _drawNextPair(emit, items);
      }
      return;
    }

    Item? findUpdated(Item? current) {
      if (current == null) return null;
      return items.where((i) => i.itemId == current.itemId).firstOrNull;
    }

    final updatedTop = findUpdated(state.topItem);
    final updatedBottom = findUpdated(state.bottomItem);

    // If either current item was deleted, draw a fresh pair
    if (updatedTop == null || updatedBottom == null) {
      if (items.length < 2) {
        emit(RatingState(pool: items, status: RatingStatus.empty));
      } else {
        emit(state.copyWith(pool: items));
        _drawPair(emit, items);
        _drawNextPair(emit, items);
      }
      return;
    }

    emit(state.copyWith(
      topItem: updatedTop,
      bottomItem: updatedBottom,
      pool: items,
    ));

    // Redraw next pair so new items can appear
    _drawNextPair(emit, items);
  }

  (String, String) _makePairKey(String a, String b) {
    return a.compareTo(b) < 0 ? (a, b) : (b, a);
  }
}

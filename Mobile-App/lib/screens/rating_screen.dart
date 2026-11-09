import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../blocs/category_bloc.dart';
import '../blocs/rating_bloc.dart';
import '../modals/add_category_modal.dart';
import '../modals/category_detail_modal.dart';
import '../modals/item_detail_modal.dart';
import '../models/item.dart';
import '../theme.dart';
import '../widgets/card_item.dart';
import '../widgets/category_list.dart';
import '../widgets/swipeable_card.dart';

class RatingScreen extends StatefulWidget {
  final VoidCallback? onSwitchToInventory;

  const RatingScreen({super.key, this.onSwitchToInventory});

  @override
  State<RatingScreen> createState() => RatingScreenState();
}

class RatingScreenState extends State<RatingScreen> {
  RatingBloc get _ratingBloc => context.read<RatingBloc>();

  // Local display state — decoupled from BLoC to avoid mid-animation rebuilds
  Item? _topItem;
  Item? _bottomItem;
  Item? _nextTopItem;
  Item? _nextBottomItem;
  bool _isEmpty = false;
  bool _isLoading = true;

  // Drag progress for loser fade effect
  double _topDragProgress = 0.0;
  double _bottomDragProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryState = context.read<CategoryBloc>().state;
      _ratingBloc.add(LoadRatingPool(categoryState.selectedCategoryIds));
    });
  }

  void refreshPool() {
    final categoryState = context.read<CategoryBloc>().state;
    _ratingBloc.add(LoadRatingPool(categoryState.selectedCategoryIds));
  }

  void refreshCurrentItems() {
    _ratingBloc.add(RefreshCurrentItems());
  }

  /// Called when BLoC emits a new state. Syncs local display state.
  void _syncFromBloc(RatingState state) {
    setState(() {
      _isLoading = state.status == RatingStatus.loading;
      _isEmpty = state.status == RatingStatus.empty;
      _topItem = state.topItem;
      _bottomItem = state.bottomItem;
      _nextTopItem = state.nextTopItem;
      _nextBottomItem = state.nextBottomItem;
      _topDragProgress = 0.0;
      _bottomDragProgress = 0.0;
    });
  }

  void _onSwiped(SwipeTarget target) {
    // Update ELO and promote next pair immediately
    _ratingBloc.add(SwipeCard(target));
    _ratingBloc.add(DrawNewPair());
  }

  Future<void> _openAddCategoryModal(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddCategoryModal(),
    );
    if (result == true && context.mounted) {
      context.read<CategoryBloc>().add(LoadCategories());
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
    if (result == true && mounted) {
      bloc.add(LoadCategories());
      _ratingBloc.add(LoadRatingPool(bloc.state.selectedCategoryIds));
    }
  }

  Future<void> _openItemDetail(BuildContext context, Item item) async {
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
      _ratingBloc.add(RefreshCurrentItems());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
        listeners: [
          BlocListener<CategoryBloc, CategoryState>(
            listenWhen: (prev, curr) => prev.selectedCategoryIds != curr.selectedCategoryIds,
            listener: (context, categoryState) {
              _ratingBloc.add(LoadRatingPool(categoryState.selectedCategoryIds));
            },
          ),
          BlocListener<RatingBloc, RatingState>(
            listener: (context, state) {
              // Only sync when BLoC has a definitive state (not mid-animation)
              if (state.status == RatingStatus.ready ||
                  state.status == RatingStatus.empty ||
                  state.status == RatingStatus.loading) {
                _syncFromBloc(state);
              }
            },
          ),
        ],
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
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
                Padding(
                  padding: const EdgeInsets.all(kSpace),
                  child: Container(
                    width: double.infinity,
                    height: kElementHeight,
                    decoration: BoxDecoration(
                      color: kColorBlack,
                      borderRadius: BorderRadius.circular(kBorderRadius),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Swipe away the item you use less frequently',
                      style: GoogleFonts.instrumentSans(fontSize: kFontSize, color: kColorWhite),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(child: _buildBody(context)),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isEmpty || _topItem == null || _bottomItem == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(kSpace),
          child: Text(
            'Add at least 2 items to start rating',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: kFontSize, color: kColorGrey),
          ),
        ),
      );
    }
    return _buildCardStacks(context);
  }

  Widget _buildCardStacks(BuildContext context) {
    // Loser opacity: power of 5 curve — stays visible much longer, only fades near full swipe
    final bp = _bottomDragProgress;
    final tp = _topDragProgress;
    final topOpacity = (1.0 - bp * bp * bp * bp * bp).clamp(0.0, 1.0);
    final bottomOpacity = (1.0 - tp * tp * tp * tp * tp).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace, 0, kSpace, kSpace),
      child: Column(
        children: [
          Expanded(
            child: _buildCardSlot(
              item: _topItem!,
              nextItem: _nextTopItem,
              target: SwipeTarget.top,
              cardOpacity: topOpacity,
              onDragProgress: (p) => setState(() => _topDragProgress = p),
              context: context,
            ),
          ),
          const SizedBox(height: kSpace),
          Expanded(
            child: _buildCardSlot(
              item: _bottomItem!,
              nextItem: _nextBottomItem,
              target: SwipeTarget.bottom,
              cardOpacity: bottomOpacity,
              onDragProgress: (p) => setState(() => _bottomDragProgress = p),
              context: context,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSlot({
    required Item item,
    Item? nextItem,
    required SwipeTarget target,
    required double cardOpacity,
    required ValueChanged<double> onDragProgress,
    required BuildContext context,
  }) {
    return Stack(
      children: [
        // Back card: always present — shows current item as fallback,
        // or next item when available. Prevents any white gap frames.
        Positioned.fill(
          child: CardItem(item: nextItem ?? item),
        ),
        // Front card: swipeable, keyed by item ID for natural recreation
        Positioned.fill(
          child: Opacity(
            opacity: cardOpacity,
            child: SwipeableCard(
              key: ValueKey('${target.name}_${item.itemId}'),
              enabled: true,
              onSwipedAway: () => _onSwiped(target),
              onDragProgress: onDragProgress,
              child: CardItem(
                item: item,
                onTap: () => _openItemDetail(context, item),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

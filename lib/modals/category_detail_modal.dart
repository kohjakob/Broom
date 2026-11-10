import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/category_bloc.dart';
import '../blocs/inventory_bloc.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../theme.dart';
import '../widgets/emoji_picker_sheet.dart';
import '../widgets/item_selection_grid.dart';

class CategoryDetailModal extends StatefulWidget {
  final Category category;

  const CategoryDetailModal({super.key, required this.category});

  @override
  State<CategoryDetailModal> createState() => _CategoryDetailModalState();
}

class _CategoryDetailModalState extends State<CategoryDetailModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  final _selectedItemIds = <String>{};
  final _originalItemIds = <String>{};
  String? _nameError;
  List<Item> _allItems = [];
  bool _loading = true;
  bool _expanded = false;

  bool get _hasChanges {
    if (_nameController.text != widget.category.name) return true;
    if (_emojiController.text != (widget.category.emoji ?? '')) return true;
    if (_selectedItemIds.length != _originalItemIds.length || !_selectedItemIds.containsAll(_originalItemIds)) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _emojiController = TextEditingController(text: widget.category.emoji ?? '');
    _nameController.addListener(() => setState(() {}));
    _emojiController.addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    final items = context.read<InventoryBloc>().state.allItems;
    final memberIds = await context.read<CategoryBloc>().getItemIdsForCategory(widget.category.categoryId);
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _selectedItemIds.addAll(memberIds);
      _originalItemIds.addAll(memberIds);
      _loading = false;
    });
  }

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => EmojiPickerSheet(
        hasEmoji: _emojiController.text.isNotEmpty,
        onSelected: (emoji) {
          setState(() => _emojiController.text = emoji);
          Navigator.of(ctx).pop();
        },
        onRemove: () {
          setState(() => _emojiController.text = '');
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }

    final emoji = _emojiController.text.trim();
    final updated = widget.category.copyWith(name: name, emoji: emoji.isNotEmpty ? emoji : null);
    context.read<CategoryBloc>().add(UpdateCategoryFull(updated, itemIds: _selectedItemIds));
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('Are you sure? Items will keep existing but lose this category.'),
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
      if (mounted) {
        context.read<CategoryBloc>().add(DeleteCategory(widget.category.categoryId));
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(kSpace * 3),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  kSpace, kSpace, kSpace,
                  MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + kSpace,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showEmojiPicker(context),
                          child: Container(
                            width: kElementHeight,
                            height: kElementHeight,
                            decoration: BoxDecoration(
                              color: kColorFill,
                              border: Border.all(color: kColorBlack.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(kBorderRadiusButton),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _emojiController.text.isNotEmpty ? _emojiController.text : '🏷️',
                              style: TextStyle(
                                fontSize: kFontSize + 4,
                                color: _emojiController.text.isEmpty ? kColorGrey.withValues(alpha: 0.3) : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: kSpace),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Category name',
                              errorText: _nameError,
                            ),
                            onChanged: (_) {
                              if (_nameError != null) setState(() => _nameError = null);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_allItems.isNotEmpty) ...[
                      const SizedBox(height: kSpace),
                      OutlinedButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text('Items (${_selectedItemIds.length} assigned)'),
                      ),
                      if (_expanded)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(top: kSpace),
                            child: ItemSelectionGrid(
                              items: _allItems,
                              selectedItemIds: _selectedItemIds,
                              onToggleItem: (id) {
                                setState(() {
                                  if (_selectedItemIds.contains(id)) {
                                    _selectedItemIds.remove(id);
                                  } else {
                                    _selectedItemIds.add(id);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: kSpace),
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
                    OutlinedButton(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(foregroundColor: kColorBlack),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

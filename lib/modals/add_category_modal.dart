import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/category_bloc.dart';
import '../blocs/inventory_bloc.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../theme.dart';
import '../widgets/emoji_picker_sheet.dart';
import '../widgets/item_selection_grid.dart';

class AddCategoryModal extends StatefulWidget {
  const AddCategoryModal({super.key});

  @override
  State<AddCategoryModal> createState() => _AddCategoryModalState();
}

class _AddCategoryModalState extends State<AddCategoryModal> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  final _selectedItemIds = <String>{};
  String? _nameError;
  List<Item> _allItems = [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() => _allItems = context.read<InventoryBloc>().state.allItems);
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

    final categoryId = const Uuid().v4();
    final emoji = _emojiController.text.trim();
    final category = Category(categoryId: categoryId, name: name, emoji: emoji.isNotEmpty ? emoji : null);
    context.read<CategoryBloc>().add(CreateCategory(category, itemIds: _selectedItemIds));
    Navigator.of(context).pop(true);
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
                child: Text('Assign items (${_selectedItemIds.length})'),
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
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

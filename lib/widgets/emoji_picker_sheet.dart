import 'dart:io';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:flutter/material.dart';
import '../theme.dart';

class EmojiPickerSheet extends StatefulWidget {
  final bool hasEmoji;
  final ValueChanged<String> onSelected;
  final VoidCallback onRemove;

  const EmojiPickerSheet({
    super.key,
    required this.hasEmoji,
    required this.onSelected,
    required this.onRemove,
  });

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  final _searchController = TextEditingController();
  List<ep.Emoji> _searchResults = [];
  bool _isSearching = false;

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    final results = await ep.EmojiPickerUtils().searchEmoji(
      query,
      ep.defaultEmojiSet,
      checkPlatformCompatibility: true,
    );
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _searchResults = results;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(kBorderRadius),
        topRight: Radius.circular(kBorderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: 420,
          child: Column(
        children: [
          // Remove button
          if (widget.hasEmoji)
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onRemove,
                  child: const Text('Remove emoji'),
                ),
              ),
            ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(kSpace),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search emoji...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: kSpace, right: kSpace / 2),
                  child: const Icon(Icons.search, size: kIconSize),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
            ),
          ),
          // Emoji grid or picker
          Expanded(
            child: _isSearching ? _buildSearchResults() : _buildPicker(),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No emojis found', style: TextStyle(color: kColorGrey, fontSize: kFontSize)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: kSpace),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: kSpace / 2,
        crossAxisSpacing: kSpace / 2,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => widget.onSelected(_searchResults[index].emoji),
          child: Center(
            child: Text(
              _searchResults[index].emoji,
              style: TextStyle(fontSize: 28 * (Platform.isIOS ? 1.2 : 1.0)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPicker() {
    return ep.EmojiPicker(
      onEmojiSelected: (category, emoji) => widget.onSelected(emoji.emoji),
      config: ep.Config(
        height: 300,
        checkPlatformCompatibility: true,
        emojiViewConfig: ep.EmojiViewConfig(
          columns: 8,
          emojiSizeMax: 28 * (Platform.isIOS ? 1.2 : 1.0),
          backgroundColor: kColorWhite,
        ),
        categoryViewConfig: const ep.CategoryViewConfig(
          backgroundColor: kColorWhite,
          indicatorColor: kColorBlack,
          iconColorSelected: kColorBlack,
          iconColor: kColorGrey,
          initCategory: ep.Category.OBJECTS,
          recentTabBehavior: ep.RecentTabBehavior.NONE,
        ),
        bottomActionBarConfig: const ep.BottomActionBarConfig(enabled: false),
        searchViewConfig: const ep.SearchViewConfig(
          backgroundColor: kColorWhite,
        ),
      ),
    );
  }
}

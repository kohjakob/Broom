import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/item.dart';
import '../theme.dart';
import 'fading_scroll_area.dart';
import 'item_photo.dart';

class ItemSelectionGrid extends StatefulWidget {
  final List<Item> items;
  final Set<String> selectedItemIds;
  final ValueChanged<String> onToggleItem;

  const ItemSelectionGrid({
    super.key,
    required this.items,
    required this.selectedItemIds,
    required this.onToggleItem,
  });

  @override
  State<ItemSelectionGrid> createState() => _ItemSelectionGridState();
}

class _ItemSelectionGridState extends State<ItemSelectionGrid> {
  String _searchQuery = '';

  List<Item> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    final query = _searchQuery.toLowerCase();
    return widget.items.where((item) => item.name.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: kSpace),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search items...',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: kSpace, right: kSpace / 2),
              child: Icon(Icons.search, size: kIconSize),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: kSpace),
        Expanded(child: FadingScrollArea(child: _buildGrid())),
      ],
    );
  }

  Widget _buildGrid() {
    final items = _filteredItems;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
        child: Text('No items found', style: TextStyle(color: kColorGrey)),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        crossAxisSpacing: kSpace,
        mainAxisSpacing: kSpace,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = widget.selectedItemIds.contains(item.itemId);
        return _buildItemTile(item, selected);
      },
    );
  }

  Widget _buildItemTile(Item item, bool selected) {
    return GestureDetector(
      onTap: () => widget.onToggleItem(item.itemId),
      child: Container(
        decoration: BoxDecoration(
          border: selected ? Border.all(color: kColorBlack, width: kBorderWidthActive) : kCardBorder,
          borderRadius: BorderRadius.circular(kBorderRadius),
          boxShadow: [kCardShadow],
          color: kColorFill,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kBorderRadius - (selected ? kBorderWidthActive : kBorderWidth)),
          child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(aspectRatio: 1.0, child: _buildThumbnail(item)),
                Expanded(
                  child: Container(
                    color: kColorFill,
                    padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(fontSize: kFontSize, fontWeight: FontWeight.w500, color: kColorBlack),
                        ),
                        Text(
                          item.ranking.toStringAsFixed(2),
                          style: GoogleFonts.dmMono(fontSize: kFontSize, color: ratingColor(item.ranking)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(kIconOverlayPadding, kIconOverlayPadding, kIconOverlayPadding, kIconOverlayPadding),
                  decoration: BoxDecoration(
                    color: kColorBlack,
                    borderRadius: BorderRadius.circular(kBorderRadiusButton),
                  ),
                  child: const Icon(Icons.check, size: kIconOverlaySize, color: kColorWhite),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(Item item) {
    final path = item.thumbnailImage ?? (item.images.isNotEmpty ? item.images.first : null);
    if (path != null) {
      return ItemPhoto(relativePath: path);
    }
    final letter = item.name.isNotEmpty ? item.name[0].toUpperCase() : '?';
    return Container(
      color: kColorFill,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(fontSize: kAvatarFontSize, fontWeight: FontWeight.bold, color: kColorGrey),
      ),
    );
  }
}

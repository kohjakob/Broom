import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/item.dart';
import '../theme.dart';
import 'grid_item.dart';

class InventoryGrid extends StatelessWidget {
  final List<Item> items;
  final ValueChanged<Item> onItemTap;
  final String? addToCategoryLabel;
  final VoidCallback? onAddToCategory;

  const InventoryGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.addToCategoryLabel,
    this.onAddToCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && addToCategoryLabel == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
          child: Text(
            'No items yet',
            textAlign: TextAlign.center,
            style: TextStyle(color: kColorGrey, fontSize: kFontSize),
          ),
        ),
      );
    }

    final hasAddTile = addToCategoryLabel != null && onAddToCategory != null;
    final totalCount = items.length + (hasAddTile ? 1 : 0);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(kSpace, 0, kSpace, kSpace),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        crossAxisSpacing: kSpace,
        mainAxisSpacing: kSpace,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (hasAddTile && index == 0) {
          return _buildAddTile();
        }
        final itemIndex = hasAddTile ? index - 1 : index;
        final item = items[itemIndex];
        return GridItem(
          item: item,
          onTap: () => onItemTap(item),
        );
      },
    );
  }

  Widget _buildAddTile() {
    return GestureDetector(
      onTap: onAddToCategory,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          border: kCardBorder,
          borderRadius: BorderRadius.circular(kBorderRadius),
          color: kColorFill,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: kIconSize * 1.5, color: kColorBlack),
            const SizedBox(height: kSpace / 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpace),
              child: Text(
                addToCategoryLabel!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.instrumentSans(
                  fontSize: kFontSize,
                  color: kColorBlack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

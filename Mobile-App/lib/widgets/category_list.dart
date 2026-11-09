import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category.dart';
import '../theme.dart';
import 'chip.dart';

class CategoryList extends StatelessWidget {
  final List<Category> categories;
  final Set<String> selectedCategoryIds;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onToggleCategory;
  final ValueChanged<String> onEditCategory;
  final VoidCallback? onAddCategory;

  const CategoryList({
    super.key,
    required this.categories,
    required this.selectedCategoryIds,
    required this.onSelectAll,
    required this.onToggleCategory,
    required this.onEditCategory,
    this.onAddCategory,
  });

  bool get _isAllSelected => selectedCategoryIds.isEmpty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kElementHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(kSpace, 0, kSpace, 0),
        children: [
          if (onAddCategory != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, kSpace, 0),
              child: GestureDetector(
                onTap: onAddCategory,
                child: Container(
                  height: kElementHeight,
                  padding: const EdgeInsets.fromLTRB(kSpace * 2, 0, kSpace * 2, 0),
                  decoration: BoxDecoration(
                    color: kColorWhite,
                    border: Border.all(color: kColorBlack, width: kBorderWidth),
                    borderRadius: BorderRadius.circular(kBorderRadiusPill),
                  ),
                  child: Center(
                    child: Text(
                      '+',
                      style: GoogleFonts.instrumentSans(
                        fontSize: kFontSize,
                        fontWeight: FontWeight.w700,
                        color: kColorBlack,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, kSpace, 0),
            child: AppChip(
              label: 'All',
              selected: _isAllSelected,
              onTap: onSelectAll,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, kSpace, 0),
            child: AppChip(
              label: 'Uncategorized',
              selected: selectedCategoryIds.contains(kUncategorizedId),
              onTap: () => onToggleCategory(kUncategorizedId),
            ),
          ),
          ...categories.map((category) {
            final isSelected = selectedCategoryIds.contains(category.categoryId);
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, kSpace, 0),
              child: AppChip(
                label: category.name,
                emoji: category.emoji,
                selected: isSelected,
                onTap: () => onToggleCategory(category.categoryId),
                onLongPress: () => onEditCategory(category.categoryId),
              ),
            );
          }),
        ],
      ),
    );
  }
}

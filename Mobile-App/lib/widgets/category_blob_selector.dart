import 'package:flutter/material.dart';
import '../models/category.dart';
import '../theme.dart';
import 'chip.dart';

class CategoryBlobSelector extends StatelessWidget {
  final List<Category> categories;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const CategoryBlobSelector({
    super.key,
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: kElementHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: kSpace),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final selected = selectedIds.contains(cat.categoryId);
          return AppChip(
            label: cat.name,
            emoji: cat.emoji,
            selected: selected,
            onTap: () => onToggle(cat.categoryId),
          );
        },
      ),
    );
  }
}

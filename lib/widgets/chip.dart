import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? emoji;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    required this.onTap,
    this.onLongPress,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: kElementHeight,
        padding: const EdgeInsets.fromLTRB(kSpace * 2, 0, kSpace * 2, 0),
        decoration: BoxDecoration(
          color: selected ? kColorBlack : kColorGreyLight,
          borderRadius: BorderRadius.circular(kBorderRadiusPill),
        ),
        child: Center(
          widthFactor: 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null && emoji!.isNotEmpty) ...[
                Text(emoji!, style: const TextStyle(fontSize: kFontSize)),
                const SizedBox(width: kSpace / 2),
              ],
              Text(
                label,
                style: GoogleFonts.instrumentSans(
                  fontSize: kFontSize,
                  color: selected ? kColorWhite : kColorGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

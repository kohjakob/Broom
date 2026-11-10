import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/item.dart';
import '../theme.dart';
import 'item_photo.dart';

class GridItem extends StatefulWidget {
  final Item item;
  final VoidCallback onTap;

  const GridItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<GridItem> createState() => _GridItemState();
}

class _GridItemState extends State<GridItem> with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          border: kCardBorder,
          borderRadius: BorderRadius.circular(kBorderRadius),
          boxShadow: [kCardShadow],
          color: kColorFill,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 1.0, child: _buildThumbnail()),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.item.name.isNotEmpty ? widget.item.name : 'Unnamed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: kFontSize,
                        fontWeight: FontWeight.w500,
                        color: kColorBlack,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: kSpace / 2),
                    Text(
                      widget.item.ranking.toStringAsFixed(2),
                      style: GoogleFonts.dmMono(
                        fontSize: kFontSize,
                        color: ratingColor(widget.item.ranking),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final path = widget.item.thumbnailImage ?? (widget.item.images.isNotEmpty ? widget.item.images.first : null);
    final hasPhoto = path != null && widget.item.images.isNotEmpty;

    const lighter = Color(0xFFFFFCF8);  // very light warm cream
    const darker = Color(0xFFF7F0E8);   // slightly deeper cream

    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated gradient background
        AnimatedBuilder(
          animation: _breathController,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_breathController.value);
            final angle = -math.pi / 6 + t * math.pi / 3;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(math.cos(angle), math.sin(angle)),
                  end: Alignment(-math.cos(angle), -math.sin(angle)),
                  colors: [lighter, darker],
                ),
              ),
            );
          },
        ),
        // Photo or avatar on top
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: hasPhoto
                ? ItemPhoto(key: ValueKey(path), relativePath: path)
                : _buildAvatar(),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final letter = widget.item.name.isNotEmpty ? widget.item.name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontSize: kAvatarFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

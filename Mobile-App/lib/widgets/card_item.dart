import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/item.dart';
import '../theme.dart';
import 'item_photo.dart';

class CardItem extends StatefulWidget {
  final Item item;
  final VoidCallback? onTap;

  const CardItem({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  State<CardItem> createState() => _CardItemState();
}

class _CardItemState extends State<CardItem> with SingleTickerProviderStateMixin {
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
    const lighter = Color(0xFFFFFCF8);  // very light warm cream
    const darker = Color(0xFFF7F0E8);   // slightly deeper cream

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kBorderRadius),
          boxShadow: [kCardShadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kBorderRadius),
          child: Stack(
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
              // Photo or avatar
              _buildForeground(),
              // Frosted glass info bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.7),
                      padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name.isNotEmpty ? widget.item.name : 'Unnamed',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.playfairDisplay(
                                color: kColorBlack,
                                fontSize: kFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            widget.item.ranking.toStringAsFixed(2),
                            style: GoogleFonts.dmMono(
                              color: ratingColor(widget.item.ranking),
                              fontSize: kFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForeground() {
    final path = widget.item.thumbnailImage ?? (widget.item.images.isNotEmpty ? widget.item.images.first : null);
    if (path != null && widget.item.images.isNotEmpty) {
      return ItemPhoto(relativePath: path);
    }
    // First-letter avatar
    final letter = widget.item.name.isNotEmpty ? widget.item.name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontSize: kAvatarFontSizeLarge,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

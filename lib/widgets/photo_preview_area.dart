import 'package:flutter/material.dart';
import '../theme.dart';
import 'item_photo.dart';

class PhotoPreviewArea extends StatelessWidget {
  final List<String> imagePaths;
  final String? thumbnailPath;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onSetThumbnail;

  const PhotoPreviewArea({
    super.key,
    required this.imagePaths,
    required this.thumbnailPath,
    required this.onRemove,
    required this.onSetThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: kThumbnailSize,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          final path = imagePaths[index];
          final isThumbnail = path == thumbnailPath;
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, kSpace, 0),
            child: SizedBox(
              width: kThumbnailSize,
              height: kThumbnailSize,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: isThumbnail
                            ? Border.all(color: kColorBlack, width: kBorderWidthActive)
                            : kCardBorder,
                        borderRadius: BorderRadius.circular(kBorderRadiusButton),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(kBorderRadiusButton - kBorderWidthActive),
                        child: ItemPhoto(relativePath: path),
                      ),
                    ),
                  ),
                  // Delete X — black square, top-right
                  kIconOverlay(icon: Icons.close, onTap: () => onRemove(index)),
                  // Star — bottom-left, same style as X overlay
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: GestureDetector(
                      onTap: () => onSetThumbnail(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kColorBlack,
                          borderRadius: BorderRadius.circular(kBorderRadiusButton),
                        ),
                        padding: const EdgeInsets.all(kIconOverlayPadding),
                        child: Icon(
                          Icons.star,
                          size: kIconOverlaySize,
                          color: isThumbnail ? kColorWhite : const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class WEAImage extends StatelessWidget {
  const WEAImage({
    super.key,
    required this.assetPath,
    this.aspectRatio = 16 / 9,
    this.overlay = false,
    this.fit = BoxFit.cover,
  });
  final String assetPath;
  final double aspectRatio;
  final bool overlay;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            fit: fit,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: WEAColors.elevated,
              child: Center(
                child: Icon(Icons.image_outlined, color: WEAColors.mutedText),
              ),
            ),
          ),
          if (overlay) const ColoredBox(color: Color(0x88050505)),
        ],
      ),
    ),
  );
}

class WEAHeroImage extends WEAImage {
  const WEAHeroImage({
    super.key,
    required super.assetPath,
    super.aspectRatio = 2,
    super.overlay = true,
  });
}

class WEAImageCard extends WEAImage {
  const WEAImageCard({
    super.key,
    required super.assetPath,
    super.aspectRatio = 4 / 3,
    super.overlay = false,
  });
}

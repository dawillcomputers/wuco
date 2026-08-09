import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// WUCO Executive Academy brand artwork.
///
/// The full lockup carries the wordmark inside the image, so it only stays
/// legible at generous heights (footers, splash surfaces). The emblem is the
/// globe alone and reads cleanly at navigation sizes, where the wordmark is set
/// in type beside it instead.
abstract final class WEABrandAssets {
  static const lockup = 'assets/brand/wuco_academy_logo.png';
  static const lockupReversed = 'assets/brand/wuco_academy_logo_reversed.png';
  static const emblem = 'assets/brand/wuco_academy_emblem.png';
  static const emblemReversed = 'assets/brand/wuco_academy_emblem_reversed.png';

  static const name = 'WUCO Executive Academy';
}

/// Compact brand signature: globe emblem plus typeset wordmark.
class WEABrand extends StatelessWidget {
  const WEABrand({super.key, this.compact = false, this.onDark = false});

  final bool compact;

  /// Switches to the reversed artwork and light type for navy grounds.
  final bool onDark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Boxed rather than sized by height: the desktop header is tight at the
      // 1440px breakpoint, so the mark keeps a fixed horizontal footprint.
      SizedBox(
        width: 32,
        height: 32,
        child: Image.asset(
          onDark ? WEABrandAssets.emblemReversed : WEABrandAssets.emblem,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          semanticLabel: WEABrandAssets.name,
        ),
      ),
      const SizedBox(width: 10),
      if (!compact)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WUCO EXECUTIVE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: onDark ? WEAColors.offWhite : WEAColors.navy,
                letterSpacing: 1.35,
              ),
            ),
            Text(
              'ACADEMY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: onDark ? WEAColors.accentSoft : WEAColors.accent,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
    ],
  );
}

/// The complete logo lockup, for surfaces with room to show it properly.
class WEABrandLockup extends StatelessWidget {
  const WEABrandLockup({super.key, this.height = 120, this.onDark = false});

  final double height;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Image.asset(
    onDark ? WEABrandAssets.lockupReversed : WEABrandAssets.lockup,
    height: height,
    filterQuality: FilterQuality.medium,
    semanticLabel: WEABrandAssets.name,
  );
}

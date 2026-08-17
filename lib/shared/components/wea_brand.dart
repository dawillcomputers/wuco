import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// Makes brand artwork the way back to the home page.
///
/// Applied wherever the logo sits in a header, app bar or sidebar, because a
/// logo in navigation is universally taken to be a link home and a visitor who
/// clicks one and gets nothing concludes the site is broken.
///
/// Deliberately not applied where the mark is a statement of origin rather
/// than a control: on a certificate, in a credential card, or on the loading
/// screen, where there is nowhere to go yet.
class _BrandHomeLink extends StatelessWidget {
  const _BrandHomeLink({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Semantics(
      link: true,
      button: true,
      label: '${WEABrandAssets.name} — home',
      child: InkWell(
        onTap: () => context.go('/'),
        borderRadius: BorderRadius.circular(8),
        // A pointer cursor is what tells a visitor it is a link at all.
        mouseCursor: SystemMouseCursors.click,
        child: child,
      ),
    );
  }
}

/// Compact brand signature: globe emblem plus typeset wordmark.
class WEABrand extends StatelessWidget {
  const WEABrand({
    super.key,
    this.compact = false,
    this.onDark = false,
    this.linkToHome = true,
  });

  final bool compact;

  /// Switches to the reversed artwork and light type for navy grounds.
  final bool onDark;

  /// Whether tapping returns to the home page. On by default: this compact
  /// signature only appears in navigation.
  final bool linkToHome;

  @override
  Widget build(BuildContext context) => _BrandHomeLink(
    enabled: linkToHome,
    child: Row(
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
    ),
  );
}

/// The complete logo lockup, for surfaces with room to show it properly.
class WEABrandLockup extends StatelessWidget {
  const WEABrandLockup({
    super.key,
    this.height = 120,
    this.onDark = false,
    this.linkToHome = true,
  });

  final double height;
  final bool onDark;

  /// Whether tapping returns to the home page.
  ///
  /// On by default, because a logo is universally taken to be the way home and
  /// a visitor who clicks one and gets nothing concludes the site is broken.
  /// Opted out only where the mark is a statement of origin rather than a
  /// control: on a certificate, on a credential card, and on the loading
  /// screen — where there is also no router to navigate with yet.
  final bool linkToHome;

  @override
  Widget build(BuildContext context) => _BrandHomeLink(
    enabled: linkToHome,
    child: Image.asset(
      onDark ? WEABrandAssets.lockupReversed : WEABrandAssets.lockup,
      height: height,
      filterQuality: FilterQuality.medium,
      semanticLabel: WEABrandAssets.name,
    ),
  );
}

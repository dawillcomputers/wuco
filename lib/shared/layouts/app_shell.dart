import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../components/wea_brand.dart';
import '../components/wea_components.dart';
import '../widgets/wea_selectable.dart';

class WEAAppShell extends StatelessWidget {
  const WEAAppShell({super.key, required this.child});

  final Widget child;

  static const links = [
    ('Home', '/'),
    ('Programmes', '/programmes'),
    ('Faculty', '/faculty'),
    ('About', '/about'),
    ('Admissions', '/admissions'),
    ('Research', '/research'),
    ('Events', '/events'),
    ('Professional Network', '/professional-network'),
  ];

  /// Below this the navigation collapses to the drawer. Laptops keep the full
  /// menu; only phones and small tablets get the hamburger.
  static const navigationBreakpoint = 1100.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showFullNavigation = width >= navigationBreakpoint;
    final currentPath = GoRouterState.of(context).uri.path;
    return Scaffold(
      backgroundColor: WEAColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Navy so the header reads as one surface with the hero beneath it,
        // parted only by the hairline below.
        backgroundColor: WEAColors.navy,
        surfaceTintColor: Colors.transparent,
        foregroundColor: WEAColors.offWhite,
        elevation: 0,
        toolbarHeight: 92,
        titleSpacing: width < 600 ? 20 : 32,
        title: WEABrandLockup(
          height: width < 600
              ? 54
              : width < 1280
              ? 58
              : 64,
          onDark: true,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: WEAColors.offWhite.withValues(alpha: .16),
          ),
        ),
        actions: showFullNavigation
            ? [
                _DesktopNavigation(currentPath: currentPath),
                const SizedBox(width: 18),
              ]
            : [
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Open navigation',
                    icon: const Icon(Icons.menu_rounded, size: 22),
                    color: WEAColors.offWhite,
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ),
                SizedBox(width: width < 600 ? 8 : 20),
              ],
      ),
      endDrawer: _MobileNavigation(currentPath: currentPath),
      body: WEASelectable(child: child),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    // Between the navigation breakpoint and a comfortable desktop the full menu
    // only fits if the links tighten up.
    final dense = MediaQuery.sizeOf(context).width < 1280;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final link in WEAAppShell.links)
          _NavigationLink(
            label: link.$1,
            path: link.$2,
            active: currentPath == link.$2,
            dense: dense,
          ),
        const SizedBox(width: 8),
        _NavigationLink(
          label: 'Login',
          path: '/login',
          active: currentPath == '/login',
          dense: dense,
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 36,
          child: WEAOutlinedButton(
            label: 'APPLY',
            onPressed: () => context.go('/apply'),
            compact: true,
            onDark: true,
          ),
        ),
      ],
    );
  }
}

class _NavigationLink extends StatefulWidget {
  const _NavigationLink({
    required this.label,
    required this.path,
    required this.active,
    this.dense = false,
  });

  final String label;
  final String path;
  final bool active;
  final bool dense;

  @override
  State<_NavigationLink> createState() => _NavigationLinkState();
}

class _NavigationLinkState extends State<_NavigationLink> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final emphasized = _hovering || widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: TextButton(
        onPressed: () => context.go(widget.path),
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? 5 : 8,
            vertical: 12,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: emphasized
                ? WEAColors.accentSoft
                : WEAColors.offWhite.withValues(alpha: .78),
            letterSpacing: widget.dense ? .35 : .65,
            fontWeight: FontWeight.w500,
          ),
          child: Text(widget.label.toUpperCase()),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) => Drawer(
    width: 330,
    backgroundColor: WEAColors.navy,
    surfaceTintColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WEABrandLockup(height: 64, onDark: true),
                IconButton(
                  tooltip: 'Close navigation',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                  color: WEAColors.offWhite,
                ),
              ],
            ),
            const SizedBox(height: 26),
            Container(
              height: 1,
              color: WEAColors.offWhite.withValues(alpha: .16),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  for (final link in WEAAppShell.links)
                    _MobileNavigationLink(
                      label: link.$1,
                      path: link.$2,
                      active: currentPath == link.$2,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 1,
                      color: WEAColors.offWhite.withValues(alpha: .16),
                    ),
                  ),
                  _MobileNavigationLink(
                    label: 'Login',
                    path: '/login',
                    active: currentPath == '/login',
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: WEAOutlinedButton(
                label: 'APPLY',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/apply');
                },
                onDark: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileNavigationLink extends StatelessWidget {
  const _MobileNavigationLink({
    required this.label,
    required this.path,
    required this.active,
  });

  final String label;
  final String path;
  final bool active;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: active
            ? WEAColors.accentSoft
            : WEAColors.offWhite.withValues(alpha: .78),
        letterSpacing: 1,
      ),
    ),
    trailing: active
        ? const Icon(Icons.arrow_outward, color: WEAColors.accentSoft, size: 17)
        : null,
    onTap: () {
      Navigator.of(context).pop();
      context.go(path);
    },
  );
}

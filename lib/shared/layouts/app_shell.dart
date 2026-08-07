import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../components/wea_brand.dart';
import '../components/wea_components.dart';

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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showFullNavigation = width >= 1440;
    final currentPath = GoRouterState.of(context).uri.path;
    return Scaffold(
      backgroundColor: WEAColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: WEAColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        titleSpacing: width < 600 ? 20 : 32,
        title: WEABrand(compact: !showFullNavigation),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WEAColors.border),
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
                    icon: const Icon(Icons.menu_rounded, size: 21),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ),
                SizedBox(width: width < 600 ? 8 : 20),
              ],
      ),
      endDrawer: _MobileNavigation(currentPath: currentPath),
      body: child,
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final link in WEAAppShell.links)
        _NavigationLink(
          label: link.$1,
          path: link.$2,
          active: currentPath == link.$2,
        ),
      const SizedBox(width: 8),
      _NavigationLink(
        label: 'Login',
        path: '/login',
        active: currentPath == '/login',
      ),
      const SizedBox(width: 12),
      SizedBox(
        height: 36,
        child: WEAOutlinedButton(
          label: 'APPLY',
          onPressed: () => context.go('/apply'),
          compact: true,
        ),
      ),
    ],
  );
}

class _NavigationLink extends StatefulWidget {
  const _NavigationLink({
    required this.label,
    required this.path,
    required this.active,
  });

  final String label;
  final String path;
  final bool active;

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: emphasized ? WEAColors.gold : WEAColors.secondaryText,
            letterSpacing: .65,
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
    backgroundColor: WEAColors.deepBlack,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const WEABrand(),
                IconButton(
                  tooltip: 'Close navigation',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Divider(height: 1),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
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
        color: active ? WEAColors.gold : WEAColors.secondaryText,
        letterSpacing: 1,
      ),
    ),
    trailing: active
        ? const Icon(Icons.arrow_outward, color: WEAColors.gold, size: 17)
        : null,
    onTap: () {
      Navigator.of(context).pop();
      context.go(path);
    },
  );
}

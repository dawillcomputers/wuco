import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../components/wea_brand.dart';

class WEAAppShell extends StatelessWidget {
  const WEAAppShell({super.key, required this.child});
  final Widget child;
  static const _links = [
    ('About', '/about'),
    ('Programmes', '/programmes'),
    ('Admissions', '/admissions'),
    ('Events', '/events'),
  ];

  @override
  Widget build(BuildContext context) {
    final breakpoint = WEAResponsive.breakpointOf(
      MediaQuery.sizeOf(context).width,
    );
    final useCompactNavigation =
        breakpoint == WEABreakpoint.mobile ||
        breakpoint == WEABreakpoint.tablet;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: WEAColors.background,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 76,
        title: WEABrand(compact: useCompactNavigation),
        actions: [
          if (useCompactNavigation)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Open navigation',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.menu),
              ),
            )
          else
            Row(
              children: [
                for (final link in _links)
                  TextButton(
                    onPressed: () => context.go(link.$2),
                    child: Text(link.$1),
                  ),
                const SizedBox(width: 16),
              ],
            ),
        ],
      ),
      endDrawer: Drawer(
        backgroundColor: WEAColors.surface,
        child: SafeArea(
          child: ListView(
            children: [
              const Padding(padding: EdgeInsets.all(20), child: WEABrand()),
              const Divider(),
              for (final link in _links)
                ListTile(
                  title: Text(link.$1),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(link.$2);
                  },
                ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(child: child),
    );
  }
}

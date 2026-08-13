import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/wea_selectable.dart';
import 'learner_header.dart';
import 'learner_sidebar.dart';

/// Chrome shared by every learner page.
///
/// One layout with three modes rather than three layouts: a persistent sidebar
/// on desktop, an icon rail on tablet, and a drawer on mobile.
class LearnerShell extends ConsumerWidget {
  const LearnerShell({super.key, required this.child});

  final Widget child;

  /// At or above this the sidebar is fully expanded.
  static const expandedBreakpoint = 1200.0;

  /// Between this and [expandedBreakpoint] the sidebar becomes an icon rail;
  /// below it, navigation moves into a drawer. Set below portrait-tablet width
  /// so a tablet keeps persistent navigation and only phones get the drawer.
  static const railBreakpoint = 760.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final location = GoRouterState.of(context).uri.path;

    final useDrawer = width < railBreakpoint;
    final collapsed = width < expandedBreakpoint;

    return Scaffold(
      // Deliberately unkeyed: a GlobalKey minted here would be a new identity
      // on every rebuild, tearing down the Scaffold — and its open drawer —
      // whenever a provider the header watches emits.
      backgroundColor: WEAColors.secondaryBackground,
      drawer: useDrawer
          ? Drawer(
              width: LearnerSidebar.expandedWidth,
              backgroundColor: WEAColors.navy,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: Builder(
                builder: (drawerContext) => LearnerSidebar(
                  location: location,
                  onNavigate: () => Navigator.of(drawerContext).pop(),
                ),
              ),
            )
          : null,
      body: WEASelectable(
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!useDrawer)
                LearnerSidebar(location: location, collapsed: collapsed),
              Expanded(
                child: Column(
                  children: [
                    Builder(
                      builder: (headerContext) => LearnerHeader(
                        location: location,
                        showMenuButton: useDrawer,
                        showBrand: useDrawer,
                        onMenuPressed: () =>
                            Scaffold.of(headerContext).openDrawer(),
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard page body: scrolls, constrains width and applies page padding, so
/// individual pages do not each re-invent it.
class LearnerPageBody extends StatelessWidget {
  const LearnerPageBody({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.scrollable = true,
  });

  final Widget child;
  final double maxWidth;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? 16.0 : 32.0;

    // Centred rather than left-aligned: on an ultra-wide monitor the content
    // pane is far wider than the readable maximum, and hugging the sidebar
    // leaves the page visibly lopsided.
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 48),
          child: child,
        ),
      ),
    );

    return scrollable ? SingleChildScrollView(child: content) : content;
  }
}

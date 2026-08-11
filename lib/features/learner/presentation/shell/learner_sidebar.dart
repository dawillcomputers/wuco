import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/components/wea_brand.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../application/learner_providers.dart';
import 'learner_nav.dart';

/// Persistent (or rail) navigation for the learner area.
class LearnerSidebar extends ConsumerWidget {
  const LearnerSidebar({
    super.key,
    required this.location,
    this.collapsed = false,
    this.onNavigate,
  });

  final String location;

  /// Icon-only rail, used on tablet widths.
  final bool collapsed;

  /// Called after a destination is chosen, so the drawer can close itself.
  final VoidCallback? onNavigate;

  static const expandedWidth = 268.0;
  static const collapsedWidth = 80.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);

    return Container(
      width: collapsed ? collapsedWidth : expandedWidth,
      decoration: const BoxDecoration(
        color: WEAColors.navy,
        border: Border(
          right: BorderSide(color: WEAColors.navyDeep),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                collapsed ? 12 : WEAInsets.lg,
                WEAInsets.lg,
                collapsed ? 12 : WEAInsets.lg,
                WEAInsets.md,
              ),
              child: InkWell(
                onTap: () => context.go('/'),
                child: collapsed
                    ? const WEABrandLockup(height: 44, onDark: true)
                    : const WEABrandLockup(height: 78, onDark: true),
              ),
            ),
            Container(
              height: 1,
              margin: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 18),
              color: WEAColors.offWhite.withValues(alpha: .14),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: WEAInsets.md),
                children: [
                  for (final group in LearnerNavigation.groups) ...[
                    if (!collapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          WEAInsets.lg,
                          WEAInsets.md,
                          WEAInsets.lg,
                          WEAInsets.xs,
                        ),
                        child: Text(
                          group.title.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: WEAColors.offWhite.withValues(alpha: .45),
                                letterSpacing: 1.4,
                              ),
                        ),
                      )
                    else
                      const SizedBox(height: WEAInsets.sm),
                    for (final item in group.items)
                      _SidebarTile(
                        item: item,
                        active: item.isActive(location),
                        collapsed: collapsed,
                        badgeCount: item.route == '/learner/notifications'
                            ? unread
                            : 0,
                        onTap: () {
                          onNavigate?.call();
                          context.go(item.route);
                        },
                      ),
                  ],
                ],
              ),
            ),
            Container(
              height: 1,
              margin: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 18),
              color: WEAColors.offWhite.withValues(alpha: .14),
            ),
            _SidebarTile(
              item: const LearnerNavItem(
                label: 'Log out',
                route: '__logout__',
                icon: Icons.logout_outlined,
              ),
              active: false,
              collapsed: collapsed,
              onTap: () => _confirmLogout(context, ref),
            ),
            const SizedBox(height: WEAInsets.sm),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'Are you sure you want to sign out of your WEA account?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('SIGN OUT'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await ref.read(authControllerProvider.notifier).signOut();
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.item,
    required this.active,
    required this.collapsed,
    required this.onTap,
    this.badgeCount = 0,
  });

  final LearnerNavItem item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final foreground = active
        ? WEAColors.offWhite
        : WEAColors.offWhite.withValues(alpha: _hovering ? .92 : .70);

    final tile = Semantics(
      selected: active,
      button: true,
      label: widget.item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        // InkWell rather than GestureDetector: navigation must be reachable by
        // keyboard on the web, and focus needs to be visible. Focus reuses the
        // hover treatment so the highlight is the same affordance.
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _hovering = focused),
          borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 10 : 12,
              vertical: 2,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 0 : 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              // Active state carries a fill, a left accent and an icon change,
              // so it never depends on colour alone.
              color: active
                  ? WEAColors.accent.withValues(alpha: .22)
                  : _hovering
                  ? WEAColors.offWhite.withValues(alpha: .06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
              border: Border(
                left: BorderSide(
                  color: active ? WEAColors.accentSoft : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: widget.collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(widget.item.icon, size: 20, color: foreground),
                if (!widget.collapsed) ...[
                  const SizedBox(width: WEAInsets.sm),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
                if (widget.badgeCount > 0)
                  Container(
                    margin: EdgeInsets.only(left: widget.collapsed ? 2 : 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: WEAColors.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${widget.badgeCount}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!widget.collapsed) return tile;
    return Tooltip(message: widget.item.label, child: tile);
  }
}

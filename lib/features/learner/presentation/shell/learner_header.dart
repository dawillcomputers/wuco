import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/components/wea_brand.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../application/learner_providers.dart';
import 'learner_nav.dart';
import 'learner_search_delegate.dart';

/// Top bar of the learner area: search, notifications and identity.
class LearnerHeader extends ConsumerWidget {
  const LearnerHeader({
    super.key,
    required this.location,
    required this.showMenuButton,
    required this.showBrand,
    this.onMenuPressed,
  });

  final String location;
  final bool showMenuButton;
  final bool showBrand;
  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 620;

    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: WEAColors.background,
        border: Border(bottom: BorderSide(color: WEAColors.border)),
      ),
      // Tightened on phones: the full lockup plus four controls does not fit a
      // 360px header at desktop padding.
      padding: EdgeInsets.symmetric(
        horizontal: compact ? WEAInsets.xxs : WEAInsets.lg,
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              tooltip: 'Open navigation',
              visualDensity: compact ? VisualDensity.compact : null,
              onPressed: onMenuPressed,
              icon: const Icon(Icons.menu_rounded),
            ),
          if (showBrand) ...[
            // The emblem alone at phone widths; the drawer carries the full
            // lockup, so brand presence is not lost.
            compact
                ? const WEABrand(compact: true)
                : const WEABrandLockup(height: 46),
            const SizedBox(width: WEAInsets.xs),
          ],
          Expanded(
            child: Text(
              LearnerNavigation.titleFor(location),
              style: compact
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (!compact) ...[
            SizedBox(
              width: 300,
              child: _SearchField(
                onTap: () => showLearnerSearch(context, ref),
              ),
            ),
            const SizedBox(width: WEAInsets.sm),
          ] else
            IconButton(
              tooltip: 'Search',
              visualDensity: VisualDensity.compact,
              onPressed: () => showLearnerSearch(context, ref),
              icon: const Icon(Icons.search),
            ),

          _NotificationButton(unread: unread, compact: compact),

          if (!compact) ...[
            const SizedBox(width: WEAInsets.sm),
            Container(width: 1, height: 32, color: WEAColors.border),
            const SizedBox(width: WEAInsets.sm),
            _ProfileChip(
              initials: profile?.initials ?? '—',
              name: profile?.fullName ?? '',
            ),
          ] else
            IconButton(
              tooltip: 'Profile',
              visualDensity: VisualDensity.compact,
              onPressed: () => context.go('/learner/profile'),
              icon: CircleAvatar(
                radius: 14,
                backgroundColor: WEAColors.accent,
                foregroundColor: Colors.white,
                child: Text(
                  profile?.initials ?? '—',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Search programmes, courses and lessons',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: WEAInsets.sm),
        decoration: BoxDecoration(
          color: WEAColors.surface,
          border: Border.all(color: WEAColors.border),
          borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: WEAColors.mutedText),
            const SizedBox(width: WEAInsets.xs),
            Expanded(
              child: Text(
                'Search your learning',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WEAColors.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unread, this.compact = false});
  final int unread;
  final bool compact;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        tooltip: unread > 0
            ? '$unread unread notifications'
            : 'Notifications',
        visualDensity: compact ? VisualDensity.compact : null,
        onPressed: () => context.go('/learner/notifications'),
        icon: const Icon(Icons.notifications_none),
      ),
      if (unread > 0)
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: WEAColors.error,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$unread',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ),
    ],
  );
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.initials, required this.name});

  final String initials;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.go('/learner/profile'),
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WEAInsets.xs,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: WEAColors.accent,
              foregroundColor: Colors.white,
              child: Text(
                initials,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: WEAInsets.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                Text(
                  'Learner',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: WEAColors.mutedText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

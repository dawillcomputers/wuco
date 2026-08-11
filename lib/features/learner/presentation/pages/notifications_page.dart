import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_enums.dart';
import '../../domain/learner_records.dart';
import '../shell/learner_shell.dart';
import '../widgets/learner_lists.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// Everything WEA has told the learner, filterable by category.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  /// Null means every category.
  NotificationCategory? _category;
  var _unreadOnly = false;

  List<LearnerNotification> _apply(List<LearnerNotification> all) => [
    for (final item in all)
      if ((_category == null || item.category == _category) &&
          (!_unreadOnly || !item.read))
        item,
  ];

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return LearnerPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LearnerPageHeader(
            eyebrow: 'Notifications',
            title: 'Your notifications',
            description: unread == 0
                ? 'You are up to date.'
                : 'You have $unread unread '
                      '${unread == 1 ? 'notification' : 'notifications'}.',
            trailing: OutlinedButton(
              onPressed: unread == 0
                  ? null
                  : () => ref
                        .read(learnerActionsProvider)
                        .markAllNotificationsRead(),
              child: const Text('MARK ALL AS READ'),
            ),
          ),
          _CategoryFilter(
            selected: _category,
            unreadOnly: _unreadOnly,
            onCategory: (value) => setState(() => _category = value),
            onUnreadOnly: (value) => setState(() => _unreadOnly = value),
          ),
          const SizedBox(height: WEAInsets.lg),
          LearnerAsync(
            value: notifications,
            onRetry: () => ref.invalidate(notificationsProvider),
            loading: const LearnerCardSkeleton(count: 4, height: 90),
            data: (all) {
              final items = _apply(all);
              if (all.isEmpty) {
                return const LearnerEmptyState(
                  icon: Icons.notifications_none,
                  title: 'No notifications',
                  message:
                      'Results, certificates and programme announcements will '
                      'appear here.',
                );
              }
              if (items.isEmpty) {
                return LearnerEmptyState(
                  icon: Icons.filter_alt_outlined,
                  title: 'Nothing in this view',
                  message:
                      'No notifications match the current filter. Clear it to '
                      'see everything.',
                  actionLabel: 'CLEAR FILTER',
                  onAction: () => setState(() {
                    _category = null;
                    _unreadOnly = false;
                  }),
                );
              }
              return LearnerCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(WEAInsets.radius),
                  child: Column(
                    children: [
                      for (final notification in items)
                        LearnerNotificationTile(
                          notification: notification,
                          onRead: (id) => ref
                              .read(learnerActionsProvider)
                              .markNotificationRead(id),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selected,
    required this.unreadOnly,
    required this.onCategory,
    required this.onUnreadOnly,
  });

  final NotificationCategory? selected;
  final bool unreadOnly;
  final ValueChanged<NotificationCategory?> onCategory;
  final ValueChanged<bool> onUnreadOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget chip({
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) => ChoiceChip(
      label: Text(label),
      selected: active,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: WEAColors.accent.withValues(alpha: .12),
      side: BorderSide(
        color: active ? WEAColors.accent : WEAColors.border,
      ),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: active ? WEAColors.accentDeep : WEAColors.secondaryText,
      ),
    );

    return Wrap(
      spacing: WEAInsets.xs,
      runSpacing: WEAInsets.xs,
      children: [
        chip(
          label: 'All',
          active: selected == null && !unreadOnly,
          onTap: () {
            onCategory(null);
            onUnreadOnly(false);
          },
        ),
        chip(
          label: 'Unread',
          active: unreadOnly,
          onTap: () => onUnreadOnly(!unreadOnly),
        ),
        for (final category in NotificationCategory.values)
          chip(
            label: category.label,
            active: selected == category,
            onTap: () => onCategory(selected == category ? null : category),
          ),
      ],
    );
  }
}

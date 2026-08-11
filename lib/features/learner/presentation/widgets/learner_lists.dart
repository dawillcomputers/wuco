import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/learner_enums.dart';
import '../../domain/learner_records.dart';
import 'learner_states.dart';

String formatShortDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatRelative(DateTime moment) {
  final difference = DateTime.now().difference(moment);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return formatShortDate(moment);
}

IconData iconForActivity(ActivityType type) => switch (type) {
  ActivityType.courseAccessed => Icons.menu_book_outlined,
  ActivityType.lessonCompleted => Icons.check_circle_outline,
  ActivityType.assessmentSubmitted => Icons.assignment_turned_in_outlined,
  ActivityType.certificateEarned => Icons.workspace_premium_outlined,
  ActivityType.cpdUpdated => Icons.trending_up_outlined,
  ActivityType.programmeEnrolled => Icons.school_outlined,
};

IconData iconForNotification(NotificationCategory category) =>
    switch (category) {
      NotificationCategory.course => Icons.menu_book_outlined,
      NotificationCategory.assessment => Icons.assignment_outlined,
      NotificationCategory.result => Icons.grading_outlined,
      NotificationCategory.certificate => Icons.workspace_premium_outlined,
      NotificationCategory.programme => Icons.school_outlined,
      NotificationCategory.system => Icons.info_outline,
      NotificationCategory.event => Icons.event_outlined,
      NotificationCategory.professionalNetwork => Icons.groups_outlined,
      NotificationCategory.aiMentor => Icons.auto_awesome_outlined,
    };

IconData iconForUpcoming(UpcomingKind kind) => switch (kind) {
  UpcomingKind.assessment => Icons.assignment_outlined,
  UpcomingKind.liveClass => Icons.videocam_outlined,
  UpcomingKind.milestone => Icons.flag_outlined,
  UpcomingKind.certificate => Icons.workspace_premium_outlined,
  UpcomingKind.event => Icons.event_outlined,
};

/// Vertical timeline of what the learner has done recently.
class LearnerActivityTimeline extends StatelessWidget {
  const LearnerActivityTimeline({super.key, required this.items});

  final List<LearningActivity> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LearnerCard(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: WEAColors.accent.withValues(alpha: .10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconForActivity(items[index].type),
                          size: 15,
                          color: WEAColors.accent,
                        ),
                      ),
                      if (index != items.length - 1)
                        Expanded(
                          child: Container(width: 1, color: WEAColors.border),
                        ),
                    ],
                  ),
                  const SizedBox(width: WEAInsets.sm),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: index == items.length - 1 ? 0 : WEAInsets.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[index].type.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: WEAColors.mutedText,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            items[index].title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: WEAColors.primaryText,
                            ),
                          ),
                          Text(
                            '${items[index].detail} · '
                            '${formatRelative(items[index].occurredAt)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A single upcoming commitment. Stated plainly rather than urgently.
class LearnerUpcomingTile extends StatelessWidget {
  const LearnerUpcomingTile({super.key, required this.item});

  final UpcomingActivity item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = item.daysAway < 0;
    return InkWell(
      onTap: item.actionRoute == null
          ? null
          : () => context.go(item.actionRoute!),
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WEAInsets.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: WEAColors.surfaceMuted,
                borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
              ),
              child: Icon(
                iconForUpcoming(item.kind),
                size: 17,
                color: overdue ? WEAColors.warning : WEAColors.accent,
              ),
            ),
            const SizedBox(width: WEAInsets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.relativeLabel.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: overdue ? WEAColors.warning : WEAColors.mutedText,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(item.title, style: theme.textTheme.bodyLarge),
                  Text(item.context, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notification row. Unread is signalled by weight, a dot and a tinted ground,
/// never by colour alone.
class LearnerNotificationTile extends StatelessWidget {
  const LearnerNotificationTile({
    super.key,
    required this.notification,
    required this.onRead,
  });

  final LearnerNotification notification;
  final ValueChanged<String> onRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.read;

    return Semantics(
      label: unread ? 'Unread notification' : 'Notification',
      child: InkWell(
        onTap: () {
          if (unread) onRead(notification.id);
          final route = notification.actionRoute;
          if (route != null) context.go(route);
        },
        child: Container(
          padding: const EdgeInsets.all(WEAInsets.md),
          decoration: BoxDecoration(
            color: unread ? WEAColors.surfaceMuted : WEAColors.card,
            border: const Border(
              bottom: BorderSide(color: WEAColors.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                iconForNotification(notification.category),
                size: 19,
                color: unread ? WEAColors.accent : WEAColors.mutedText,
              ),
              const SizedBox(width: WEAInsets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: WEAColors.primaryText,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: WEAColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(notification.message, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${notification.category.label} · '
                      '${formatRelative(notification.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
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

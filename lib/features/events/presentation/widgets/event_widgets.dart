import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../shared/components/wea_components.dart';
import '../../domain/event_models.dart';

/// The card an event appears as in a listing.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final WeaEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artwork = event.artwork;

    return InkWell(
      onTap: () => context.go('/events/${event.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: WEAColors.card,
          border: Border.all(color: WEAColors.border),
          borderRadius: BorderRadius.circular(WEAInsets.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: artwork == null
                  ? const ColoredBox(color: WEAColors.elevated)
                  : Image.network(
                      artwork,
                      fit: BoxFit.cover,
                      semanticLabel: event.title,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: WEAColors.elevated),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(WEAInsets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (event.eventType.isNotEmpty)
                        WEABadge(label: _titleCase(event.eventType)),
                      const Spacer(),
                      Text(
                        event.format.label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: WEAColors.mutedText,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WEAInsets.sm),
                  Text(
                    event.title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: WEAInsets.xs),
                  Text(
                    formatEventDate(event.startsAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WEAColors.accentDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (event.summary.isNotEmpty) ...[
                    const SizedBox(height: WEAInsets.sm),
                    Text(
                      event.summary,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: WEAInsets.md),
                  const Divider(height: 1),
                  const SizedBox(height: WEAInsets.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.feeLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: WEAColors.primaryText,
                          ),
                        ),
                      ),
                      Text(
                        'VIEW EVENT →',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: WEAColors.accent,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _titleCase(String value) => value
    .toLowerCase()
    .split(RegExp(r'[_\s]+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

/// A labelled fact — date, venue, format, fee — in the event's fact strip.
class EventFact extends StatelessWidget {
  const EventFact({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onDark = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = onDark
        ? WEAColors.offWhite.withValues(alpha: .70)
        : WEAColors.mutedText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: onDark ? WEAColors.accentSoft : WEAColors.accent),
        const SizedBox(width: WEAInsets.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onDark ? WEAColors.offWhite : WEAColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A titled block of the event page.
class EventSectionBlock extends StatelessWidget {
  const EventSectionBlock({
    super.key,
    required this.title,
    required this.child,
    this.first = false,
  });

  final String title;
  final Widget child;
  final bool first;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: WEAInsets.xl),
    decoration: first
        ? null
        : const BoxDecoration(
            border: Border(top: BorderSide(color: WEAColors.border)),
          ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: WEAInsets.md),
        child,
      ],
    ),
  );
}

/// Body copy at a readable measure.
class EventProse extends StatelessWidget {
  const EventProse({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: WEAMaxWidths.readable),
    child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
  );
}

/// One line of the published agenda.
class EventAgendaRow extends StatelessWidget {
  const EventAgendaRow({super.key, required this.item});

  final EventAgendaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              item.time,
              style: theme.textTheme.labelLarge?.copyWith(
                color: WEAColors.accentDeep,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: theme.textTheme.titleMedium),
                if (item.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.detail, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A downloadable or linked event resource.
class EventMaterialCard extends StatelessWidget {
  const EventMaterialCard({
    super.key,
    required this.material,
    required this.onOpen,
  });

  final EventMaterial material;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: WEAInsets.xs),
      padding: const EdgeInsets.all(WEAInsets.md),
      decoration: BoxDecoration(
        color: WEAColors.card,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 22,
            color: WEAColors.accent,
          ),
          const SizedBox(width: WEAInsets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.title, style: theme.textTheme.titleMedium),
                if (material.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(material.description, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (material.participantsOnly)
            Padding(
              padding: const EdgeInsets.only(right: WEAInsets.xs),
              child: Tooltip(
                message: 'Participants only',
                child: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: WEAColors.mutedText,
                ),
              ),
            ),
          WEAOutlinedButton(label: 'OPEN', compact: true, onPressed: onOpen),
        ],
      ),
    );
  }
}

/// Lays children out in a responsive grid without a nested scroll view.
class EventGrid extends StatelessWidget {
  const EventGrid({super.key, required this.children, this.spacing = 24});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = switch (WEAResponsive.breakpointOf(constraints.maxWidth)) {
        WEABreakpoint.mobile => 1,
        WEABreakpoint.tablet => 2,
        _ => 3,
      };
      final width =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: width.clamp(240, constraints.maxWidth), child: child),
        ],
      );
    },
  );
}

/// A step indicator for the registration flow.
class RegistrationProgress extends StatelessWidget {
  const RegistrationProgress({
    super.key,
    required this.steps,
    required this.current,
  });

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              if (index > 0)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: WEAInsets.xs,
                    ),
                    color: index <= current
                        ? WEAColors.accent
                        : WEAColors.border,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index <= current
                          ? WEAColors.accent
                          : WEAColors.elevated,
                    ),
                    child: index < current
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: index == current
                                  ? Colors.white
                                  : WEAColors.mutedText,
                            ),
                          ),
                  ),
                  // On a narrow screen only the current step is named, which
                  // keeps the row readable instead of squeezing four labels.
                  if (!compact || index == current) ...[
                    const SizedBox(width: WEAInsets.xs),
                    Text(
                      steps[index],
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: index <= current
                            ? WEAColors.primaryText
                            : WEAColors.mutedText,
                        fontWeight: index == current
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A status chip for a registration or payment state.
class RegistrationStatusChip extends StatelessWidget {
  const RegistrationStatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final Color tone;
  final IconData? icon;

  factory RegistrationStatusChip.forRegistration(
    EventRegistrationStatus status,
  ) => RegistrationStatusChip(
    label: status.label,
    tone: switch (status) {
      EventRegistrationStatus.completed ||
      EventRegistrationStatus.paid => WEAColors.success,
      EventRegistrationStatus.paymentFailed ||
      EventRegistrationStatus.cancelled => WEAColors.error,
      EventRegistrationStatus.abandoned => WEAColors.mutedText,
      _ => WEAColors.warning,
    },
    icon: switch (status) {
      EventRegistrationStatus.completed ||
      EventRegistrationStatus.paid => Icons.verified_outlined,
      EventRegistrationStatus.paymentFailed => Icons.error_outline,
      EventRegistrationStatus.abandoned => Icons.hourglass_disabled_outlined,
      _ => Icons.schedule,
    },
  );

  factory RegistrationStatusChip.forPayment(EventPaymentStatus status) =>
      RegistrationStatusChip(
        label: status.label,
        tone: switch (status) {
          EventPaymentStatus.paid ||
          EventPaymentStatus.notRequired => WEAColors.success,
          EventPaymentStatus.failed => WEAColors.error,
          EventPaymentStatus.refunded => WEAColors.mutedText,
          _ => WEAColors.warning,
        },
        icon: switch (status) {
          EventPaymentStatus.paid => Icons.check_circle_outline,
          EventPaymentStatus.failed => Icons.error_outline,
          _ => Icons.schedule,
        },
      );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: .10),
      border: Border.all(color: tone.withValues(alpha: .34)),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: tone),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone),
        ),
      ],
    ),
  );
}

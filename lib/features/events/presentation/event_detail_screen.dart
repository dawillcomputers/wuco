import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/responsive/responsive.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/navigation/back_navigation.dart';
import '../../../shared/widgets/wea_public_widgets.dart';
import '../application/events_providers.dart';
import '../data/events_repository.dart';
import '../domain/event_models.dart';
import 'widgets/event_share_bar.dart';
import 'widgets/event_widgets.dart';

/// The public page for one event.
///
/// Its job is to answer, in order: what is this, when and where, who is it for,
/// what does it cost, and how do I register — with the fee stated plainly and
/// the registration action never more than a scroll away.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    if (!mounted) return;
    final detail = ref.read(eventDetailProvider(widget.slug)).value;
    ref
        .read(eventActionsProvider)
        .recordPageView(
          '/events/${widget.slug}',
          title: detail?.event.title ?? '',
          eventId: detail?.event.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(eventDetailProvider(widget.slug));

    // The identifier is only known once the event has loaded, so the view is
    // attributed to the event as soon as it arrives.
    ref.listen(eventDetailProvider(widget.slug), (previous, next) {
      if (previous?.value == null && next.value != null) _report();
    });

    return WEAPublicPage(
      child: detail.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(WEAInsets.section),
          child: WEALoading(label: 'Loading event'),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(WEAInsets.section),
          child: WEAErrorState(
            message: error is EventFailure
                ? error.message
                : 'We could not load this event.',
            onRetry: () => ref.invalidate(eventDetailProvider(widget.slug)),
          ),
        ),
        data: (data) => _EventBody(detail: data),
      ),
    );
  }
}

class _EventBody extends StatelessWidget {
  const _EventBody({required this.detail});

  final EventDetail detail;

  @override
  Widget build(BuildContext context) {
    final event = detail.event;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EventHero(detail: detail),
        WEAContainer(
          child: Padding(
            padding: const EdgeInsets.only(
              top: WEAInsets.xxl,
              bottom: WEAInsets.section,
            ),
            child: ResponsiveBuilder(
              builder: (context, breakpoint) {
                final wide = breakpoint != WEABreakpoint.mobile &&
                    breakpoint != WEABreakpoint.tablet;
                final body = _EventNarrative(detail: detail);
                final panel = _RegistrationPanel(detail: detail);

                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      panel,
                      const SizedBox(height: WEAInsets.xl),
                      body,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: body),
                    const SizedBox(width: WEAInsets.xxl),
                    SizedBox(width: 340, child: panel),
                  ],
                );
              },
            ),
          ),
        ),
        _EventFooterCta(event: event, open: detail.registrationOpen),
      ],
    );
  }
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.detail});

  final EventDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = detail.event;
    final artwork = event.artwork;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: WEAColors.navy,
        image: artwork == null
            ? null
            : DecorationImage(
                image: NetworkImage(artwork),
                fit: BoxFit.cover,
                opacity: .34,
                onError: (_, _) {},
              ),
      ),
      child: WEAContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Returns to whatever the visitor was reading; a shared link
              // opened cold has no history, so it falls back to the calendar.
              const WEABackButton(fallback: '/events', label: 'BACK', onDark: true),
              const SizedBox(height: WEAInsets.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Text(
                  event.title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: WEAColors.offWhite,
                  ),
                ),
              ),
              if (event.theme.isNotEmpty) ...[
                const SizedBox(height: WEAInsets.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Text(
                    // The line the event is convened around, so it carries
                    // the accent rather than sitting in the body colour.
                    event.theme,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: WEAColors.accentSoft,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              if (event.subtitle.isNotEmpty) ...[
                const SizedBox(height: WEAInsets.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Text(
                    event.subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: WEAColors.offWhite.withValues(alpha: .86),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: WEAInsets.xl),
              Wrap(
                spacing: WEAInsets.xl,
                runSpacing: WEAInsets.md,
                children: [
                  EventFact(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: formatEventWhen(
                      event.startsAt,
                      event.endsAt,
                      event.timezone,
                    ),
                    onDark: true,
                  ),
                  if (event.venue.isNotEmpty)
                    EventFact(
                      icon: Icons.place_outlined,
                      label: 'Venue',
                      value: event.venue,
                      onDark: true,
                    ),
                  EventFact(
                    icon: Icons.podcasts_outlined,
                    label: 'Format',
                    value: event.format.label,
                    onDark: true,
                  ),
                  EventFact(
                    icon: Icons.payments_outlined,
                    label: 'Registration fee',
                    value: event.feeLabel,
                    onDark: true,
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.xl),
              EventShareBar(
                kind: 'event',
                slug: event.slug,
                title: event.title,
                onDark: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventNarrative extends StatelessWidget {
  const _EventNarrative({required this.detail});

  final EventDetail detail;

  @override
  Widget build(BuildContext context) {
    final event = detail.event;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.description.isNotEmpty)
          EventSectionBlock(
            first: true,
            title: 'About the event',
            child: EventProse(text: detail.description),
          )
        else if (event.summary.isNotEmpty)
          EventSectionBlock(
            first: true,
            title: 'About the event',
            child: EventProse(text: event.summary),
          ),
        if (detail.whyAttend.isNotEmpty || detail.highlights.isNotEmpty)
          EventSectionBlock(
            title: 'Why attend',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.whyAttend.isNotEmpty)
                  EventProse(text: detail.whyAttend),
                if (detail.highlights.isNotEmpty) ...[
                  if (detail.whyAttend.isNotEmpty)
                    const SizedBox(height: WEAInsets.md),
                  for (final highlight in detail.highlights)
                    _Bullet(text: highlight),
                ],
              ],
            ),
          ),
        if (detail.speakers.isNotEmpty)
          EventSectionBlock(
            title: 'Speakers',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final speaker in detail.speakers) _Bullet(text: speaker),
              ],
            ),
          ),
        if (detail.whoShouldAttend.isNotEmpty)
          EventSectionBlock(
            title: 'Who should attend',
            child: EventProse(text: detail.whoShouldAttend),
          ),
        if (detail.agenda.isNotEmpty)
          EventSectionBlock(
            title: 'Programme',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, item) in detail.agenda.indexed)
                  EventAgendaRow(
                    item: item,
                    isLast: index == detail.agenda.length - 1,
                  ),
              ],
            ),
          ),
        if (detail.sessions.isNotEmpty)
          EventSectionBlock(
            title: 'Sessions',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final session in detail.sessions)
                  _SessionRow(session: session),
              ],
            ),
          ),
        if (detail.materials.isNotEmpty)
          EventSectionBlock(
            title: 'Event documents',
            child: Column(
              children: [
                for (final material in detail.materials)
                  EventMaterialCard(material: material, onOpen: null),
              ],
            ),
          ),
        if (detail.practicalities.isNotEmpty)
          EventSectionBlock(
            title: 'What to know before you register',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in detail.practicalities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: WEAInsets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        EventProse(text: item.$2),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (detail.terms.isNotEmpty)
          EventSectionBlock(
            title: 'Terms and conditions',
            child: EventProse(text: detail.terms),
          ),
        if (detail.contactEmail.isNotEmpty || detail.contactPhone.isNotEmpty)
          EventSectionBlock(
            title: 'Event enquiries',
            child: EventProse(
              text: [
                detail.contactEmail,
                detail.contactPhone,
              ].where((line) => line.isNotEmpty).join('\n'),
            ),
          ),
      ],
    );
  }
}

/// One highlight or speaker.
class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: WEAInsets.xs),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: WEAMaxWidths.readable),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: WEAInsets.sm),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: WEAColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    ),
  );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final EventSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(session.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            [
              formatEventWhen(session.startsAt, session.endsAt, session.timezone),
              if (session.speaker.isNotEmpty) session.speaker,
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The registration panel: fee, availability and the action.
class _RegistrationPanel extends StatelessWidget {
  const _RegistrationPanel({required this.detail});

  final EventDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = detail.event;
    final open = detail.registrationOpen;

    return Container(
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: WEAColors.card,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REGISTRATION FEE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: WEAInsets.xs),
          Text(
            event.feeLabel,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: WEAColors.primaryText,
            ),
          ),
          if (detail.placesRemaining != null) ...[
            const SizedBox(height: WEAInsets.xs),
            Text(
              detail.placesRemaining == 0
                  ? 'This event is full.'
                  : '${detail.placesRemaining} of ${event.capacity} places remaining',
              style: theme.textTheme.bodySmall?.copyWith(
                color: detail.placesRemaining == 0
                    ? WEAColors.error
                    : WEAColors.secondaryText,
              ),
            ),
          ],
          if (detail.registrationClosesAt != null) ...[
            const SizedBox(height: WEAInsets.xs),
            Text(
              'Registration closes ${formatEventDate(detail.registrationClosesAt)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: WEAInsets.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: open
                  ? () => context.go('/events/${event.slug}/register')
                  : null,
              child: Text(open ? 'REGISTER NOW' : 'REGISTRATION CLOSED'),
            ),
          ),
          const SizedBox(height: WEAInsets.sm),
          Text(
            open
                ? event.isPaid
                      ? 'Your place is confirmed once payment has been received '
                            'and verified.'
                      : 'No payment is required for this event.'
                : 'Registration for this event is not currently open.',
            style: theme.textTheme.bodySmall,
          ),
          if (detail.hasFlier) ...[
            const SizedBox(height: WEAInsets.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(detail.flierUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                icon: const Icon(Icons.download_outlined, size: 17),
                label: const Text('DOWNLOAD THE FLIER'),
              ),
            ),
          ],
          if (detail.allowGuestRegistration && open) ...[
            const SizedBox(height: WEAInsets.sm),
            Row(
              children: [
                const Icon(
                  Icons.bolt_outlined,
                  size: 15,
                  color: WEAColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No account needed to start.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WEAColors.accentDeep,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EventFooterCta extends StatelessWidget {
  const _EventFooterCta({required this.event, required this.open});

  final WeaEvent event;
  final bool open;

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return ColoredBox(
      color: WEAColors.surfaceMuted,
      child: WEAContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.xxxl),
          child: ResponsiveBuilder(
            builder: (context, breakpoint) {
              final stacked = breakpoint == WEABreakpoint.mobile;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Register', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    '${event.title} · ${event.feeLabel}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              );
              final action = ElevatedButton(
                onPressed: () => context.go('/events/${event.slug}/register'),
                child: const Text('REGISTER NOW'),
              );
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        copy,
                        const SizedBox(height: WEAInsets.lg),
                        action,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: WEAInsets.lg),
                        action,
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}

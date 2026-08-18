import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/widgets/wea_auto_grid.dart';
import '../../../shared/widgets/wea_public_widgets.dart';
import '../application/events_providers.dart';
import '../data/events_repository.dart';
import '../domain/event_models.dart';
import 'widgets/event_widgets.dart';
import 'widgets/payment_choice_sheet.dart';

/// The public events calendar.
///
/// Every event here is a row a Super Admin published; nothing is compiled in,
/// so the next summit appears without a release.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  var _search = '';

  @override
  void initState() {
    super.initState();
    // Reported after the first frame so measurement never delays the paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(eventActionsProvider).recordPageView('/events', title: 'Events');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      upcomingOnly: false,
      featuredOnly: false,
      search: _search.isEmpty ? null : _search,
    );
    final events = ref.watch(eventsListProvider(query));

    return WEAPublicPage(
      child: WEAContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WEASectionHeading(
                eyebrow: 'EVENTS',
                title: 'Where executive conversations continue.',
                description:
                    'Executive conferences, summits, masterclasses and forums '
                    'convened by WUCO Executive Academy.',
              ),
              const SizedBox(height: WEAInsets.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: TextField(
                  onChanged: (value) => setState(() => _search = value.trim()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Search events',
                  ),
                ),
              ),
              const SizedBox(height: WEAInsets.xl),
              const _MyRegistrations(),
              events.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(WEAInsets.xxxl),
                  child: WEALoading(label: 'Loading events'),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(WEAInsets.xxl),
                  child: WEAErrorState(
                    message: error is EventFailure
                        ? error.message
                        : 'We could not load the events calendar.',
                    onRetry: () => ref.invalidate(eventsListProvider(query)),
                  ),
                ),
                data: (rows) => rows.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(WEAInsets.xxl),
                        child: WEAEmptyState(
                          title: 'No events published yet',
                          message:
                              'The next WEA events will be announced here.',
                        ),
                      )
                    : _EventSections(events: rows),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A signed-in visitor's own registrations, so they can reach their event
/// dashboard without hunting for the confirmation email.
class _MyRegistrations extends ConsumerWidget {
  const _MyRegistrations();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myEventRegistrationsProvider);
    return mine.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR REGISTRATIONS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: WEAColors.mutedText,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: WEAInsets.sm),
            for (final row in rows)
              Container(
                margin: const EdgeInsets.only(bottom: WEAInsets.xs),
                padding: const EdgeInsets.all(WEAInsets.md),
                decoration: BoxDecoration(
                  color: WEAColors.card,
                  border: Border.all(color: WEAColors.border),
                  borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.event.title,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatEventDate(row.event.startsAt)} · '
                            '${row.registration.reference}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    RegistrationStatusChip.forRegistration(
                      row.registration.status,
                    ),
                    const SizedBox(width: WEAInsets.sm),
                    // A place that is not paid for is not held, so the action
                    // that settles it comes first and is the emphasised one.
                    // Where nothing is owed there is nothing to press.
                    if (!row.registration.paymentStatus.settled)
                      Padding(
                        padding: const EdgeInsets.only(right: WEAInsets.xs),
                        child: _PayNowButton(row: row),
                      ),
                    WEAOutlinedButton(
                      label: 'OPEN',
                      compact: true,
                      onPressed: () => context.go(
                        '/events/registration/${row.registration.reference}',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: WEAInsets.xl),
          ],
        );
      },
    );
  }
}

/// Settles an unpaid registration without opening it first.
///
/// The commonest thing somebody returns to this page to do is pay, so it is
/// one press from the list rather than two. It starts the payment on the API
/// and follows the checkout the API hands back — the amount and the currency
/// are decided there, exactly as they are everywhere else.
class _PayNowButton extends ConsumerStatefulWidget {
  const _PayNowButton({required this.row});

  final MyEventRegistration row;

  @override
  ConsumerState<_PayNowButton> createState() => _PayNowButtonState();
}

class _PayNowButtonState extends ConsumerState<_PayNowButton> {
  bool _busy = false;

  /// Asks how they want to pay, using the same sheet as everywhere else.
  ///
  /// The ways on offer come from the API, so a Nigerian registrant is shown
  /// the transfer their event actually configured rather than being sent
  /// straight to a card.
  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final registration = widget.row.registration;
      final options = await ref.read(
        eventPaymentMethodsProvider((
          slug: widget.row.event.slug,
          attendanceMode: registration.attendanceMode.isEmpty
              ? null
              : registration.attendanceMode,
          country: registration.country.isEmpty ? null : registration.country,
        )).future,
      );
      if (!mounted) return;
      setState(() => _busy = false);

      await showPaymentChoice(
        context: context,
        reference: registration.reference,
        options: options,
        attendanceMode: registration.attendanceMode.isEmpty
            ? null
            : registration.attendanceMode,
      );
      if (mounted) ref.invalidate(myEventRegistrationsProvider);
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) => WEAButton(
    label: _busy ? 'OPENING…' : 'PAY NOW',
    onPressed: _busy ? null : _pay,
  );
}

/// Splits the calendar into what is ahead and what has already happened.
class _EventSections extends StatelessWidget {
  const _EventSections({required this.events});

  final List<WeaEvent> events;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = [
      for (final event in events)
        if (event.startsAt == null || !event.startsAt!.isBefore(now)) event,
    ];
    final past = [
      for (final event in events)
        if (event.startsAt != null && event.startsAt!.isBefore(now)) event,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (upcoming.isNotEmpty) ...[
          Text(
            'FORTHCOMING',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: WEAInsets.md),
          WEAAutoGrid(
            spacing: WEAInsets.md,
            runSpacing: WEAInsets.md,
            children: [for (final event in upcoming) EventCard(event: event)],
          ),
        ],
        if (past.isNotEmpty) ...[
          const SizedBox(height: WEAInsets.xxxl),
          Text(
            'PAST EVENTS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: WEAInsets.md),
          WEAAutoGrid(
            spacing: WEAInsets.md,
            runSpacing: WEAInsets.md,
            children: [
              for (final event in past)
                EventCard(event: event, registrationOpen: false),
            ],
          ),
        ],
      ],
    );
  }
}

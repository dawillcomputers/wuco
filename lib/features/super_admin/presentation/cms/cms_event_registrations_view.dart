import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../events/application/events_providers.dart';
import '../../../events/data/events_repository.dart';
import '../../../events/domain/event_models.dart';
import '../../../events/presentation/widgets/event_widgets.dart';
import '../../application/cms_providers.dart';

/// Event registrations as the academy sees them.
///
/// The important thing this screen does is show the people who *did not*
/// finish. Someone who typed their name, their address and their telephone
/// number and then closed the tab is a lead the academy can call, and they sit
/// in this list alongside the confirmed places rather than vanishing.
class CmsEventRegistrationsView extends ConsumerStatefulWidget {
  const CmsEventRegistrationsView({super.key});

  @override
  ConsumerState<CmsEventRegistrationsView> createState() =>
      _CmsEventRegistrationsViewState();
}

class _CmsEventRegistrationsViewState
    extends ConsumerState<CmsEventRegistrationsView> {
  String? _eventId;
  String _search = '';
  _Lens _lens = _Lens.all;

  RegistrantQuery get _query => (
    eventId: _eventId,
    status: null,
    paymentStatus: null,
    search: _search.isEmpty ? null : _search,
  );

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) _notify(done);
    } on EventFailure catch (failure) {
      if (mounted) _notify(failure.message);
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(backgroundColor: WEAColors.navy, content: Text(message)),
  );

  Future<void> _export() async {
    try {
      final csv = await ref
          .read(eventActionsProvider)
          .exportRegistrations(eventId: _eventId);
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        _notify(
          'Registrations copied as CSV. Paste into a spreadsheet and save.',
        );
      }
    } on EventFailure catch (failure) {
      if (mounted) _notify(failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registrants = ref.watch(adminRegistrantsProvider(_query));
    final overview = ref.watch(adminEventOverviewProvider(_eventId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event registrations',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Everyone who started, whether or not they finished.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: WEAInsets.md),
            OutlinedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('EXPORT CSV'),
            ),
          ],
        ),
        const SizedBox(height: WEAInsets.lg),
        overview.when(
          loading: () => const SizedBox(height: 2, child: LinearProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
          data: (data) => _Overview(
            overview: data.$1,
            funnel: data.$2,
            onSweep: () => _run(() async {
              final updated = await ref.read(eventActionsProvider).sweepAbandoned();
              if (mounted) _notify('$updated registration(s) marked abandoned.');
            }, ''),
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        _EventFilter(
          selected: _eventId,
          onSelected: (value) => setState(() => _eventId = value),
        ),
        TextField(
          onChanged: (value) => setState(() => _search = value.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 20),
            hintText: 'Search by name, email, phone, organisation or reference',
          ),
        ),
        const SizedBox(height: WEAInsets.md),
        Wrap(
          spacing: WEAInsets.xs,
          children: [
            for (final lens in _Lens.values)
              ChoiceChip(
                label: Text(lens.label),
                selected: _lens == lens,
                onSelected: (_) => setState(() => _lens = lens),
              ),
          ],
        ),
        const SizedBox(height: WEAInsets.md),
        registrants.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(WEAInsets.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(WEAInsets.xl),
            child: Text(
              error is EventFailure
                  ? error.message
                  : 'We could not load event registrations.',
              textAlign: TextAlign.center,
            ),
          ),
          data: (rows) {
            final visible = [
              for (final row in rows)
                if (_lens.matches(row)) row,
            ];
            if (visible.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: WEAInsets.xxl),
                child: Center(
                  child: Text(
                    'No registrations match this view yet.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final row in visible)
                  _RegistrantRow(
                    registrant: row,
                    onStatus: (status) => _run(
                      () => ref
                          .read(eventActionsProvider)
                          .setRegistrationStatus(row.id, status: status),
                      'Registration updated.',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The four ways the academy actually looks at this list.
enum _Lens {
  all('Everyone'),
  confirmed('Confirmed'),
  pending('Awaiting payment'),
  leads('Leads');

  const _Lens(this.label);

  final String label;

  bool matches(EventRegistrant row) => switch (this) {
    _Lens.all => true,
    _Lens.confirmed => row.paymentStatus.settled,
    _Lens.pending =>
      row.paymentStatus == EventPaymentStatus.pending ||
          row.paymentStatus == EventPaymentStatus.processing,
    // Everyone who gave their details and did not complete — the follow-up list.
    _Lens.leads => row.isLead,
  };
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.overview,
    required this.funnel,
    required this.onSweep,
  });

  final EventOverview overview;
  final EventFunnel funnel;
  final VoidCallback onSweep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Wrap(
            spacing: WEAInsets.xxl,
            runSpacing: WEAInsets.md,
            children: [
              _Metric(label: 'Registration attempts', value: '${overview.totalAttempts}'),
              _Metric(
                label: 'Completed',
                value: '${overview.completed}',
                tone: WEAColors.success,
              ),
              _Metric(
                label: 'Payment pending',
                value: '${overview.paymentPending + overview.paymentProcessing}',
                tone: WEAColors.warning,
              ),
              _Metric(
                label: 'Abandoned',
                value: '${overview.abandoned}',
                tone: WEAColors.mutedText,
              ),
              _Metric(
                label: 'Payment failed',
                value: '${overview.paymentFailed}',
                tone: WEAColors.error,
              ),
            ],
          ),
          const Divider(height: WEAInsets.xl),
          Text(
            'VERIFIED REVENUE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          // Only payments the processor confirmed. Pending and abandoned
          // registrations are never counted as money.
          Text(
            overview.revenue.isEmpty
                ? 'No verified payments yet'
                : overview.revenue.entries
                      .map((entry) => formatMoney(entry.value, entry.key))
                      .join('  ·  '),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: WEAInsets.lg),
          Text(
            'CONVERSION',
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: WEAInsets.xs),
          Wrap(
            spacing: WEAInsets.xxl,
            runSpacing: WEAInsets.md,
            children: [
              _Metric(label: 'Page visitors', value: '${funnel.landingPageVisitors}'),
              _Metric(label: 'Started', value: '${funnel.startedRegistration}'),
              _Metric(label: 'Completed form', value: '${funnel.completedForm}'),
              _Metric(label: 'Payment attempts', value: '${funnel.paymentAttempts}'),
              _Metric(label: 'Paid', value: '${funnel.successfulPayments}'),
              _Metric(
                label: 'Conversion rate',
                value: funnel.conversionRate == null
                    ? '—'
                    : '${funnel.conversionRate}%',
                tone: WEAColors.accent,
              ),
            ],
          ),
          const SizedBox(height: WEAInsets.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onSweep,
              icon: const Icon(Icons.cleaning_services_outlined, size: 17),
              label: const Text('MARK STALE ATTEMPTS AS ABANDONED'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: tone ?? WEAColors.primaryText,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: WEAColors.mutedText),
        ),
      ],
    );
  }
}

class _EventFilter extends ConsumerWidget {
  const _EventFilter({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(cmsOptionsProvider('events'));
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.md),
      child: options.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (rows) => DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Filter by event'),
          items: [
            const DropdownMenuItem(value: null, child: Text('— All events —')),
            for (final row in rows)
              DropdownMenuItem(
                value: '${row['id']}',
                child: Text(
                  '${row['title'] ?? row['id']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onSelected,
        ),
      ),
    );
  }
}

class _RegistrantRow extends StatelessWidget {
  const _RegistrantRow({required this.registrant, required this.onStatus});

  final EventRegistrant registrant;
  final ValueChanged<EventRegistrationStatus> onStatus;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registrant.name.isEmpty ? 'Unnamed' : registrant.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        registrant.email,
                        if (registrant.phone.isNotEmpty) registrant.phone,
                        if (registrant.organisation.isNotEmpty)
                          registrant.organisation,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${registrant.eventTitle} · ${registrant.reference}'
                      '${registrant.campaign.isEmpty ? '' : ' · ${registrant.campaign}'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: WEAColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WEAInsets.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RegistrationStatusChip.forRegistration(registrant.status),
                  const SizedBox(height: 4),
                  RegistrationStatusChip.forPayment(registrant.paymentStatus),
                ],
              ),
            ],
          ),
          const SizedBox(height: WEAInsets.sm),
          Row(
            children: [
              Text(
                registrant.amount > 0
                    ? formatMoney(registrant.amount, registrant.currency)
                    : 'Free',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              // Chiefly for confirming a bank transfer, which no processor can
              // tell the academy about.
              if (!registrant.paymentStatus.settled)
                TextButton(
                  onPressed: () => onStatus(EventRegistrationStatus.paid),
                  child: const Text('MARK PAID'),
                ),
              if (registrant.status != EventRegistrationStatus.cancelled)
                TextButton(
                  onPressed: () => onStatus(EventRegistrationStatus.cancelled),
                  child: const Text('CANCEL'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

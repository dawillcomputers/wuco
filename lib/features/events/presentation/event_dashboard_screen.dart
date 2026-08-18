import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/checkout_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/responsive/responsive.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/data/countries.dart';
import '../../../shared/navigation/back_navigation.dart';
import '../../../shared/widgets/wea_public_widgets.dart';
import '../application/events_providers.dart';
import '../data/events_repository.dart';
import '../domain/event_models.dart';
import 'widgets/event_widgets.dart';

/// A participant's own view of one registration.
///
/// This is where the payer lands when the processor sends them back, so it has
/// three jobs at once: confirm what actually happened with the payment, tell
/// them plainly whether their place is secure, and — once it is — be the
/// dashboard for the event itself.
///
/// The confirmation is not taken from the return URL. Arriving here asks the
/// API to check with the processor, which is the only thing that decides.
class EventDashboardScreen extends ConsumerStatefulWidget {
  const EventDashboardScreen({super.key, required this.reference});

  final String reference;

  @override
  ConsumerState<EventDashboardScreen> createState() =>
      _EventDashboardScreenState();
}

class _EventDashboardScreenState extends ConsumerState<EventDashboardScreen> {
  var _verifying = false;
  var _verified = false;
  var _switching = false;
  EventPaymentOutcome? _outcome;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(eventActionsProvider)
          .recordPageView('/events/registration', title: 'Event registration');
    });
  }

  /// Asks the API to settle the payment, at most once per visit.
  Future<void> _verify(EventRegistration registration) async {
    if (_verified || _verifying) return;
    if (registration.paymentStatus.settled) {
      _verified = true;
      return;
    }
    setState(() => _verifying = true);
    try {
      final outcome = await ref
          .read(eventActionsProvider)
          .verifyPayment(
            widget.reference,
            // Flutterwave returns the payer here with `transaction_id` on the
            // URL. It is the only thing the API can verify the payment by, so
            // it is read from the address rather than assumed.
            transactionId: Uri.base.queryParameters['transaction_id'],
          );
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _verifying = false;
        _verified = true;
      });
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = true;
        _error = failure.message;
      });
    }
  }

  /// Moves the registration between attending in person and online.
  ///
  /// The disclaimer comes first and has to be agreed to, because the change is
  /// not reversible in money: switching from the dearer way of attending to
  /// the cheaper one refunds nothing. Saying that plainly before the change is
  /// made is the point of the step — nobody should discover it afterwards.
  Future<void> _changeAttendance(EventAttendanceMode mode, bool paid) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => _AttendanceDisclaimer(mode: mode, paid: paid),
    );
    if (agreed != true) return;

    setState(() {
      _switching = true;
      _error = null;
    });
    try {
      await ref
          .read(eventActionsProvider)
          .changeAttendance(widget.reference, mode);
      if (!mounted) return;
      setState(() => _switching = false);
      _notify('You are now attending ${mode.shortLabel.toLowerCase()}.');
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _switching = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _retryPayment() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(eventActionsProvider)
          .beginPayment(widget.reference);
      if (!mounted) return;
      setState(() => _verifying = false);
      if (intent.hasCheckout) {
        final opened = await openCheckout(intent.checkoutUrl!);
        if (!opened && mounted) {
          setState(
            () => _error =
                'Your browser did not open the payment page. Try again, or '
                'allow this site to open it.',
          );
        }
      } else if (mounted) {
        _notify(
          intent.instructions.isEmpty
              ? 'The academy office will be in touch with payment instructions.'
              : intent.instructions,
        );
      }
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) {
      _notify('That document is not available yet.');
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _join(EventSession session) async {
    try {
      final url = await ref
          .read(eventActionsProvider)
          .joinSession(widget.reference, session.id);
      if (url.isEmpty) {
        _notify('The room is not open yet.');
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on EventFailure catch (failure) {
      _notify(failure.message);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: WEAColors.navy, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(eventDashboardProvider(widget.reference));

    return WEAPublicPage(
      child: WEAContainer(
        maxWidth: 980,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: dashboard.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(WEAInsets.xxxl),
              child: WEALoading(label: 'Loading your registration'),
            ),
            error: (error, _) => WEAErrorState(
              message: error is EventFailure
                  ? error.message
                  : 'We could not find that registration.',
              onRetry: () =>
                  ref.invalidate(eventDashboardProvider(widget.reference)),
            ),
            data: (data) {
              // Settling happens on arrival, which is exactly when the payer
              // gets back from the processor.
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _verify(data.registration),
              );
              return _body(data);
            },
          ),
        ),
      ),
    );
  }

  Widget _body(EventDashboard data) {
    final theme = Theme.of(context);
    final registration = data.registration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusBanner(
          registration: registration,
          verifying: _verifying,
          outcome: _outcome,
          successMessage: data.successMessage,
          onRetry: _retryPayment,
        ),
        if (_error != null) ...[
          const SizedBox(height: WEAInsets.md),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: WEAColors.error),
          ),
        ],
        const SizedBox(height: WEAInsets.xxl),
        Text(
          'Welcome, ${registration.firstName}',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(data.event.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: WEAInsets.lg),
        Wrap(
          spacing: WEAInsets.xl,
          runSpacing: WEAInsets.md,
          children: [
            EventFact(
              icon: Icons.calendar_today_outlined,
              label: 'Event date',
              value: formatEventWhen(
                data.event.startsAt,
                data.event.endsAt,
                data.event.timezone,
              ),
            ),
            if (data.event.venue.isNotEmpty)
              EventFact(
                icon: Icons.place_outlined,
                label: 'Venue',
                value: data.event.venue,
              ),
            EventFact(
              icon: Icons.confirmation_number_outlined,
              label: 'Reference',
              value: registration.reference,
            ),
            EventFact(
              icon: Icons.payments_outlined,
              label: 'Payment',
              value: registration.paymentStatus.label,
            ),
          ],
        ),
        const SizedBox(height: WEAInsets.xxl),
        ResponsiveBuilder(
          builder: (context, breakpoint) {
            final stacked = breakpoint == WEABreakpoint.mobile;
            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.liveNow != null || data.sessions.isNotEmpty)
                  _SessionsPanel(
                    dashboard: data,
                    onJoin: _join,
                    onRecording: (session) => _open(session.recordingUrl),
                  ),
                if (data.canChangeAttendance)
                  _AttendancePanel(
                    dashboard: data,
                    busy: _switching,
                    onChange: _changeAttendance,
                  ),
                _MaterialsPanel(dashboard: data, onOpen: _open),
                if (data.agenda.isNotEmpty)
                  EventSectionBlock(
                    title: 'Agenda',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (index, item) in data.agenda.indexed)
                          EventAgendaRow(
                            item: item,
                            isLast: index == data.agenda.length - 1,
                          ),
                      ],
                    ),
                  ),
              ],
            );
            final side = _RegistrationPanel(registration: registration);
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [side, const SizedBox(height: WEAInsets.xl), main],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: main),
                      const SizedBox(width: WEAInsets.xxl),
                      SizedBox(width: 300, child: side),
                    ],
                  );
          },
        ),
        const SizedBox(height: WEAInsets.xxl),
        WEAOutlinedButton(
          label: 'BACK TO EVENT',
          onPressed: () =>
              weaGoBack(context, fallback: '/events/${data.event.slug}'),
        ),
      ],
    );
  }
}

/// The headline outcome: confirmed, awaiting payment, or failed.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.registration,
    required this.verifying,
    required this.outcome,
    required this.successMessage,
    required this.onRetry,
  });

  final EventRegistration registration;
  final bool verifying;
  final EventPaymentOutcome? outcome;
  final String successMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (verifying) {
      return _Panel(
        tone: WEAColors.accent,
        icon: Icons.sync,
        title: 'Confirming your payment',
        body:
            'We are checking with the payment processor. This takes a moment.',
      );
    }

    if (registration.isConfirmed) {
      return _Panel(
        tone: WEAColors.success,
        icon: Icons.verified_outlined,
        title: 'Registration successful',
        body: successMessage.isNotEmpty
            ? successMessage
            : 'Your place is confirmed. A confirmation has been sent to '
                  '${registration.email}.',
        child: Padding(
          padding: const EdgeInsets.only(top: WEAInsets.sm),
          child: Text(
            'Reference ${registration.reference}'
            '${registration.requiresPayment ? ' · ${registration.amountLabel} paid' : ''}',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    if (registration.paymentStatus == EventPaymentStatus.failed) {
      return _Panel(
        tone: WEAColors.error,
        icon: Icons.error_outline,
        title: 'Payment not completed',
        body:
            'Your registration has been saved, but the payment was not '
            'successful. You can try again.',
        action: ('TRY PAYMENT AGAIN', onRetry),
      );
    }

    return _Panel(
      tone: WEAColors.warning,
      icon: Icons.schedule,
      title: 'Payment pending',
      body: registration.requiresPayment
          ? 'Your registration is saved and your place is held once payment of '
                '${registration.amountLabel} has been received and verified.'
          : 'Your registration is saved.',
      action: registration.requiresPayment ? ('PAY NOW', onRetry) : null,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
    this.child,
    this.action,
  });

  final Color tone;
  final IconData icon;
  final String title;
  final String body;
  final Widget? child;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        border: Border.all(color: tone.withValues(alpha: .32)),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 26),
          const SizedBox(width: WEAInsets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(color: tone),
                ),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
                ?child,
                if (action != null) ...[
                  const SizedBox(height: WEAInsets.md),
                  WEAOutlinedButton(
                    label: action!.$1,
                    compact: true,
                    onPressed: action!.$2,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsPanel extends StatelessWidget {
  const _SessionsPanel({
    required this.dashboard,
    required this.onJoin,
    required this.onRecording,
  });

  final EventDashboard dashboard;
  final void Function(EventSession) onJoin;
  final void Function(EventSession) onRecording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EventSectionBlock(
      first: true,
      title: 'Live sessions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dashboard.sessions.isEmpty)
            Text(
              'Session details will be published here before the event.',
              style: theme.textTheme.bodyMedium,
            ),
          for (final session in dashboard.sessions)
            Container(
              margin: const EdgeInsets.only(bottom: WEAInsets.xs),
              padding: const EdgeInsets.all(WEAInsets.md),
              decoration: BoxDecoration(
                color: WEAColors.card,
                border: Border.all(
                  color: session.isLive ? WEAColors.accent : WEAColors.border,
                ),
                borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          [
                            formatEventWhen(
                              session.startsAt,
                              session.endsAt,
                              session.timezone,
                            ),
                            if (session.speaker.isNotEmpty) session.speaker,
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (session.isLive && dashboard.entitled)
                    WEAOutlinedButton(
                      label: 'JOIN LIVE',
                      compact: true,
                      onPressed: () => onJoin(session),
                    )
                  else if (session.hasRecording && dashboard.entitled)
                    WEAOutlinedButton(
                      label: 'RECORDING',
                      compact: true,
                      onPressed: () => onRecording(session),
                    )
                  else
                    Text(
                      dashboard.entitled ? 'Not open yet' : 'Payment required',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: WEAColors.mutedText,
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

/// Lets a registrant move between attending in person and attending online.
///
/// Only shown where the event offers both. Plans change — a flight falls
/// through, or somebody who booked online finds they can travel — and making
/// them cancel and register again would cost them their place and their
/// payment.
class _AttendancePanel extends StatelessWidget {
  const _AttendancePanel({
    required this.dashboard,
    required this.busy,
    required this.onChange,
  });

  final EventDashboard dashboard;
  final bool busy;
  final void Function(EventAttendanceMode mode, bool paid) onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registration = dashboard.registration;
    final current = registration.mode;
    final paid = registration.paymentStatus.settled;

    return EventSectionBlock(
      title: 'How you are attending',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paid
                ? 'You can change this at any time. Your place is already paid '
                      'for, so switching costs nothing and refunds nothing.'
                : 'You can change this until you pay. The fee follows whichever '
                      'you choose.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: WEAColors.mutedText,
            ),
          ),
          const SizedBox(height: WEAInsets.md),
          if (busy)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: WEAInsets.sm,
              runSpacing: WEAInsets.sm,
              children: [
                for (final mode in dashboard.attendanceModes)
                  ChoiceChip(
                    selected: mode == current,
                    onSelected: (_) {
                      if (mode != current) onChange(mode, paid);
                    },
                    avatar: Icon(
                      mode == EventAttendanceMode.physical
                          ? Icons.location_on_outlined
                          : Icons.videocam_outlined,
                      size: 18,
                    ),
                    label: Text(mode.label),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// What changes, and what does not, before the switch is made.
///
/// The money is the part worth stating: moving from the dearer way of
/// attending to the cheaper one refunds nothing. Somebody should agree to that
/// knowingly rather than discover it on their statement.
class _AttendanceDisclaimer extends StatefulWidget {
  const _AttendanceDisclaimer({required this.mode, required this.paid});

  final EventAttendanceMode mode;
  final bool paid;

  @override
  State<_AttendanceDisclaimer> createState() => _AttendanceDisclaimerState();
}

class _AttendanceDisclaimerState extends State<_AttendanceDisclaimer> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Change to ${widget.mode.shortLabel.toLowerCase()}?'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.paid
                  ? 'Your place is already paid for. Changing how you attend '
                        'does not change what you paid: nothing further is '
                        'charged, and nothing is refunded — including where '
                        'the other way of attending costs less.'
                  : 'You have not paid yet, so the fee will follow whichever '
                        'you choose. You will see the amount before paying.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: WEAInsets.md),
            Container(
              padding: const EdgeInsets.all(WEAInsets.sm),
              decoration: BoxDecoration(
                color: WEAColors.surfaceMuted,
                borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
              ),
              child: Text(
                widget.mode == EventAttendanceMode.virtual
                    ? 'You will receive a joining link instead of a seat in the '
                          'room.'
                    : 'You will have a seat in the room instead of a joining '
                          'link.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: WEAInsets.sm),
            CheckboxListTile(
              value: _agreed,
              onChanged: (value) => setState(() => _agreed = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                widget.paid
                    ? 'I understand that no refund is due.'
                    : 'I understand the fee will change.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        // Enabled only once they have agreed, so the tick is a decision rather
        // than something to click past.
        ElevatedButton(
          onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('CONTINUE'),
        ),
      ],
    );
  }
}

class _MaterialsPanel extends StatelessWidget {
  const _MaterialsPanel({required this.dashboard, required this.onOpen});

  final EventDashboard dashboard;
  final void Function(String?) onOpen;

  @override
  Widget build(BuildContext context) => EventSectionBlock(
    title: 'Programme materials',
    child: dashboard.materials.isEmpty
        ? Text(
            dashboard.entitled
                ? 'Materials will appear here as the academy publishes them.'
                : 'Programme materials are released once your payment has been '
                      'confirmed.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        : Column(
            children: [
              for (final material in dashboard.materials)
                EventMaterialCard(
                  material: material,
                  onOpen: () => onOpen(material.url),
                ),
            ],
          ),
  );
}

class _RegistrationPanel extends StatelessWidget {
  const _RegistrationPanel({required this.registration});

  final EventRegistration registration;

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
          Text('My registration', style: theme.textTheme.titleLarge),
          const SizedBox(height: WEAInsets.md),
          RegistrationStatusChip.forRegistration(registration.status),
          const SizedBox(height: WEAInsets.md),
          _Detail(label: 'Name', value: registration.fullName),
          _Detail(label: 'Email', value: registration.email),
          _Detail(label: 'Phone', value: registration.phone),
          if (registration.organisation.isNotEmpty)
            _Detail(label: 'Organisation', value: registration.organisation),
          if (registration.jobTitle.isNotEmpty)
            _Detail(label: 'Job title', value: registration.jobTitle),
          if (registration.country.isNotEmpty)
            // Stored as an ISO code now, so it is resolved back to a name —
            // a registrant should read "Ghana", not "GH".
            _Detail(label: 'Country', value: countryName(registration.country)),
          if (registration.mode case final mode?)
            _Detail(label: 'Attending', value: mode.shortLabel),
          _Detail(label: 'Reference', value: registration.reference),
          if (registration.requiresPayment)
            _Detail(label: 'Fee', value: registration.amountLabel),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

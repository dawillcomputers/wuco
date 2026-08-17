import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/checkout_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/navigation/back_navigation.dart';
import '../../../shared/widgets/wea_public_widgets.dart';
import '../../authentication/application/auth_controller.dart';
import '../application/events_providers.dart';
import '../data/events_repository.dart';
import '../domain/event_models.dart';
import 'widgets/event_widgets.dart';

/// Registering for an event.
///
/// Two decisions shape this screen.
///
/// The form is short on purpose. Before payment it asks for a name, an address
/// and a telephone number, plus whatever questions the academy configured for
/// this event — and nothing else. Anything WEA already holds is shown as
/// confirmed rather than asked for again.
///
/// And it saves as it goes. Each step is written to the API before the next one
/// opens, so somebody who fills in their details and then closes the tab is a
/// registration the academy can still see and follow up, not a lost visit.
class EventRegistrationScreen extends ConsumerStatefulWidget {
  const EventRegistrationScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<EventRegistrationScreen> createState() =>
      _EventRegistrationScreenState();
}

class _EventRegistrationScreenState
    extends ConsumerState<EventRegistrationScreen> {
  final _detailsKey = GlobalKey<FormState>();
  final _contactKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _organisation = TextEditingController();
  final _jobTitle = TextEditingController();
  final _country = TextEditingController();
  final _answers = <String, String>{};

  var _step = 0;
  var _prefilled = false;
  var _busy = false;
  var _accepted = false;
  String? _error;
  EventRegistration? _registration;
  EventPaymentIntent? _intent;

  /// Set when completing the registration created a WEA account. Shown once.
  String? _temporaryPassword;

  /// How they are attending, on an event that offers both. Which *rate* that
  /// earns is not chosen here or anywhere else in the client: the date decides
  /// it, and the server is the only thing entitled to that opinion.
  EventAttendanceMode? _attendance;

  static const _steps = ['Information', 'Details', 'Review', 'Payment'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(eventActionsProvider)
          .recordPageView('/events/${widget.slug}/register');
      ref.read(eventActionsProvider).unawaitedReport(name: 'registration_started');
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _organisation,
      _jobTitle,
      _country,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fills the form from what WEA already holds, once the context arrives.
  void _prefill(EventRegistrationContext context) {
    if (_prefilled) return;
    _prefilled = true;
    final existing = context.existingRegistration;
    _firstName.text = existing?.firstName ?? context.known['first_name'] ?? '';
    _lastName.text = existing?.lastName ?? context.known['last_name'] ?? '';
    _email.text = existing?.email ?? context.known['email'] ?? '';
    _phone.text = existing?.phone ?? context.known['phone'] ?? '';
    _organisation.text =
        existing?.organisation ?? context.known['organisation'] ?? '';
    _jobTitle.text = existing?.jobTitle ?? context.known['job_title'] ?? '';
    _country.text = existing?.country ?? context.known['country'] ?? '';
    for (final field in context.fields) {
      final value = existing?.answers[field.fieldKey] ?? field.prefill ?? '';
      if (value.isNotEmpty) _answers[field.fieldKey] = value;
    }
    _registration = existing;
  }

  EventRegistrationDraft _draft({required bool complete}) =>
      EventRegistrationDraft(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        organisation: _organisation.text.trim(),
        jobTitle: _jobTitle.text.trim(),
        country: _country.text.trim(),
        answers: Map.of(_answers),
        complete: complete,
        source: 'EVENT_PAGE',
      );

  /// Saves whatever is filled in and moves on. The save happens first: if it
  /// fails, the registrant stays where they are with the reason shown.
  Future<void> _saveAndAdvance({required bool complete, required int next}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(eventActionsProvider)
          .save(widget.slug, _draft(complete: complete));
      if (!mounted) return;
      setState(() {
        _registration = saved.registration;
        // Shown once, on this screen only. It is also emailed, and it stops
        // working the moment they choose their own password.
        _temporaryPassword = saved.temporaryPassword ?? _temporaryPassword;
        // Kept for the change-password screen, so somebody who has just been
        // shown a generated password is not asked to type it back in.
        if (saved.temporaryPassword != null) {
          ref
              .read(issuedTemporaryPasswordProvider.notifier)
              .remember(saved.temporaryPassword);
        }
        _busy = false;
        _step = next;
      });
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _pay() async {
    final registration = _registration;
    if (registration == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(eventActionsProvider)
          .beginPayment(
            registration.reference,
            attendanceMode: _attendance?.wire,
          );
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _busy = false;
      });

      if (intent.hasCheckout) {
        final opened = await openCheckout(intent.checkoutUrl!);
        // A launch that fails and is ignored is what makes a payment button
        // look broken. If the browser refused it, say so and leave the link on
        // screen — pressing that is a fresh gesture, which nothing blocks.
        if (!opened && mounted) {
          setState(
            () => _error =
                'Your browser did not open the payment page. Use the button '
                'below to continue to it.',
          );
        }
      }
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.kind == EventFailureKind.alreadyPaid
            ? 'This registration has already been paid for.'
            : failure.message;
      });
      if (failure.kind == EventFailureKind.alreadyPaid) _goToRegistration();
    }
  }

  void _goToRegistration() {
    final reference = _registration?.reference;
    if (reference != null) context.go('/events/registration/$reference');
  }

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(eventRegistrationContextProvider(widget.slug));

    return WEAPublicPage(
      child: WEAContainer(
        maxWidth: 820,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: contextAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(WEAInsets.xxxl),
              child: WEALoading(label: 'Preparing registration'),
            ),
            error: (error, _) => WEAErrorState(
              message: error is EventFailure
                  ? error.message
                  : 'We could not open registration for this event.',
              onRetry: () =>
                  ref.invalidate(eventRegistrationContextProvider(widget.slug)),
            ),
            data: (data) {
              _prefill(data);
              if (!data.registrationOpen &&
                  data.existingRegistration == null) {
                return _ClosedNotice(event: data.event);
              }
              return _form(data);
            },
          ),
        ),
      ),
    );
  }

  Widget _form(EventRegistrationContext data) {
    final theme = Theme.of(context);
    final event = data.event;
    final paid = event.isPaid;
    // A free event has nothing to pay, so the payment step is not shown at all
    // rather than shown and skipped.
    final steps = paid ? _steps : _steps.sublist(0, 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WEABackButton(fallback: '/events/${event.slug}'),
        const SizedBox(height: WEAInsets.md),
        Text(event.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          '${formatEventDate(event.startsAt)} · ${event.feeLabel}',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: WEAColors.secondaryText,
          ),
        ),
        const SizedBox(height: WEAInsets.xl),
        RegistrationProgress(steps: steps, current: _step),
        const SizedBox(height: WEAInsets.xl),
        Container(
          padding: const EdgeInsets.all(WEAInsets.xl),
          decoration: BoxDecoration(
            color: WEAColors.card,
            border: Border.all(color: WEAColors.border),
            borderRadius: BorderRadius.circular(WEAInsets.radius),
          ),
          child: switch (_step) {
            0 => _detailsStep(data),
            1 => _contactStep(data),
            2 => _reviewStep(data),
            _ => _paymentStep(data),
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: WEAInsets.md),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: WEAColors.error),
              const SizedBox(width: WEAInsets.xs),
              Expanded(
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: WEAColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: WEAInsets.lg),
        Text(
          'WEA keeps only what you enter on this form. Card details are handled '
          'by the payment processor and never reach the academy.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  // --- Step 1: who you are ---------------------------------------------------

  Widget _detailsStep(EventRegistrationContext data) {
    final theme = Theme.of(context);
    final signedIn = ref.watch(authControllerProvider).isAuthenticated;
    final early = [
      for (final field in data.fields)
        if (field.askEarly) field,
    ];

    return Form(
      key: _detailsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.isReturning && data.firstName.isNotEmpty
                ? 'Welcome back, ${data.firstName}.'
                : 'Your details',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            data.isReturning
                ? 'We have used what WEA already holds. Change anything that is out of date.'
                : 'Just the essentials — you can pay on the next screen but one.',
            style: theme.textTheme.bodyMedium,
          ),
          if (data.registrationNote.isNotEmpty) ...[
            const SizedBox(height: WEAInsets.md),
            Container(
              padding: const EdgeInsets.all(WEAInsets.md),
              decoration: BoxDecoration(
                color: WEAColors.accent.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
              ),
              child: Text(
                data.registrationNote,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          if (!signedIn) ...[
            const SizedBox(height: WEAInsets.md),
            _SignInPrompt(slug: widget.slug),
          ],
          const SizedBox(height: WEAInsets.lg),
          _Field(
            controller: _firstName,
            label: 'First name',
            autofill: const [AutofillHints.givenName],
            validator: _required,
          ),
          _Field(
            controller: _lastName,
            label: 'Last name',
            autofill: const [AutofillHints.familyName],
            validator: _required,
          ),
          _Field(
            controller: _email,
            label: 'Email address',
            keyboardType: TextInputType.emailAddress,
            autofill: const [AutofillHints.email],
            // Signing in makes the address the account's, not the form's.
            enabled: !signedIn,
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'Please enter your email address.';
              if (!text.contains('@') || !text.contains('.')) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
          ),
          for (final field in early)
            _CustomField(
              field: field,
              value: _answers[field.fieldKey] ?? '',
              onChanged: (value) => _answers[field.fieldKey] = value,
            ),
          const SizedBox(height: WEAInsets.md),
          _StepActions(
            busy: _busy,
            nextLabel: 'CONTINUE',
            onNext: () {
              if (!(_detailsKey.currentState?.validate() ?? false)) return;
              // The record is created here, before anything else. From this
              // point the academy has the registration whatever happens next.
              _saveAndAdvance(complete: false, next: 1);
            },
          ),
        ],
      ),
    );
  }

  // --- Step 2: how to reach you ----------------------------------------------

  Widget _contactStep(EventRegistrationContext data) {
    final theme = Theme.of(context);
    final later = [
      for (final field in data.fields)
        if (!field.askEarly) field,
    ];

    return Form(
      key: _contactKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How we reach you', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'A telephone number so the academy can confirm your place.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: WEAInsets.lg),
          _Field(
            controller: _phone,
            label: 'Phone number',
            keyboardType: TextInputType.phone,
            autofill: const [AutofillHints.telephoneNumber],
            validator: _required,
          ),
          _Field(
            controller: _organisation,
            label: 'Organisation (optional)',
            autofill: const [AutofillHints.organizationName],
          ),
          _Field(controller: _jobTitle, label: 'Job title (optional)'),
          _Field(
            controller: _country,
            label: 'Country (optional)',
            autofill: const [AutofillHints.countryName],
          ),
          for (final field in later)
            _CustomField(
              field: field,
              value: _answers[field.fieldKey] ?? '',
              onChanged: (value) => _answers[field.fieldKey] = value,
            ),
          const SizedBox(height: WEAInsets.md),
          _StepActions(
            busy: _busy,
            nextLabel: 'REVIEW',
            onBack: () => setState(() => _step = 0),
            onNext: () {
              if (!(_contactKey.currentState?.validate() ?? false)) return;
              _saveAndAdvance(complete: false, next: 2);
            },
          ),
        ],
      ),
    );
  }

  // --- Step 3: check it over --------------------------------------------------

  Widget _reviewStep(EventRegistrationContext data) {
    final theme = Theme.of(context);
    final event = data.event;
    final paid = event.isPaid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review your registration', style: theme.textTheme.headlineSmall),
        const SizedBox(height: WEAInsets.lg),
        _ReviewRow(label: 'Event', value: event.title),
        _ReviewRow(
          label: 'Registrant',
          value: '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
        ),
        _ReviewRow(label: 'Email', value: _email.text.trim()),
        _ReviewRow(label: 'Phone', value: _phone.text.trim()),
        if (_organisation.text.trim().isNotEmpty)
          _ReviewRow(label: 'Organisation', value: _organisation.text.trim()),
        for (final field in data.fields)
          if ((_answers[field.fieldKey] ?? '').isNotEmpty)
            _ReviewRow(label: field.label, value: _answers[field.fieldKey]!),
        const Divider(height: WEAInsets.xl),
        Row(
          children: [
            Expanded(
              child: Text(
                'Registration fee',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              event.feeLabel,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: WEAColors.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: WEAInsets.md),
        CheckboxListTile(
          value: _accepted,
          onChanged: (value) => setState(() => _accepted = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'I confirm these details are correct and accept the terms of registration.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: WEAInsets.md),
        _StepActions(
          busy: _busy,
          nextLabel: paid ? 'CONTINUE TO PAYMENT' : 'COMPLETE REGISTRATION',
          onBack: () => setState(() => _step = 1),
          onNext: _accepted
              ? () async {
                  await _saveAndAdvance(complete: true, next: 3);
                  // A free event would normally go straight to the dashboard,
                  // but not past a temporary password shown only once.
                  if (!paid &&
                      mounted &&
                      _error == null &&
                      _temporaryPassword == null) {
                    _goToRegistration();
                  }
                }
              : null,
        ),
      ],
    );
  }

  // --- Step 4: payment --------------------------------------------------------

  Widget _paymentStep(EventRegistrationContext data) {
    final theme = Theme.of(context);
    final event = data.event;
    final registration = _registration;
    final intent = _intent;

    // The prices, and the methods that can settle each of them, both come from
    // the server. Watched once here so the amount shown and the methods
    // offered can never disagree about which currency is being paid in.
    final payment = ref.watch(
      eventPaymentMethodsProvider((
        slug: widget.slug,
        attendanceMode: _attendance?.wire,
      )),
    );

    final options = payment.value;

    // Once a payment has begun, the committed figure. Before that, whichever
    // of the academy's prices the payer has chosen — falling back to the base
    // price while the prices are still loading.
    final amountDue = intent != null
        ? formatMoney(intent.amount, intent.currency)
        : options?.price?.label ?? registration?.amountLabel ?? event.feeLabel;

    final rateLabel = options?.tierLabel ?? '';
    // Only worth saying before they have committed; afterwards the rate they
    // got is settled and a deadline is just noise.
    final rateCloses = intent == null ? options?.tierClosesAt : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Your registration is saved. It is confirmed once payment has been '
          'received and verified.',
          style: theme.textTheme.bodyMedium,
        ),
        if (_temporaryPassword != null) ...[
          const SizedBox(height: WEAInsets.lg),
          _AccountCreatedPanel(
            email: _registration?.email ?? _email.text.trim(),
            password: _temporaryPassword!,
          ),
        ],
        const SizedBox(height: WEAInsets.lg),
        Container(
          padding: const EdgeInsets.all(WEAInsets.lg),
          decoration: BoxDecoration(
            color: WEAColors.surfaceMuted,
            borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewRow(label: 'Event', value: event.title),
              _ReviewRow(
                label: 'Registrant',
                value: registration?.fullName ?? '',
              ),
              _ReviewRow(label: 'Reference', value: registration?.reference ?? ''),
              if (options?.mode case final mode?)
                _ReviewRow(label: 'Attending', value: mode.shortLabel),
              const Divider(height: WEAInsets.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amount due', style: theme.textTheme.titleMedium),
                        // Naming the rate matters: a registrant told only a
                        // number cannot tell whether they got the early price,
                        // nor why it will be different next week.
                        if (rateLabel.isNotEmpty)
                          Text(
                            rateLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: WEAColors.mutedText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(amountDue, style: theme.textTheme.headlineSmall),
                ],
              ),
              if (rateCloses != null)
                Padding(
                  padding: const EdgeInsets.only(top: WEAInsets.sm),
                  child: Text(
                    'This rate closes ${formatEventDate(rateCloses)}.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WEAColors.mutedText,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (intent != null && !intent.hasCheckout) ...[
          const SizedBox(height: WEAInsets.lg),
          Text('How to pay', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            intent.instructions.isEmpty
                ? 'The academy office will send payment instructions to '
                      '${registration?.email ?? 'your email address'}.'
                : intent.instructions,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: WEAInsets.md),
          Text(
            'Quote reference ${registration?.reference ?? ''} with your payment.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (intent == null) ...[
          const SizedBox(height: WEAInsets.lg),
          payment.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: WEAInsets.lg),
              child: LinearProgressIndicator(),
            ),
            error: (_, _) => const SizedBox.shrink(),
            // There is nothing to choose here any more. How to pay is asked
            // on Flutterwave's own checkout — card, transfer, USSD — which is
            // where the card is entered and where the list is accurate,
            // because it is the list that account actually supports.
            //
            // Only a hybrid event still has a question: which way of attending,
            // because that changes what is being bought. Each option shows its
            // own price so nobody has to switch to compare.
            data: (options) => options.hasModeChoice
                ? _AttendanceChoice(
                    options: options,
                    selected: _attendance ?? options.mode,
                    onSelected: (mode) => setState(() => _attendance = mode),
                  )
                : const SizedBox.shrink(),
          ),
        ],
        const SizedBox(height: WEAInsets.xl),
        if (intent == null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _pay,
              child: Text(
                _busy ? 'PREPARING PAYMENT…' : 'CONTINUE TO PAYMENT',
              ),
            ),
          )
        // A checkout was opened. It stays reachable from here because a
        // browser can refuse the automatic navigation, and because a payer who
        // came back without paying should not have to start again — pressing
        // this is a fresh gesture, which nothing blocks.
        else if (intent.hasCheckout) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => openCheckout(intent.checkoutUrl!),
              child: const Text('CONTINUE TO PAYMENT'),
            ),
          ),
          const SizedBox(height: WEAInsets.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _goToRegistration,
              child: const Text('VIEW MY REGISTRATION'),
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goToRegistration,
              child: const Text('VIEW MY REGISTRATION'),
            ),
          ),
        const SizedBox(height: WEAInsets.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: WEATextButton(
            label: 'Pay later',
            onPressed: _goToRegistration,
          ),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'This is required.' : null;
}

// --- Small pieces -------------------------------------------------------------

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
    this.autofill,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<String>? autofill;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: WEAInsets.md),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      autofillHints: autofill,
      enabled: enabled,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

/// A question the academy configured for this event.
class _CustomField extends StatelessWidget {
  const _CustomField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final EventRegistrationField field;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = field.required ? field.label : '${field.label} (optional)';

    if (field.type == EventFieldType.select && field.options.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: WEAInsets.md),
        child: DropdownButtonFormField<String>(
          initialValue: field.options.contains(value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            helperText: field.helpText.isEmpty ? null : field.helpText,
          ),
          items: [
            for (final option in field.options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          validator: field.required
              ? (selected) =>
                    (selected ?? '').isEmpty ? 'Please choose an option.' : null
              : null,
          onChanged: (selected) => onChanged(selected ?? ''),
        ),
      );
    }

    if (field.type == EventFieldType.checkbox) {
      return CheckboxListTile(
        value: value == 'true',
        onChanged: (checked) => onChanged(checked == true ? 'true' : ''),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.md),
      child: TextFormField(
        initialValue: value,
        maxLines: field.type == EventFieldType.textarea ? 4 : 1,
        keyboardType: field.type == EventFieldType.number
            ? TextInputType.number
            : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: field.helpText.isEmpty ? null : field.helpText,
        ),
        validator: field.required
            ? (input) =>
                  (input ?? '').trim().isEmpty ? 'This is required.' : null
            : null,
        onChanged: onChanged,
      ),
    );
  }
}

/// Lets the registrant say whether they are coming to the room or watching.
///
/// Only ever shown on a hybrid event, and it is the one thing about the price
/// the payer does decide. The currency is not offered as a choice — it follows
/// from where they are — but how they attend is a genuine difference in what
/// they are buying.
///
/// Each option carries its own price, because that difference is usually the
/// reason somebody is choosing at all, and making them switch back and forth
/// to compare would be a worse form of the same question.
class _AttendanceChoice extends StatelessWidget {
  const _AttendanceChoice({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final EventPaymentOptions options;
  final EventAttendanceMode? selected;
  final ValueChanged<EventAttendanceMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HOW WILL YOU ATTEND?',
          style: theme.textTheme.labelSmall?.copyWith(
            color: WEAColors.mutedText,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: WEAInsets.sm),
        for (final mode in options.attendanceModes)
          Padding(
            padding: const EdgeInsets.only(bottom: WEAInsets.xs),
            child: _AttendanceOption(
              mode: mode,
              selected: mode == selected,
              price: options.tierFor(mode)?.priceIn(options.currency)?.label,
              onTap: () => onSelected(mode),
            ),
          ),
      ],
    );
  }
}

class _AttendanceOption extends StatelessWidget {
  const _AttendanceOption({
    required this.mode,
    required this.selected,
    required this.price,
    required this.onTap,
  });

  final EventAttendanceMode mode;
  final bool selected;
  final String? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WEAInsets.md,
          vertical: WEAInsets.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? theme.colorScheme.primary : WEAColors.mutedText,
            ),
            const SizedBox(width: WEAInsets.sm),
            Expanded(
              child: Text(mode.label, style: theme.textTheme.bodyMedium),
            ),
            if (price != null)
              Text(
                price!,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? theme.colorScheme.primary : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The credentials created by completing a registration.
///
/// Shown here once and emailed at the same time, because a password that only
/// exists in a message nobody has received yet is a support call waiting to
/// happen. It is a temporary one: the account is flagged so it must be
/// replaced at first sign-in, and this value stops working then.
class _AccountCreatedPanel extends StatelessWidget {
  const _AccountCreatedPanel({required this.email, required this.password});

  final String email;
  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: WEAColors.success.withValues(alpha: .07),
        border: Border.all(color: WEAColors.success.withValues(alpha: .32)),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 20,
                color: WEAColors.success,
              ),
              const SizedBox(width: WEAInsets.xs),
              Text(
                'Your WEA account is ready',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: WEAColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: WEAInsets.xs),
          Text(
            'Registering created your account, so next time everything is '
            'filled in for you. We have emailed these details as well.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: WEAInsets.md),
          _Credential(label: 'Email', value: email),
          _Credential(label: 'Temporary password', value: password),
          const SizedBox(height: WEAInsets.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'You will choose your own password the first time you sign in.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: password));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: WEAColors.navy,
                        content: Text('Temporary password copied.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('COPY'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Credential extends StatelessWidget {
  const _Credential({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: WEAColors.mutedText,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepActions extends StatelessWidget {
  const _StepActions({
    required this.busy,
    required this.nextLabel,
    required this.onNext,
    this.onBack,
  });

  final bool busy;
  final String nextLabel;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onBack != null)
        TextButton(onPressed: busy ? null : onBack, child: const Text('BACK')),
      const Spacer(),
      ElevatedButton(
        onPressed: busy ? null : onNext,
        child: Text(busy ? 'SAVING…' : nextLabel),
      ),
    ],
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: WEAColors.mutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Offered, never required: an account makes the next registration shorter,
/// but insisting on one before we know a visitor's name is how registrations
/// are lost.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(WEAInsets.md),
    decoration: BoxDecoration(
      color: WEAColors.surfaceMuted,
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
    ),
    child: Row(
      children: [
        const Icon(Icons.person_outline, size: 18, color: WEAColors.accent),
        const SizedBox(width: WEAInsets.xs),
        Expanded(
          child: Text(
            'Already registered with WEA? Sign in and we will fill this in for you.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        WEAOutlinedButton(
          label: 'SIGN IN',
          compact: true,
          onPressed: () => context.go('/login'),
        ),
      ],
    ),
  );
}

class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice({required this.event});

  final WeaEvent event;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(event.title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: WEAInsets.md),
      Text(
        'Registration for this event is not currently open. '
        'Please check the event page for the next intake.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: WEAInsets.lg),
      WEAOutlinedButton(
        label: 'BACK TO EVENT',
        onPressed: () => context.go('/events/${event.slug}'),
      ),
    ],
  );
}

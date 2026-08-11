import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/widgets/wea_public_widgets.dart';
import '../../authentication/application/auth_controller.dart';
import '../application/catalogue_providers.dart';
import '../data/catalogue_repository.dart';
import '../domain/catalogue_models.dart';
import '../domain/registration_models.dart';
import 'widgets/catalogue_cards.dart';

/// Programme registration.
///
/// A returning applicant is never asked again for anything WEA already holds:
/// the account is the profile, so the form confirms what is on file and asks
/// only the programme-specific questions that remain.
class RegistrationScreen extends ConsumerWidget {
  const RegistrationScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programmeDetailProvider(slug));
    final signedIn = ref.watch(authControllerProvider).isAuthenticated;

    return WEAPublicPage(
      child: WEAContainer(
        maxWidth: 900,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: CatalogueAsync(
            value: detail,
            onRetry: () => ref.invalidate(programmeDetailProvider(slug)),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WEATextButton(
                  label: '← Back to programme',
                  onPressed: () => context.go('/programmes/$slug'),
                ),
                const SizedBox(height: WEAInsets.sm),
                WEASectionHeading(
                  eyebrow: 'REGISTRATION',
                  title: data.programme.title,
                  description:
                      '${data.programme.typeTitle} · ${data.programme.durationLabel} · ${data.programme.tuitionLabel}',
                ),
                const SizedBox(height: WEAInsets.xl),
                if (!signedIn)
                  const _SignInPrompt()
                else
                  _RegistrationForm(programme: data.programme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Registration requires an account, because the account *is* the applicant
/// record that later registrations reuse.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: WEAColors.surfaceMuted,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('One WEA profile, every programme',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: WEAInsets.xs),
          Text(
            'Sign in or create your WEA account first. Your details are then '
            'reused for every future registration, so you only ever enter them '
            'once.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: WEAInsets.lg),
          Wrap(
            spacing: WEAInsets.sm,
            runSpacing: WEAInsets.sm,
            children: [
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('SIGN IN'),
                ),
              ),
              WEAOutlinedButton(
                label: 'CREATE ACCOUNT',
                onPressed: () => context.go('/register'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegistrationForm extends ConsumerStatefulWidget {
  const _RegistrationForm({required this.programme});

  final CatalogueProgramme programme;

  @override
  ConsumerState<_RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends ConsumerState<_RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  String? _paymentMethodId;
  var _submitting = false;
  String? _error;
  RegistrationRecord? _submitted;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(RegistrationField field) =>
      _controllers.putIfAbsent(
        field.fieldKey,
        // Seeded from the applicant's previous answer where there is one, so a
        // returning applicant confirms rather than retypes.
        () => TextEditingController(text: field.prefill ?? ''),
      );

  Future<void> _submit(List<RegistrationField> fields) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final record = await ref
          .read(catalogueActionsProvider)
          .register(
            programmeId: widget.programme.id,
            answers: {
              for (final field in fields)
                field.fieldKey: _controllers[field.fieldKey]?.text.trim() ?? '',
            },
            paymentMethodId: _paymentMethodId,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = record;
      });
    } on CatalogueFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _submitted;
    if (submitted != null) {
      return _Confirmation(
        record: submitted,
        paymentMethodId: _paymentMethodId,
      );
    }

    final context$ = ref.watch(
      registrationContextProvider(widget.programme.id),
    );

    return CatalogueAsync(
      value: context$,
      onRetry: () =>
          ref.invalidate(registrationContextProvider(widget.programme.id)),
      data: (data) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KnownDetails(context: data),
            const SizedBox(height: WEAInsets.xl),
            if (data.fields.isNotEmpty) ...[
              Text(
                'A few programme details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: WEAInsets.md),
              for (final field in data.fields) ...[
                _FieldInput(field: field, controller: _controllerFor(field)),
                const SizedBox(height: WEAInsets.md),
              ],
            ],
            const SizedBox(height: WEAInsets.sm),
            _PaymentChoice(
              selected: _paymentMethodId,
              onSelected: (id) => setState(() => _paymentMethodId = id),
            ),
            if (_error != null) ...[
              const SizedBox(height: WEAInsets.md),
              Container(
                padding: const EdgeInsets.all(WEAInsets.sm),
                decoration: BoxDecoration(
                  color: WEAColors.error.withValues(alpha: .08),
                  border: Border.all(
                    color: WEAColors.error.withValues(alpha: .32),
                  ),
                  borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: WEAColors.error,
                    ),
                    const SizedBox(width: WEAInsets.xs),
                    Expanded(
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: WEAInsets.xl),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _submit(data.fields),
                child: Text(
                  _submitting ? 'SUBMITTING…' : 'SUBMIT REGISTRATION',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What WEA already holds, shown as confirmed rather than asked again.
class _KnownDetails extends StatelessWidget {
  const _KnownDetails({required this.context});

  final RegistrationContext context;

  @override
  Widget build(BuildContext buildContext) {
    final theme = Theme.of(buildContext);
    final name = context.firstName;
    final labels = {
      'first_name': 'First name',
      'last_name': 'Last name',
      'email': 'Email',
      'phone': 'Phone',
      'country': 'Country',
    };

    return Container(
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: WEAColors.surfaceMuted,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: WEAColors.accent,
              ),
              const SizedBox(width: WEAInsets.xs),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Your WEA profile' : 'Welcome back, $name.',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: WEAInsets.xs),
          Text(
            'We already have your WEA profile. These details will be reused for '
            'this registration — you do not need to enter them again.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: WEAInsets.md),
          Wrap(
            spacing: WEAInsets.xl,
            runSpacing: WEAInsets.sm,
            children: [
              for (final entry in labels.entries)
                if ((context.known[entry.key] ?? '').isNotEmpty)
                  SizedBox(
                    width: 210,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: WEAColors.mutedText,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          context.known[entry.key]!,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
          if (context.missingProfile.isNotEmpty) ...[
            const SizedBox(height: WEAInsets.md),
            Text(
              'Add your ${context.missingProfile.map((key) => labels[key]?.toLowerCase() ?? key).join(', ')} '
              'to your profile so future registrations are even shorter.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: WEAInsets.md),
          WEATextButton(
            label: 'Update my profile',
            onPressed: () => buildContext.go('/profile'),
          ),
        ],
      ),
    );
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({required this.field, required this.controller});

  final RegistrationField field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    String? validate(String? value) =>
        field.required && (value?.trim().isEmpty ?? true)
        ? 'Please provide your ${field.label.toLowerCase()}.'
        : null;

    if (field.type == RegistrationFieldType.select &&
        field.options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: field.options.contains(controller.text)
            ? controller.text
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.helpText.isEmpty ? null : field.helpText,
        ),
        items: [
          for (final option in field.options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) => controller.text = value ?? '',
        validator: validate,
      );
    }

    return TextFormField(
      controller: controller,
      maxLines: field.type == RegistrationFieldType.textarea ? 4 : 1,
      minLines: field.type == RegistrationFieldType.textarea ? 3 : 1,
      keyboardType: field.type == RegistrationFieldType.number
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helpText.isEmpty ? null : field.helpText,
      ),
      validator: validate,
    );
  }
}

class _PaymentChoice extends ConsumerWidget {
  const _PaymentChoice({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    final theme = Theme.of(context);

    return methods.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (available) {
        if (available.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How would you like to pay?',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: WEAInsets.sm),
            for (final method in available)
              Semantics(
                inMutuallyExclusiveGroup: true,
                selected: selected == method.id,
                child: ListTile(
                  onTap: () => onSelected(method.id),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected == method.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected == method.id
                        ? WEAColors.accent
                        : WEAColors.mutedText,
                  ),
                  title: Text(method.title),
                  subtitle: Text(
                    method.instructions,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Post-submission: the reference and how to pay against it.
class _Confirmation extends ConsumerWidget {
  const _Confirmation({required this.record, required this.paymentMethodId});

  final RegistrationRecord record;
  final String? paymentMethodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final method = ref
        .watch(paymentMethodsProvider)
        .value
        ?.where((item) => item.id == paymentMethodId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(WEAInsets.lg),
          decoration: BoxDecoration(
            color: WEAColors.navy,
            borderRadius: BorderRadius.circular(WEAInsets.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REGISTRATION RECEIVED',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: WEAColors.accentSoft,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: WEAInsets.sm),
              Text(
                record.programmeTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: WEAColors.offWhite,
                ),
              ),
              const SizedBox(height: WEAInsets.md),
              Text(
                'YOUR REFERENCE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: WEAColors.offWhite.withValues(alpha: .7),
                  letterSpacing: 1.4,
                ),
              ),
              SelectableText(
                record.reference,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: WEAColors.offWhite,
                ),
              ),
              const SizedBox(height: WEAInsets.xs),
              Text(
                'Quote this reference on any payment or correspondence.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: WEAColors.offWhite.withValues(alpha: .82),
                ),
              ),
            ],
          ),
        ),
        if (method != null) ...[
          const SizedBox(height: WEAInsets.lg),
          Container(
            padding: const EdgeInsets.all(WEAInsets.lg),
            decoration: BoxDecoration(
              border: Border.all(color: WEAColors.border),
              borderRadius: BorderRadius.circular(WEAInsets.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment instructions',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: WEAInsets.sm),
                Text(method.instructions, style: theme.textTheme.bodyLarge),
                if (method.hasBankDetails) ...[
                  const SizedBox(height: WEAInsets.md),
                  for (final (label, value) in method.bankDetails)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(
                              label.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: WEAColors.mutedText,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              value,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (method.gatewayCheckoutUrl.isNotEmpty) ...[
                  const SizedBox(height: WEAInsets.md),
                  Text(
                    'You will be directed to ${method.gatewayProvider} to complete payment.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: WEAInsets.lg),
        Text(
          'The programme office will confirm your place once payment is matched '
          'to your reference. You can follow progress from your WEA account.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: WEAInsets.lg),
        Wrap(
          spacing: WEAInsets.sm,
          runSpacing: WEAInsets.sm,
          children: [
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => context.go('/learner'),
                child: const Text('GO TO MY ACCOUNT'),
              ),
            ),
            WEAOutlinedButton(
              label: 'BROWSE MORE PROGRAMMES',
              onPressed: () => context.go('/programmes'),
            ),
          ],
        ),
      ],
    );
  }
}

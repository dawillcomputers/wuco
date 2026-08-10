import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../application/auth_controller.dart';
import '../domain/auth_state.dart';
import '../domain/password_policy.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _country = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  var _acceptedTerms = false;
  var _showTermsError = false;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _country,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() => _showTermsError = !_acceptedTerms);
    if (!formValid || !_acceptedTerms) return;

    await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _email.text,
          password: _password.text,
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          country: _country.text.trim().isEmpty ? null : _country.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth is AuthLoading;
    final theme = Theme.of(context);

    return AuthScaffold(
      eyebrow: 'CREATE ACCOUNT',
      title: 'Create your WEA account',
      subtitle:
          'Join WUCO Executive Academy and begin your executive learning journey.',
      panelPoints: const [
        'Enrol in executive certificate programmes',
        'Build a verified professional learning record',
        'Join a Pan-African network of senior leaders',
      ],
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (auth is AuthError) AuthErrorBanner(failure: auth.failure),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Please enter your first name.'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                    ),
                  ),
                  const SizedBox(width: WEAInsets.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Please enter your last name.'
                          : null,
                      decoration: const InputDecoration(labelText: 'Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.md),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: validateEmail,
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              const SizedBox(height: WEAInsets.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                      ),
                    ),
                  ),
                  const SizedBox(width: WEAInsets.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _country,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.countryName],
                      decoration: const InputDecoration(labelText: 'Country'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.md),
              AuthPasswordField(
                label: 'Password',
                controller: _password,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                validator: PasswordPolicy.validate,
              ),
              PasswordStrengthMeter(password: _password.text),
              const SizedBox(height: WEAInsets.md),
              AuthPasswordField(
                label: 'Confirm password',
                controller: _confirm,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                validator: (value) => value != _password.text
                    ? 'Passwords do not match.'
                    : null,
              ),
              const SizedBox(height: WEAInsets.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (value) => setState(() {
                      _acceptedTerms = value ?? false;
                      if (_acceptedTerms) _showTermsError = false;
                    }),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('I accept the ', style: theme.textTheme.bodyMedium),
                          InkWell(
                            onTap: () => context.go('/terms'),
                            child: Text(
                              'Terms and Conditions',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: WEAColors.accent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(' and ', style: theme.textTheme.bodyMedium),
                          InkWell(
                            onTap: () => context.go('/privacy'),
                            child: Text(
                              'Privacy Policy',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: WEAColors.accent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text('.', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_showTermsError)
                Padding(
                  padding: const EdgeInsets.only(left: WEAInsets.md),
                  child: Text(
                    'Please accept the terms to continue.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WEAColors.error,
                    ),
                  ),
                ),
              const SizedBox(height: WEAInsets.md),
              AuthSubmitButton(
                label: 'CREATE ACCOUNT',
                busyLabel: 'Creating account…',
                busy: busy,
                onPressed: _submit,
              ),
              const SizedBox(height: WEAInsets.md),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already registered? Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

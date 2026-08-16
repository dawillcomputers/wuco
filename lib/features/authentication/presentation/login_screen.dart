import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../application/auth_controller.dart';
import '../domain/auth_state.dart';
import 'auth_scaffold.dart';
import 'widgets/social_sign_in_section.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _rememberMe = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    // Navigation is handled by the router guard reacting to the new state.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth is AuthLoading;

    return AuthScaffold(
      eyebrow: 'ACCOUNT ACCESS',
      title: 'Welcome back',
      subtitle: 'Sign in to continue to WUCO Executive Academy.',
      panelPoints: const [
        'Continue your executive certificate programmes',
        'Review your verified learning record',
        'Stay connected to the WUCO Professional Network',
      ],
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (auth is AuthError)
                AuthErrorBanner(
                  failure: auth.failure,
                  onRetry: busy ? null : _submit,
                ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: validateEmail,
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              const SizedBox(height: WEAInsets.md),
              AuthPasswordField(
                label: 'Password',
                controller: _password,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: _submit,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter your password.'
                    : null,
              ),
              const SizedBox(height: WEAInsets.xs),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) =>
                        setState(() => _rememberMe = value ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Remember me',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.md),
              AuthSubmitButton(
                label: 'SIGN IN',
                busyLabel: 'Signing in…',
                busy: busy,
                onPressed: _submit,
              ),
              // Renders nothing unless the deployment has a provider
              // configured. Navigation is left to the router guard, exactly as
              // for the password form.
              const SocialSignInSection(),
              const SizedBox(height: WEAInsets.lg),
              Row(
                children: [
                  const Expanded(child: Divider(color: WEAColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WEAInsets.sm,
                    ),
                    child: Text(
                      "DON'T HAVE AN ACCOUNT",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: WEAColors.mutedText,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: WEAColors.border)),
                ],
              ),
              const SizedBox(height: WEAInsets.xs),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('CREATE ACCOUNT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

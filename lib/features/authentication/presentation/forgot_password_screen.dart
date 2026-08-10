import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../application/auth_controller.dart';
import '../domain/auth_state.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  var _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth is AuthLoading;
    final theme = Theme.of(context);

    return AuthScaffold(
      eyebrow: 'PASSWORD RECOVERY',
      title: 'Reset your password',
      subtitle:
          "Enter your email address and we'll send you instructions to reset your password.",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (auth is AuthError) AuthErrorBanner(failure: auth.failure),
            if (_sent)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: WEAInsets.md),
                padding: const EdgeInsets.all(WEAInsets.md),
                decoration: BoxDecoration(
                  color: WEAColors.success.withValues(alpha: .06),
                  border: Border.all(
                    color: WEAColors.success.withValues(alpha: .35),
                  ),
                  borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 18,
                      color: WEAColors.success,
                    ),
                    const SizedBox(width: WEAInsets.xs),
                    Expanded(
                      child: Text(
                        // Deliberately does not confirm whether the address is
                        // registered.
                        'If an account exists for that address, reset '
                        'instructions are on their way.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: validateEmail,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: WEAInsets.lg),
            AuthSubmitButton(
              label: 'SEND RESET LINK',
              busyLabel: 'Sending reset link…',
              busy: busy,
              onPressed: _submit,
            ),
            const SizedBox(height: WEAInsets.md),
            Center(
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Return to sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

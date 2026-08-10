import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../application/auth_controller.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_state.dart';
import '../domain/password_policy.dart';
import 'auth_scaffold.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  /// Supplied by the emailed link as `?token=`.
  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _done = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(token: widget.token, newPassword: _password.text);
    if (ok && mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth is AuthLoading;
    final theme = Theme.of(context);

    if (_done) {
      return AuthScaffold(
        eyebrow: 'PASSWORD UPDATED',
        title: 'Your password is set',
        subtitle: 'You can now sign in with your new password.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthSubmitButton(
              label: 'RETURN TO LOGIN',
              busyLabel: '',
              busy: false,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      eyebrow: 'PASSWORD RECOVERY',
      title: 'Choose a new password',
      subtitle: 'Set a new password for your WEA account.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.token.isEmpty)
              const AuthErrorBanner(
                failure: AuthFailure(AuthFailureKind.invalidLink),
              )
            else if (auth is AuthError)
              AuthErrorBanner(failure: auth.failure),
            AuthPasswordField(
              label: 'New password',
              controller: _password,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              validator: PasswordPolicy.validate,
            ),
            PasswordStrengthMeter(password: _password.text),
            const SizedBox(height: WEAInsets.md),
            AuthPasswordField(
              label: 'Confirm new password',
              controller: _confirm,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
              validator: (value) =>
                  value != _password.text ? 'Passwords do not match.' : null,
            ),
            const SizedBox(height: WEAInsets.lg),
            AuthSubmitButton(
              label: 'UPDATE PASSWORD',
              busyLabel: 'Updating password…',
              busy: busy,
              onPressed: widget.token.isEmpty ? () {} : _submit,
            ),
            const SizedBox(height: WEAInsets.md),
            Center(
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: Text(
                  'Request a new link',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: WEAColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

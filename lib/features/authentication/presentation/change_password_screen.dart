import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../application/auth_controller.dart';
import '../domain/auth_state.dart';
import '../domain/password_policy.dart';
import 'auth_scaffold.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .changePassword(
          currentPassword: _current.text,
          newPassword: _password.text,
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your password has been updated.')),
      );
      final profile = ref.read(currentProfileProvider);
      if (profile != null) context.go(profile.role.landingRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth is AuthLoading;
    final mustChange = auth.profile?.mustChangePassword ?? false;

    return AuthScaffold(
      eyebrow: 'ACCOUNT SECURITY',
      title: mustChange ? 'Set your password' : 'Change your password',
      subtitle: mustChange
          ? 'Your account uses a temporary password. Choose a new one to continue.'
          : 'Choose a new password for your WEA account.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (auth is AuthError) AuthErrorBanner(failure: auth.failure),
            AuthPasswordField(
              label: mustChange ? 'Temporary password' : 'Current password',
              controller: _current,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Please enter your current password.'
                  : null,
            ),
            const SizedBox(height: WEAInsets.md),
            AuthPasswordField(
              label: 'New password',
              controller: _password,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final policy = PasswordPolicy.validate(value);
                if (policy != null) return policy;
                if (value == _current.text) {
                  return 'Choose a password you have not used before.';
                }
                return null;
              },
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
              onPressed: _submit,
            ),
            if (!mustChange) ...[
              const SizedBox(height: WEAInsets.md),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/profile'),
                  child: const Text('Back to profile'),
                ),
              ),
            ] else ...[
              const SizedBox(height: WEAInsets.md),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) context.go('/login');
                  },
                  child: Text(
                    'Sign out instead',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: WEAColors.mutedText,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_dimensions.dart';
import '../application/auth_controller.dart';
import '../domain/auth_state.dart';
import 'auth_scaffold.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.token});

  /// Present when arriving from the emailed link.
  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _cooldownSeconds = 45;

  Timer? _timer;
  var _remaining = 0;

  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (token != null && token.isNotEmpty) {
      Future.microtask(
        () => ref.read(authControllerProvider.notifier).verifyEmail(token),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Rate limits resends so the endpoint cannot be hammered.
  void _startCooldown() {
    setState(() => _remaining = _cooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    if (_remaining > 0) return;
    await ref.read(authControllerProvider.notifier).resendVerification();
    _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth is AuthLoading;
    final email = auth.profile?.email;

    return AuthScaffold(
      eyebrow: 'EMAIL VERIFICATION',
      title: 'Verify your email',
      subtitle: email == null
          ? "We've sent a verification link to your email address."
          : "We've sent a verification link to $email.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (auth is AuthError) AuthErrorBanner(failure: auth.failure),
          AuthSubmitButton(
            label: _remaining > 0
                ? 'RESEND AVAILABLE IN ${_remaining}S'
                : 'RESEND EMAIL',
            busyLabel: 'Sending…',
            busy: busy,
            onPressed: _remaining > 0 ? () {} : _resend,
          ),
          const SizedBox(height: WEAInsets.md),
          Center(
            child: TextButton(
              onPressed: () => context.go('/register'),
              child: const Text('Change email address'),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Back to sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/auth_controller.dart';
import '../../data/auth_repository.dart';
import '../../data/social_sign_in.dart';
import 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart';

/// The providers this deployment can complete a sign-in with.
///
/// Asked of the API rather than assumed, so an academy that has not configured
/// Google is not shown a button that cannot work.
final socialProvidersProvider = FutureProvider<List<SocialProvider>>(
  (ref) => ref.watch(authRepositoryProvider).socialProviders(),
);

/// "Continue with Google", where the deployment supports it.
///
/// Renders nothing at all when no provider is configured — including the
/// divider, because a rule across an empty space is worse than no rule.
class SocialSignInSection extends ConsumerStatefulWidget {
  const SocialSignInSection({super.key, this.onSignedIn});

  /// Called after a successful sign-in, so the screen can navigate.
  final VoidCallback? onSignedIn;

  @override
  ConsumerState<SocialSignInSection> createState() =>
      _SocialSignInSectionState();
}

class _SocialSignInSectionState extends ConsumerState<SocialSignInSection> {
  StreamSubscription<String>? _tokens;
  bool _busy = false;

  @override
  void dispose() {
    _tokens?.cancel();
    super.dispose();
  }

  /// Starts listening for the web flow's result.
  ///
  /// Google's rendered button reports its sign-in on a stream rather than by
  /// returning from a call, so on the web this subscription is the only way
  /// the result ever arrives.
  void _listen() {
    _tokens ??= SocialSignIn.instance.idTokens.listen((idToken) {
      _exchange(idToken);
    });
  }

  Future<void> _exchange(String idToken) async {
    if (_busy) return;
    setState(() => _busy = true);
    final signedIn = await ref
        .read(authControllerProvider.notifier)
        .signInWithProvider(provider: 'GOOGLE', idToken: idToken);
    if (!mounted) return;
    setState(() => _busy = false);
    if (signedIn) widget.onSignedIn?.call();
  }

  Future<void> _prompt() async {
    setState(() => _busy = true);
    try {
      final idToken = await SocialSignIn.instance.authenticate();
      if (!mounted) return;
      setState(() => _busy = false);
      // Null means the account chooser was closed, which is a decision and
      // not something to report as a failure.
      if (idToken != null) await _exchange(idToken);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ref
        .watch(socialProvidersProvider)
        .when(
          // Silent while it loads and if it fails: the password form is right
          // there, and a spinner or an error above it would only be noise.
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (providers) {
            final google = providers
                .where((provider) => provider.provider == 'GOOGLE')
                .firstOrNull;
            if (google == null || google.clientId.isEmpty) {
              return const SizedBox.shrink();
            }

            return FutureBuilder<void>(
              future: SocialSignIn.instance.ensureInitialised(google.clientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                if (snapshot.hasError) return const SizedBox.shrink();
                _listen();

                return Column(
                  children: [
                    const SizedBox(height: WEAInsets.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: WEAInsets.md,
                          ),
                          child: Text(
                            'OR',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: WEAColors.mutedText,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: WEAInsets.lg),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: WEAInsets.sm),
                        child: LinearProgressIndicator(),
                      )
                    else if (SocialSignIn.instance.canPrompt)
                      // Our own button, where the platform lets us start the
                      // flow ourselves.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _prompt,
                          icon: const Icon(Icons.account_circle_outlined),
                          label: Text(google.label),
                        ),
                      )
                    else
                      // Google's own button. On the web this is the only way
                      // in: Identity Services will not start a sign-in from
                      // anything else, and it cannot be restyled.
                      Align(
                        alignment: Alignment.center,
                        child: googleRenderedButton(),
                      ),
                  ],
                );
              },
            );
          },
        );
  }
}

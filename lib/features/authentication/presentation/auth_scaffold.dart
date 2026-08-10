import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_brand.dart';
import '../domain/auth_failure.dart';
import '../domain/password_policy.dart';

/// Shared composition for every authentication page: a navy brand panel beside
/// a white form column, collapsing to a compact banner above the form on
/// smaller screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.panelPoints = const [],
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final List<String> panelPoints;

  static const _splitBreakpoint = 980.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final split = width >= _splitBreakpoint;

    final form = _AuthFormColumn(
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      child: child,
    );

    return Scaffold(
      backgroundColor: WEAColors.background,
      body: split
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _BrandPanel(points: panelPoints)),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WEAInsets.xxl,
                      vertical: WEAInsets.sectionSmall,
                    ),
                    child: Center(child: form),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandPanel(points: [], compact: true),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      width < 600
                          ? WEAInsets.mobilePageHorizontal
                          : WEAInsets.xxl,
                      WEAInsets.xxl,
                      width < 600
                          ? WEAInsets.mobilePageHorizontal
                          : WEAInsets.xxl,
                      WEAInsets.xxl,
                    ),
                    child: form,
                  ),
                ],
              ),
            ),
    );
  }
}

class _AuthFormColumn extends StatelessWidget {
  const _AuthFormColumn({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eyebrow,
            style: theme.textTheme.labelMedium?.copyWith(
              color: WEAColors.accent,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: WEAInsets.sm),
          Text(title, style: theme.textTheme.headlineLarge),
          const SizedBox(height: WEAInsets.sm),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: WEAInsets.xl),
          child,
          const SizedBox(height: WEAInsets.lg),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('← Back to WEA'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: .02, end: 0);
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.points, this.compact = false});

  final List<String> points;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        // A restrained navy gradient rather than a flat block, per the brief's
        // guidance on using blue gradients sparingly.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WEAColors.navy, WEAColors.navyDeep],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? WEAInsets.lg : WEAInsets.section,
          vertical: compact ? WEAInsets.xl : WEAInsets.section,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => context.go('/'),
              child: WEABrandLockup(height: compact ? 76 : 132, onDark: true),
            ),
            SizedBox(height: compact ? WEAInsets.lg : WEAInsets.xxl),
            Container(height: 1, width: 46, color: WEAColors.accentSoft),
            SizedBox(height: compact ? WEAInsets.md : WEAInsets.lg),
            Text(
              "Where Africa's\nLeaders Are Formed",
              style: theme.textTheme.displayMedium?.copyWith(
                color: WEAColors.offWhite,
                fontSize: compact ? 28 : 42,
                height: 1.06,
                fontWeight: FontWeight.w600,
                letterSpacing: -.5,
              ),
            ),
            if (!compact && points.isNotEmpty) ...[
              const SizedBox(height: WEAInsets.xl),
              for (final point in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: WEAInsets.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        height: 1,
                        width: 14,
                        color: WEAColors.accentSoft,
                      ),
                      const SizedBox(width: WEAInsets.sm),
                      Expanded(
                        child: Text(
                          point,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: WEAColors.offWhite.withValues(alpha: .80),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (!compact) ...[
              const SizedBox(height: WEAInsets.xxl),
              Text(
                'BACKED BY THE WORLD UNITED CONSUMER ORGANISATION',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: WEAColors.offWhite.withValues(alpha: .55),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline failure notice. Errors are announced by icon and text, never by
/// colour alone.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.failure, this.onRetry});

  final AuthFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: WEAInsets.md),
      padding: const EdgeInsets.all(WEAInsets.sm),
      decoration: BoxDecoration(
        color: WEAColors.error.withValues(alpha: .06),
        border: Border.all(color: WEAColors.error.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: WEAColors.error),
          const SizedBox(width: WEAInsets.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failure.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WEAColors.error,
                  ),
                ),
                if (failure.isRetryable && onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('TRY AGAIN')),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Text field with a visibility toggle, used for every password input.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  var _obscured = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscured,
    validator: widget.validator,
    textInputAction: widget.textInputAction,
    autofillHints: widget.autofillHints,
    onChanged: widget.onChanged,
    onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        tooltip: _obscured ? 'Show password' : 'Hide password',
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: WEAColors.mutedText,
        ),
      ),
    ),
  );
}

/// Live strength feedback plus the outstanding requirements in words.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final score = PasswordPolicy.strength(password);
    final colour = score < .4
        ? WEAColors.error
        : score < .7
        ? WEAColors.warning
        : WEAColors.success;

    return Padding(
      padding: const EdgeInsets.only(top: WEAInsets.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: score,
                    minHeight: 4,
                    backgroundColor: WEAColors.elevated,
                    valueColor: AlwaysStoppedAnimation(colour),
                  ),
                ),
              ),
              const SizedBox(width: WEAInsets.sm),
              Text(
                PasswordPolicy.strengthLabel(password),
                style: theme.textTheme.labelSmall?.copyWith(color: colour),
              ),
            ],
          ),
          const SizedBox(height: WEAInsets.xs),
          for (final rule in PasswordPolicy.checklist(password))
            Row(
              children: [
                Icon(
                  rule.satisfied
                      ? Icons.check_circle_outline
                      : Icons.circle_outlined,
                  size: 13,
                  color: rule.satisfied
                      ? WEAColors.success
                      : WEAColors.mutedText,
                ),
                const SizedBox(width: 6),
                Text(
                  rule.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: rule.satisfied
                        ? WEAColors.secondaryText
                        : WEAColors.mutedText,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Full-width primary action that shows progress and refuses double taps.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: WEAInsets.sm),
                Text(busyLabel),
              ],
            )
          : Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
    ),
  );
}

/// Shared email validation so every screen rejects the same inputs.
String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Please enter your email address.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
    return 'Please enter a valid email address.';
  }
  return null;
}

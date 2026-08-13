import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/event_models.dart';

/// Lets a payer choose how to pay.
///
/// The list is decided by the server, which intersects what the academy
/// enabled on the event with what the deployment's credentials and the
/// processor actually support. Nothing is listed here that cannot complete:
/// showing a method and then failing on it is worse than not offering it.
///
/// No key, token or processor credential reaches this widget. It renders a
/// list of names and reports which one was chosen.
class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.methods,
    required this.selected,
    required this.onSelected,
    this.environment = '',
  });

  final List<EventPaymentMethod> methods;
  final String? selected;
  final ValueChanged<String> onSelected;

  /// `SANDBOX` or `PRODUCTION`, so a test payment says so plainly.
  final String environment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (methods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(WEAInsets.md),
        decoration: BoxDecoration(
          color: WEAColors.warning.withValues(alpha: .07),
          border: Border.all(color: WEAColors.warning.withValues(alpha: .32)),
          borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: WEAColors.warning),
            const SizedBox(width: WEAInsets.xs),
            Expanded(
              child: Text(
                'Online payment is not available for this event yet. Your '
                'registration is saved, and the academy office will be in '
                'touch with payment instructions.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PAYMENT METHOD',
              style: theme.textTheme.labelSmall?.copyWith(
                color: WEAColors.mutedText,
                letterSpacing: 1.3,
              ),
            ),
            const Spacer(),
            // A test payment must never be mistaken for a real one.
            if (environment.toUpperCase() == 'SANDBOX')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: WEAColors.warning.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'TEST MODE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: WEAColors.warning,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: WEAInsets.sm),
        for (final method in methods)
          _MethodTile(
            method: method,
            selected: selected == method.key,
            onTap: () => onSelected(method.key),
          ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final EventPaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (method.key) {
    'card' => Icons.credit_card,
    'bank_transfer' => Icons.account_balance_outlined,
    'bank_account' => Icons.account_balance_wallet_outlined,
    'ussd' => Icons.dialpad,
    'opay' => Icons.smartphone_outlined,
    'nqr' => Icons.qr_code_2,
    _ => Icons.payments_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
        child: Container(
          padding: const EdgeInsets.all(WEAInsets.md),
          decoration: BoxDecoration(
            color: selected
                ? WEAColors.accent.withValues(alpha: .06)
                : WEAColors.card,
            border: Border.all(
              color: selected ? WEAColors.accent : WEAColors.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                size: 22,
                color: selected ? WEAColors.accent : WEAColors.mutedText,
              ),
              const SizedBox(width: WEAInsets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: selected
                            ? WEAColors.primaryText
                            : WEAColors.secondaryText,
                      ),
                    ),
                    if (method.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        method.description,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? WEAColors.accent : WEAColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

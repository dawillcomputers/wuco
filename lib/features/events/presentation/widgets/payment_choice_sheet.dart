import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/services/checkout_launcher.dart';
import '../../application/events_providers.dart';
import '../../data/events_repository.dart';
import '../../domain/event_models.dart';

/// Asks how somebody wants to pay, then takes them there.
///
/// One place, used from everywhere a payment can start — the registration
/// step, the registration dashboard, the events list — so the answer to "how
/// do I pay" is the same wherever it is asked.
///
/// Which ways are offered comes from the API and follows from where the payer
/// is: a card everywhere, and a transfer into the academy's own account only
/// for a Nigerian payer on an event whose creator set one up.
Future<void> showPaymentChoice({
  required BuildContext context,
  required String reference,
  required EventPaymentOptions options,
  String? attendanceMode,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: WEAColors.card,
  builder: (context) => _PaymentChoiceSheet(
    reference: reference,
    options: options,
    attendanceMode: attendanceMode,
  ),
);

class _PaymentChoiceSheet extends ConsumerStatefulWidget {
  const _PaymentChoiceSheet({
    required this.reference,
    required this.options,
    this.attendanceMode,
  });

  final String reference;
  final EventPaymentOptions options;
  final String? attendanceMode;

  @override
  ConsumerState<_PaymentChoiceSheet> createState() => _PaymentChoiceSheetState();
}

class _PaymentChoiceSheetState extends ConsumerState<_PaymentChoiceSheet> {
  bool _busy = false;
  String? _error;

  /// Set once a transfer has been started, so the sheet turns into the account
  /// details rather than closing and losing them.
  EventTransferAccount? _account;
  bool _uploaded = false;

  Future<void> _payByCard() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(eventActionsProvider)
          .beginPayment(
            widget.reference,
            attendanceMode: widget.attendanceMode,
            paymentChoice: 'CARD',
          );
      if (!mounted) return;
      setState(() => _busy = false);

      if (intent.hasCheckout) {
        final opened = await openCheckout(intent.checkoutUrl!);
        if (!opened && mounted) {
          setState(
            () => _error =
                'Your browser did not open the payment page. Try once more.',
          );
        }
        return;
      }
      setState(() => _error = 'No checkout was returned. Please try again.');
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _payByTransfer() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(eventActionsProvider)
          .beginPayment(
            widget.reference,
            attendanceMode: widget.attendanceMode,
            paymentChoice: 'TRANSFER',
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        // The account comes back from the API rather than from the options, so
        // the details shown are the ones the payment was actually recorded
        // against.
        _account = intent.transferAccount ?? widget.options.transferAccount;
      });
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _uploadReceipt() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(eventActionsProvider)
          .uploadPaymentProof(
            widget.reference,
            bytes: bytes,
            filename: file.name,
            contentType: _mimeFor(file.extension ?? 'jpg'),
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _uploaded = true;
      });
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  static String _mimeFor(String extension) => switch (extension.toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = _account;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          WEAInsets.lg,
          0,
          WEAInsets.lg,
          WEAInsets.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account == null ? 'How would you like to pay?' : 'Bank transfer',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                account == null
                    ? '${widget.options.price?.label ?? ''} due for your place.'
                    : 'Transfer the exact amount and quote your reference.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: WEAColors.mutedText,
                ),
              ),
              const SizedBox(height: WEAInsets.lg),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: WEAColors.error,
                  ),
                ),
                const SizedBox(height: WEAInsets.md),
              ],

              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: WEAInsets.lg),
                  child: LinearProgressIndicator(),
                )
              else if (account != null)
                _TransferDetails(
                  account: account,
                  reference: widget.reference,
                  amount: widget.options.price?.label ?? '',
                  uploaded: _uploaded,
                  onUpload: _uploadReceipt,
                  onDone: () => Navigator.of(context).pop(),
                )
              else ...[
                if (widget.options.cardAvailable)
                  _ChoiceTile(
                    icon: Icons.credit_card,
                    title: 'Pay with card',
                    subtitle:
                        'Visa, Mastercard and Verve, on the secure Flutterwave '
                        'checkout. Confirmed immediately.',
                    onTap: _payByCard,
                  ),
                if (widget.options.transferAvailable) ...[
                  const SizedBox(height: WEAInsets.sm),
                  _ChoiceTile(
                    icon: Icons.account_balance_outlined,
                    title: 'Bank transfer',
                    subtitle:
                        'Transfer to the academy’s account from your banking '
                        'app, then upload your receipt. Confirmed by the '
                        'academy office.',
                    onTap: _payByTransfer,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      child: Container(
        padding: const EdgeInsets.all(WEAInsets.md),
        decoration: BoxDecoration(
          border: Border.all(color: WEAColors.border),
          borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
        ),
        child: Row(
          children: [
            Icon(icon, color: WEAColors.accent),
            const SizedBox(width: WEAInsets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WEAColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: WEAColors.mutedText),
          ],
        ),
      ),
    );
  }
}

/// The academy's account, and the receipt that lets the office match it.
class _TransferDetails extends StatelessWidget {
  const _TransferDetails({
    required this.account,
    required this.reference,
    required this.amount,
    required this.uploaded,
    required this.onUpload,
    required this.onDone,
  });

  final EventTransferAccount account;
  final String reference;
  final String amount;
  final bool uploaded;
  final VoidCallback onUpload;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(WEAInsets.md),
          decoration: BoxDecoration(
            color: WEAColors.surfaceMuted,
            border: Border.all(color: WEAColors.border),
            borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Line(label: 'Bank', value: account.bankName),
              _Line(label: 'Account name', value: account.accountName),
              _Line(label: 'Account number', value: account.accountNumber, copy: true),
              if (amount.isNotEmpty) _Line(label: 'Amount', value: amount),
              // The reference is what ties the money to this place. Without it
              // the office is matching a name against a bank statement.
              _Line(label: 'Reference', value: reference, copy: true),
            ],
          ),
        ),
        if (account.instructions.isNotEmpty) ...[
          const SizedBox(height: WEAInsets.sm),
          Text(account.instructions, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: WEAInsets.md),
        Text(
          uploaded
              ? 'Your receipt has been received. The academy office will confirm '
                    'your place once the transfer has been matched.'
              : account.proofRequired
              ? 'Once you have transferred, upload your receipt so the office '
                    'can confirm your place.'
              : 'Once you have transferred, the office will confirm your place.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: uploaded ? WEAColors.accentDeep : WEAColors.mutedText,
          ),
        ),
        const SizedBox(height: WEAInsets.md),
        if (!uploaded)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('I HAVE PAID — UPLOAD RECEIPT'),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onDone, child: const Text('DONE')),
          ),
        const SizedBox(height: WEAInsets.xs),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: onDone,
            child: Text(uploaded ? 'Close' : 'I will pay later'),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.copy = false});

  final String label;
  final String value;
  final bool copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: WEAColors.mutedText,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.titleSmall,
            ),
          ),
          // Copyable where a digit typed wrongly sends money to a stranger.
          if (copy)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Copy',
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
              icon: const Icon(Icons.copy_outlined, size: 16),
            ),
        ],
      ),
    );
  }
}

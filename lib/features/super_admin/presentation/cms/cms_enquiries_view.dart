import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../catalogue/data/catalogue_repository.dart';
import '../../../contact/application/contact_providers.dart';
import '../../../contact/domain/contact_models.dart';
import '../../../contact/presentation/widgets/enquiry_thread.dart';

/// Enquiries sent from the contact page, and the office's replies.
///
/// A reply is delivered two ways: it appears in the sender's account when they
/// have one, and the office answers by email against the reference when they
/// do not.
class CmsEnquiriesView extends ConsumerStatefulWidget {
  const CmsEnquiriesView({super.key});

  @override
  ConsumerState<CmsEnquiriesView> createState() => _CmsEnquiriesViewState();
}

class _CmsEnquiriesViewState extends ConsumerState<CmsEnquiriesView> {
  EnquiryStatus? _status;

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on CatalogueFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: WEAColors.navy,
          content: Text(failure.message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enquiries = ref.watch(adminEnquiriesProvider(_status));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enquiries', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(
          'Messages sent from the contact page. Replying here reaches the '
          'sender in their account when they have one.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: WEAInsets.lg),
        Wrap(
          spacing: WEAInsets.xs,
          runSpacing: WEAInsets.xs,
          children: [
            _chip(null, 'All'),
            for (final status in EnquiryStatus.values)
              _chip(status, status.label),
          ],
        ),
        const SizedBox(height: WEAInsets.lg),
        enquiries.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(WEAInsets.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(WEAInsets.xl),
            child: Text(
              error is CatalogueFailure
                  ? error.message
                  : 'We could not load enquiries.',
              textAlign: TextAlign.center,
            ),
          ),
          data: (items) => items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: WEAInsets.xxl),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 28,
                        color: WEAColors.accent,
                      ),
                      const SizedBox(height: WEAInsets.sm),
                      Text(
                        _status == null
                            ? 'No enquiries yet'
                            : 'Nothing in this view',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: WEAInsets.xs),
                      Text(
                        'Messages sent from the contact page arrive here.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (final enquiry in items)
                      EnquiryThread(
                        enquiry: enquiry,
                        showSender: true,
                        replyLabel: 'SEND REPLY',
                        initiallyExpanded: enquiry.awaitingReply,
                        trailing: _StatusMenu(
                          enquiry: enquiry,
                          onSelected: (status) => _guard(
                            () => ref
                                .read(contactActionsProvider)
                                .setStatus(
                                  enquiryId: enquiry.id,
                                  status: status,
                                ),
                          ),
                        ),
                        onFollowUp: (body) => ref
                            .read(contactActionsProvider)
                            .reply(enquiryId: enquiry.id, body: body),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _chip(EnquiryStatus? value, String label) => ChoiceChip(
    label: Text(label),
    selected: _status == value,
    showCheckmark: false,
    onSelected: (_) => setState(() => _status = value),
    selectedColor: WEAColors.accent.withValues(alpha: .12),
    side: BorderSide(
      color: _status == value ? WEAColors.accent : WEAColors.border,
    ),
  );
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.enquiry, required this.onSelected});

  final Enquiry enquiry;
  final ValueChanged<EnquiryStatus> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<EnquiryStatus>(
    tooltip: 'Set status',
    initialValue: enquiry.status,
    onSelected: onSelected,
    itemBuilder: (context) => [
      for (final status in EnquiryStatus.values)
        PopupMenuItem(value: status, child: Text(status.label)),
    ],
    icon: const Icon(Icons.more_horiz, size: 20),
  );
}

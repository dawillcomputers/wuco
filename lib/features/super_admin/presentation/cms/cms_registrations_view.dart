import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../catalogue/data/catalogue_repository.dart';
import '../../../catalogue/domain/registration_models.dart';
import '../../application/cms_providers.dart';

/// Applications, and the decisions taken on them.
///
/// Confirming a registration also enrols the learner and promotes an applicant
/// account, so a confirmed place immediately means access.
class CmsRegistrationsView extends ConsumerStatefulWidget {
  const CmsRegistrationsView({super.key});

  @override
  ConsumerState<CmsRegistrationsView> createState() =>
      _CmsRegistrationsViewState();
}

class _CmsRegistrationsViewState extends ConsumerState<CmsRegistrationsView> {
  String? _status;

  Future<void> _review(RegistrationRecord record) async {
    final noteController = TextEditingController(text: record.reviewNote);
    var status = record.status;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record.reference),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.programmeTitle),
                Text(
                  record.applicantName.isEmpty
                      ? record.applicantEmail
                      : '${record.applicantName} · ${record.applicantEmail}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: WEAInsets.md),
                DropdownButtonFormField<RegistrationStatus>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Decision'),
                  items: [
                    for (final option in RegistrationStatus.values)
                      DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: WEAInsets.md),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Internal note',
                    helperText: 'Kept for the programme office; not shown publicly.',
                  ),
                ),
                // Paying for a place is taking it up, so both decisions enrol.
                // Saying so here stops the office marking somebody paid and
                // then hunting for a second button that no longer exists.
                if (status == RegistrationStatus.confirmed ||
                    status == RegistrationStatus.paid) ...[
                  const SizedBox(height: WEAInsets.sm),
                  Text(
                    status == RegistrationStatus.paid
                        ? 'Recording payment enrols this applicant on the '
                              'programme straight away and gives them learner '
                              'access — no separate confirmation is needed.'
                        : 'Confirming enrols this applicant on the programme '
                              'and gives them learner access.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('SAVE DECISION'),
            ),
          ],
        ),
      ),
    );

    final note = noteController.text;
    noteController.dispose();
    if (confirmed != true) return;

    try {
      await ref
          .read(cmsActionsProvider)
          .reviewRegistration(record.id, status: status, note: note);
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
    final registrations = ref.watch(cmsRegistrationsProvider(_status));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Registrations', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(
          'Applications submitted through the public site.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: WEAInsets.lg),
        Wrap(
          spacing: WEAInsets.xs,
          runSpacing: WEAInsets.xs,
          children: [
            _filterChip(context, null, 'All'),
            for (final status in RegistrationStatus.values)
              _filterChip(context, status.wireName, status.label),
          ],
        ),
        const SizedBox(height: WEAInsets.lg),
        registrations.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(WEAInsets.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(WEAInsets.xl),
            child: Text(
              error is CatalogueFailure
                  ? error.message
                  : 'We could not load registrations.',
              textAlign: TextAlign.center,
            ),
          ),
          data: (items) => items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: WEAInsets.xxl),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.assignment_outlined,
                        size: 28,
                        color: WEAColors.accent,
                      ),
                      const SizedBox(height: WEAInsets.sm),
                      Text(
                        'No registrations in this view',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: WEAInsets.xs),
                      Text(
                        'Applications appear here as soon as they are submitted.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (final record in items)
                      _RegistrationRow(
                        record: record,
                        onReview: () => _review(record),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _filterChip(BuildContext context, String? value, String label) =>
      ChoiceChip(
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

class _RegistrationRow extends StatelessWidget {
  const _RegistrationRow({required this.record, required this.onReview});

  final RegistrationRecord record;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 760;

    return Container(
      margin: const EdgeInsets.only(bottom: WEAInsets.xs),
      padding: const EdgeInsets.all(WEAInsets.md),
      decoration: BoxDecoration(
        color: WEAColors.card,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      ),
      child: Flex(
        direction: narrow ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: narrow ? 0 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.reference, style: theme.textTheme.labelMedium),
                Text(record.programmeTitle, style: theme.textTheme.titleMedium),
                Text(
                  record.applicantName.isEmpty
                      ? record.applicantEmail
                      : '${record.applicantName} · ${record.applicantEmail}',
                  style: theme.textTheme.bodySmall,
                ),
                if (record.answers.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.answers.entries
                        .where((entry) => entry.value.isNotEmpty)
                        .map((entry) => '${entry.key}: ${entry.value}')
                        .join(' · '),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: narrow ? null : WEAInsets.md,
            height: narrow ? WEAInsets.sm : null,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: WEAColors.accent.withValues(alpha: .10),
                  border: Border.all(
                    color: WEAColors.accent.withValues(alpha: .34),
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  record.status.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: WEAColors.accentDeep,
                  ),
                ),
              ),
              const SizedBox(width: WEAInsets.xs),
              OutlinedButton(onPressed: onReview, child: const Text('REVIEW')),
            ],
          ),
        ],
      ),
    );
  }
}

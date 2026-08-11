import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/components/wea_brand.dart';
import '../../domain/learner_enums.dart';
import '../../domain/learner_records.dart';
import 'learner_lists.dart';
import 'learner_progress.dart';
import 'learner_states.dart';

/// A certificate the learner has earned, or one still to be issued.
///
/// Everything on it is read-only: the number, the date and the status are set
/// by WEA, never by the learner.
class CertificateCard extends StatelessWidget {
  const CertificateCard({super.key, required this.certificate});

  final Certificate certificate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issued = certificate.isIssued;

    return LearnerCard(
      padding: EdgeInsets.zero,
      onTap: issued
          ? () => context.go('/learner/certificates/${certificate.id}')
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A restrained navy band stands in for the certificate itself: a
          // dignified mark rather than a decorative gradient.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(WEAInsets.lg),
            decoration: BoxDecoration(
              color: issued ? WEAColors.navy : WEAColors.surfaceMuted,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(WEAInsets.radius),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WEABrandLockup(height: 42, onDark: issued),
                const SizedBox(height: WEAInsets.md),
                Text(
                  issued ? 'EXECUTIVE CERTIFICATE' : 'AWAITING ISSUE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: issued
                        ? WEAColors.accentSoft
                        : WEAColors.mutedText,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  certificate.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: issued ? WEAColors.offWhite : WEAColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(WEAInsets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        certificate.programmeTitle,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _CertificateChip(status: certificate.status),
                  ],
                ),
                const SizedBox(height: WEAInsets.sm),
                Text(
                  issued
                      ? 'Certificate No. ${certificate.certificateNumber}'
                      : 'Issued once the programme assessment is complete.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (certificate.issuedOn != null)
                  Text(
                    'Issued ${formatShortDate(certificate.issuedOn!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: WEAInsets.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: issued
                        ? () =>
                              context.go('/learner/certificates/${certificate.id}')
                        : null,
                    child: const Text('VIEW CERTIFICATE'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateChip extends StatelessWidget {
  const _CertificateChip({required this.status});

  final CertificateStatus status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (status) {
      CertificateStatus.issued => (
        WEAColors.success,
        Icons.verified_outlined,
      ),
      CertificateStatus.pending => (
        WEAColors.warning,
        Icons.hourglass_empty,
      ),
      CertificateStatus.revoked => (WEAColors.error, Icons.block_outlined),
    };
    return LearnerStatusChip(label: status.label, tone: tone, icon: icon);
  }
}

/// A verifiable digital credential.
class CredentialCard extends StatelessWidget {
  const CredentialCard({
    super.key,
    required this.credential,
    required this.onShare,
  });

  final Credential credential;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (tone, icon) = switch (credential.status) {
      CredentialStatus.active => (WEAColors.success, Icons.verified_outlined),
      CredentialStatus.expired => (
        WEAColors.mutedText,
        Icons.event_busy_outlined,
      ),
      CredentialStatus.revoked => (WEAColors.error, Icons.block_outlined),
    };

    return LearnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: WEAColors.accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: WEAColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: WEAInsets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(credential.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Issued by ${credential.issuer}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              LearnerStatusChip(
                label: credential.status.label,
                tone: tone,
                icon: icon,
              ),
            ],
          ),
          const SizedBox(height: WEAInsets.md),
          Text(
            'Credential ID  ${credential.credentialId}',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            'Issued ${formatShortDate(credential.issuedOn)}'
            '${credential.expiresOn == null ? ' · No expiry' : ' · Expires ${formatShortDate(credential.expiresOn!)}'}',
            style: theme.textTheme.bodySmall,
          ),
          if (credential.skills.isNotEmpty) ...[
            const SizedBox(height: WEAInsets.md),
            Wrap(
              spacing: WEAInsets.xs,
              runSpacing: WEAInsets.xs,
              children: [
                for (final skill in credential.skills)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: WEAColors.surfaceMuted,
                      border: Border.all(color: WEAColors.border),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(skill, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ],
          const SizedBox(height: WEAInsets.md),
          Wrap(
            spacing: WEAInsets.sm,
            runSpacing: WEAInsets.xs,
            children: [
              OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('SHARE'),
              ),
              TextButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.qr_code_2, size: 16),
                label: const Text('VERIFICATION LINK'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One CPD award in the learner's record.
class CpdRecordTile extends StatelessWidget {
  const CpdRecordTile({super.key, required this.record, required this.last});

  final CpdRecord record;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: WEAInsets.sm),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: WEAColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: WEAColors.primaryText,
                  ),
                ),
                Text(
                  '${record.source} · ${formatShortDate(record.awardedOn)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: WEAInsets.sm),
          Text(
            '+${record.points}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: WEAColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

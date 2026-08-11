import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_records.dart';
import '../shell/learner_shell.dart';
import '../widgets/certificate_document.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_lists.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// A single certificate, shown as the document itself plus its record.
class CertificateDetailPage extends ConsumerWidget {
  const CertificateDetailPage({super.key, required this.certificateId});

  final String certificateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerPageBody(
    child: LearnerAsync(
      value: ref.watch(certificatesProvider),
      onRetry: () => ref.invalidate(certificatesProvider),
      loading: const LearnerCardSkeleton(count: 1, height: 320),
      data: (certificates) {
        final certificate = certificates
            .where((item) => item.id == certificateId)
            .firstOrNull;
        if (certificate == null) {
          return LearnerEmptyState(
            icon: Icons.search_off_outlined,
            title: 'Certificate not found',
            message:
                'This certificate is not one of yours, or the link is no '
                'longer valid.',
            actionLabel: 'BACK TO CERTIFICATES',
            onAction: () => context.go('/learner/certificates'),
          );
        }
        return _CertificateDetail(certificate: certificate);
      },
    ),
  );
}

class _CertificateDetail extends ConsumerWidget {
  const _CertificateDetail({required this.certificate});

  final Certificate certificate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPageHeader(
          eyebrow: 'Certificate',
          title: certificate.title,
          description: certificate.programmeTitle,
          backRoute: '/learner/certificates',
          backLabel: 'Certificates',
        ),
        LearnerCard(
          padding: const EdgeInsets.all(WEAInsets.md),
          child: CertificateDocument(
            certificate: certificate,
            recipientName: account?.fullName ?? 'WEA Learner',
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Certificate record',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LearnerFactGrid(
                facts: [
                  LearnerFact(
                    label: 'Certificate number',
                    value: certificate.certificateNumber,
                    icon: Icons.tag,
                  ),
                  LearnerFact(
                    label: 'Status',
                    value: certificate.status.label,
                    icon: Icons.verified_outlined,
                  ),
                  LearnerFact(
                    label: 'Issued',
                    value: certificate.issuedOn == null
                        ? 'Not yet issued'
                        : formatShortDate(certificate.issuedOn!),
                    icon: Icons.event_outlined,
                  ),
                  LearnerFact(
                    label: 'Awarded to',
                    value: account?.fullName ?? 'WEA Learner',
                    icon: Icons.person_outline,
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.lg),
              Wrap(
                spacing: WEAInsets.sm,
                runSpacing: WEAInsets.xs,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pending(context, 'Download'),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('DOWNLOAD PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pending(context, 'Verification'),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('VERIFY'),
                  ),
                  TextButton.icon(
                    onPressed: () => _pending(context, 'Sharing'),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('SHARE'),
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.md),
              Text(
                'Public verification will be available at '
                'verify.wuco.academy/${certificate.certificateNumber}.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: WEAInsets.sm),
              const LearnerLockedNote(
                message:
                    'Certificate numbers, issue dates and verification status '
                    'are issued by WEA and cannot be altered from your account.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _pending(BuildContext context, String action) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: WEAColors.navy,
      content: Text(
        '$action opens with the certificate service. Your certificate record '
        'is already issued and safe.',
      ),
    ),
  );
}

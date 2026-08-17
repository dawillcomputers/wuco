import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/components/wea_brand.dart';
import '../../domain/learner_records.dart';
import 'learner_lists.dart';

/// The certificate as a document.
///
/// Laid out at a fixed logical size inside a [FittedBox] so it scales down
/// proportionally on any screen instead of reflowing — a certificate that
/// rearranges itself on a phone would not read as a formal record.
class CertificateDocument extends StatelessWidget {
  const CertificateDocument({
    super.key,
    required this.certificate,
    required this.recipientName,
  });

  final Certificate certificate;
  final String recipientName;

  static const _width = 900.0;
  static const _height = 640.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxWidth * (_height / _width),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Container(
            width: _width,
            height: _height,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: WEAColors.background,
              border: Border.all(color: WEAColors.navy, width: 2),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
              decoration: BoxDecoration(
                border: Border.all(color: WEAColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const WEABrandLockup(height: 82, linkToHome: false),
                  const SizedBox(height: 10),
                  Text(
                    'EMPOWERING AFRICA’S LEADERS · SHAPING GLOBAL EXCELLENCE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: WEAColors.accent,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'This is to certify that',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipientName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: 40,
                      color: WEAColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(width: 160, height: 2, color: WEAColors.accent),
                  const SizedBox(height: 18),
                  Text(
                    'has successfully completed the programme',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      certificate.programmeTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _Footer(certificate: certificate),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.certificate});

  final Certificate certificate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.labelSmall?.copyWith(
      color: WEAColors.mutedText,
      letterSpacing: 1.1,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Signature(caption: 'ACADEMY DIRECTOR', name: 'WUCO Executive Academy'),
        const SizedBox(width: 28),
        _Signature(caption: 'PROGRAMME DEAN', name: 'Office of the Dean'),
        const Spacer(),
        // Bounded: a long certificate number or verification host must not
        // widen the block past the document it is printed on.
        SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Placeholder for the verification code the certificate service
              // will mint; nothing here is a working code.
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: WEAColors.surfaceMuted,
                  border: Border.all(color: WEAColors.border),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  size: 46,
                  color: WEAColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text('CERTIFICATE NO.', style: caption),
              Text(
                certificate.certificateNumber,
                style: theme.textTheme.labelMedium,
              ),
              Text(
                certificate.issuedOn == null
                    ? 'Not yet issued'
                    : 'Issued ${formatShortDate(certificate.issuedOn!)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'verify.wuco.academy/${certificate.certificateNumber}',
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: WEAColors.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Signature extends StatelessWidget {
  const _Signature({required this.caption, required this.name});

  final String caption;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: WEAColors.navy),
          const SizedBox(height: WEAInsets.xxs),
          Text(name, style: theme.textTheme.labelMedium),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../shared/components/wea_components.dart';
import '../../../shared/layouts/app_shell.dart';

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({
    super.key,
    required this.title,
    required this.description,
  });
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => WEAAppShell(
    child: WEAContainer(
      child: Center(
        child: WEASection(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: WEACard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 14),
                  Text(description),
                  const SizedBox(height: 24),
                  const WEAChip(label: 'Foundation route'),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

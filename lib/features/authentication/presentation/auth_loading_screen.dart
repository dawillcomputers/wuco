import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/components/wea_brand.dart';

/// Shown while the stored session is being checked, so the application never
/// opens on a blank frame or flashes the login page at a signed-in user.
class WEAAuthLoadingScreen extends StatelessWidget {
  const WEAAuthLoadingScreen({super.key, this.message = 'Loading your account…'});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WEAColors.background,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WEABrandLockup(height: 132, linkToHome: false),
          const SizedBox(height: 40),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

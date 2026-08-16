import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

/// Google's own rendered button.
///
/// On the web this is not a stylistic choice. Google Identity Services will
/// only begin a sign-in from a button it renders inside its own frame — it
/// cannot be started from our code, and it cannot be restyled to match the
/// rest of the academy's interface. Rendering Google's button is therefore the
/// only way to offer Google sign-in on the web at all.
Widget googleRenderedButton() {
  final plugin = GoogleSignInPlatform.instance;
  if (plugin is! GoogleSignInPlugin) return const SizedBox.shrink();

  return SizedBox(
    height: 44,
    child: plugin.renderButton(
      configuration: GSIButtonConfiguration(
        theme: GSIButtonTheme.outline,
        size: GSIButtonSize.large,
        text: GSIButtonText.continueWith,
        shape: GSIButtonShape.rectangular,
        logoAlignment: GSIButtonLogoAlignment.left,
      ),
    ),
  );
}

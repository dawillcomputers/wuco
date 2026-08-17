import 'package:url_launcher/url_launcher.dart';

/// Opens the processor's checkout on a device.
///
/// Returns whether the checkout was actually opened. The result matters: a
/// launch that quietly fails and is quietly ignored is what makes a payment
/// button look broken, so every caller is expected to say something when this
/// comes back false rather than leaving the payer looking at an unchanged
/// screen.
Future<bool> openCheckout(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

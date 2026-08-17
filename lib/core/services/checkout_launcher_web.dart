import 'package:web/web.dart' as web;

/// Sends the browser to the processor's checkout.
///
/// This assigns `location.href` rather than calling `window.open`, and the
/// difference is the whole point.
///
/// Starting a payment means asking the API for a checkout first, so by the
/// time there is a URL to open, the click that began it is over. A browser
/// treats `window.open` outside a live user gesture as a pop-up and blocks it
/// — silently. That is why pressing "continue to payment" appeared to do
/// nothing: the request had succeeded, the link had come back, and the
/// navigation was being suppressed.
///
/// Assigning `location.href` is an ordinary same-tab navigation. It is not a
/// pop-up, so nothing blocks it, and the payer arrives at the checkout however
/// long the API took to answer.
///
/// Same tab deliberately: the processor sends the payer back to the
/// registration page afterwards, and a new tab would leave them looking at a
/// stale one.
Future<bool> openCheckout(String url) async {
  web.window.location.href = url;
  return true;
}

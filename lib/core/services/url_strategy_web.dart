import 'package:flutter_web_plugins/url_strategy.dart';

/// Uses real paths on the web — `/events/africa-summit` rather than
/// `/#/events/africa-summit`.
///
/// This is not cosmetic. Three things WEA relies on break under the hash
/// strategy, because everything after `#` never reaches the server and is
/// discarded when the application boots at a path it was not expecting:
///
/// - a shared event link, which arrives from the API's `/share/` card;
/// - a campaign short link, which redirects to a real path;
/// - and worst, the payment return URL, which would drop a payer who has just
///   been charged onto the home page instead of their registration.
///
/// Cloudflare Pages already serves the application shell for unmatched paths,
/// so a deep link is delivered to Flutter rather than 404ing.
void configureUrlStrategy() => usePathUrlStrategy();

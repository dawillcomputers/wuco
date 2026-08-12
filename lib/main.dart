import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/url_strategy.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Real paths on the web, so shared event links, campaign links and the
  // payment return URL all land where they point.
  configureUrlStrategy();
  runApp(const ProviderScope(child: WEAApp()));
}

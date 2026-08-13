import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class WEAApp extends ConsumerWidget {
  const WEAApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'WUCO Executive Academy',
    debugShowCheckedModeBanner: false,
    theme: WEAAppTheme.light(),
    routerConfig: ref.watch(routerProvider),
    // Text selection is applied by the page shells rather than here: a
    // SelectionArea at this level sits above the Navigator, and it needs an
    // Overlay ancestor to place its handles. See WEASelectableText.
  );
}

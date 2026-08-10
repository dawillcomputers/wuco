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
  );
}

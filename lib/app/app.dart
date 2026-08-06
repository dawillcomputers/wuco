import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class WEAApp extends StatelessWidget {
  const WEAApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'WUCO Executive Academy',
    debugShowCheckedModeBanner: false,
    theme: WEAAppTheme.dark(),
    routerConfig: appRouter,
  );
}

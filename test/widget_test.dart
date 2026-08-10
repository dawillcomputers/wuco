import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:wea_lms/app/app.dart';
import 'package:wea_lms/app/theme/app_colors.dart';
import 'package:wea_lms/app/theme/app_theme.dart';
import 'package:wea_lms/core/responsive/responsive.dart';
import 'package:wea_lms/features/authentication/presentation/login_screen.dart';
import 'package:wea_lms/features/authentication/presentation/register_screen.dart';

void main() {
  testWidgets('app starts with WEA branding', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const ProviderScope(child: WEAApp()));
      await tester.pumpAndSettle();
      expect(find.text("Where Africa's\nLeaders Are Formed"), findsOneWidget);
      expect(find.text('EXPLORE PROGRAMMES'), findsAtLeastNWidgets(1));
    });
  });

  test('theme tokens use the bright WUCO logo palette', () {
    expect(WEAColors.background.toARGB32(), 0xFFFFFFFF);
    expect(WEAColors.accent.toARGB32(), 0xFF1B6FC4);
    expect(WEAColors.navy.toARGB32(), 0xFF0A1E3D);
    expect(WEAColors.primaryText, WEAColors.navy);
  });

  test('theme is light and carries the logo accent', () {
    final theme = WEAAppTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, WEAColors.accent);
    expect(theme.scaffoldBackgroundColor, WEAColors.background);
  });

  test('responsive breakpoints select expected layouts', () {
    expect(WEAResponsive.breakpointOf(390), WEABreakpoint.mobile);
    expect(WEAResponsive.breakpointOf(768), WEABreakpoint.tablet);
    expect(WEAResponsive.breakpointOf(1280), WEABreakpoint.desktop);
    expect(WEAResponsive.breakpointOf(1920), WEABreakpoint.largeDesktop);
  });

  testWidgets('authentication pages adapt across viewport widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final screen in <(String, Widget)>[
      ('login', const LoginScreen()),
      ('register', const RegisterScreen()),
    ]) {
      for (final width in [360.0, 390.0, 430.0, 768.0, 1024.0, 1280.0, 1920.0]) {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;

        final router = GoRouter(
          initialLocation: '/x',
          routes: [
            GoRoute(path: '/x', builder: (_, _) => screen.$2),
            GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(
              theme: WEAAppTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.$1} overflowed at ${width}px',
        );
      }
    }
  });

  testWidgets('home adapts across supported viewport widths without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await mockNetworkImagesFor(() async {
      for (final width in [
        360.0,
        390.0,
        430.0,
        768.0,
        1024.0,
        // Straddles WEAAppShell.navigationBreakpoint, where the drawer gives
        // way to the full desktop menu.
        1099.0,
        1100.0,
        1152.0,
        1280.0,
        1440.0,
        1920.0,
      ]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const ProviderScope(child: WEAApp()));
        await tester.pumpAndSettle();
        expect(find.text('EXPLORE PROGRAMMES'), findsAtLeastNWidgets(1));
      }
    });
  });
}

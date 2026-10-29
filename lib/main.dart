import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/app/display_geometry.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/objectBox/store.dart';
import 'package:hktransports/pages/credits_page.dart';
import 'package:hktransports/pages/home.dart';
import 'package:hktransports/pages/route.dart';
import 'package:hktransports/pages/settings_page.dart';
import 'package:hktransports/pages/update_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeShell()),
    GoRoute(
      path: '/route/:slug',
      pageBuilder: (context, state) {
        final String slug = state.pathParameters['slug'] ?? '';
        final bool fade = state.uri.queryParameters['fade'] == '1';
        if (fade) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: RoutePageRoute(slug: slug),
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          );
        }
        return MaterialPage<void>(
          key: state.pageKey,
          child: RoutePageRoute(slug: slug),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPageRoute(),
    ),
    GoRoute(
      path: '/updateData',
      builder: (context, state) => const UpdateDataPageRoute(),
    ),
    GoRoute(path: '/credits', builder: (context, state) => const CreditsPage()),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Directory dir = await getApplicationDocumentsDirectory();
  final String path = dir.path;
  final Directory dirAppdata = Directory('$path/hktransports/appdata');
  if (!await dirAppdata.exists()) {
    await dirAppdata.create(recursive: true);
  }
  await initObjectBox();
  await DisplayGeometry.load();

  final AppSettings settings = AppSettings();
  final BusRepository repository = BusRepository(settings);
  await repository.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<BusRepository>.value(value: repository),
      ],
      child: const MyApp(),
    ),
  );
  unawaited(repository.autoCheckIfDue());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final bool purple = settings.usesPurpleTheme;
            final ColorScheme lightScheme = purple
                ? purpleLightScheme()
                : lightDynamic ?? fallbackLightScheme();
            final ColorScheme darkScheme = purple
                ? purpleDarkScheme()
                : darkDynamic ?? fallbackDarkScheme();
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              themeMode: settings.themeMode,
              theme: buildAppTheme(lightScheme),
              darkTheme: buildAppTheme(darkScheme),
              routerConfig: _router,
              builder: (context, child) {
                final MediaQueryData media = MediaQuery.of(context);
                final double systemScale = media.textScaler.scale(1);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: TextScaler.linear(
                      systemScale * settings.textScale,
                    ),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
        );
      },
    );
  }
}

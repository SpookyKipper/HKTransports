import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/app_theme.dart';
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
      builder: (context, state) =>
          RoutePageRoute(slug: state.pathParameters['slug'] ?? ''),
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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              themeMode: settings.themeMode,
              theme: buildAppTheme(lightDynamic ?? fallbackLightScheme()),
              darkTheme: buildAppTheme(darkDynamic ?? fallbackDarkScheme()),
              routerConfig: _router,
            );
          },
        );
      },
    );
  }
}

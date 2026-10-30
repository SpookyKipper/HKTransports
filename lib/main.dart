import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/app/fade_forward_page.dart';
import 'package:hktransports/app/m3e_scope.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/objectBox/store.dart';
import 'package:hktransports/pages/credits_page.dart';
import 'package:hktransports/pages/favorite_groups_page.dart';
import 'package:hktransports/pages/home.dart';
import 'package:hktransports/pages/licenses_page.dart';
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
          final PageTransitionsBuilder reverseBuilder = transitionBuilderFor(
            context.read<AppSettings>().transitionStyle,
          );
          return FadeForwardPage<void>(
            key: state.pageKey,
            reverseBuilder: reverseBuilder,
            child: RoutePageRoute(slug: slug),
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
    GoRoute(
      path: '/licenses',
      builder: (context, state) => const LicensesPage(),
    ),
    GoRoute(
      path: '/favoriteGroups',
      builder: (context, state) => const FavoriteGroupsPage(),
    ),
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
        Provider<EtaService>(
          create: (_) => EtaService(language: settings.language),
        ),
      ],
      child: const MyApp(),
    ),
  );
  repository.startAutoUpdate();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        return DynamicColorBuilder(
          builder:
              (mui.ColorScheme? lightDynamic, mui.ColorScheme? darkDynamic) {
                final bool purple = settings.usesPurpleTheme;
                final ColorScheme lightScheme = purple
                    ? purpleLightScheme()
                    : lightDynamic == null
                    ? fallbackLightScheme()
                    : flutterSchemeFromMaterialUi(lightDynamic);
                final ColorScheme darkScheme = purple
                    ? purpleDarkScheme()
                    : darkDynamic == null
                    ? fallbackDarkScheme()
                    : flutterSchemeFromMaterialUi(darkDynamic);
                return MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  themeMode: settings.themeMode,
                  theme: buildAppTheme(lightScheme, settings.transitionStyle),
                  darkTheme: buildAppTheme(
                    darkScheme,
                    settings.transitionStyle,
                  ),
                  routerConfig: _router,
                  builder: (context, child) {
                    final MediaQueryData media = MediaQuery.of(context);
                    final double systemScale = media.textScaler.scale(1);
                    return M3EScope(
                      scheme: Theme.of(context).colorScheme,
                      child: MediaQuery(
                        data: media.copyWith(
                          textScaler: TextScaler.linear(
                            systemScale * settings.textScale,
                          ),
                        ),
                        child: child ?? const SizedBox.shrink(),
                      ),
                    );
                  },
                );
              },
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/app/app_transition_page.dart';
import 'package:hktransports/app/fade_forward_page.dart';
import 'package:hktransports/app/m3e_scope.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/notice/bbi_service.dart';
import 'package:hktransports/bus/state/pinned_stops.dart';
import 'package:hktransports/bus/ui/pinned_stops_bar.dart';
import 'package:hktransports/location/location_controller.dart';
import 'package:hktransports/objectBox/store.dart';
import 'package:hktransports/pages/credits_page.dart';
import 'package:hktransports/pages/favorite_groups_page.dart';
import 'package:hktransports/pages/home.dart';
import 'package:hktransports/pages/homeIndexPage/home.dart';
import 'package:hktransports/pages/homeIndexPage/traffic_news.dart';
import 'package:hktransports/pages/search_page.dart';
import 'package:hktransports/pages/licenses_page.dart';
import 'package:hktransports/pages/notice_viewer_page.dart';
import 'package:hktransports/pages/proprietary_data_page.dart';
import 'package:hktransports/pages/route.dart';
import 'package:hktransports/pages/settings_page.dart';
import 'package:hktransports/pages/update_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

Page<void> _page(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  LocalKey? key,
}) {
  return AppTransitionPage<void>(
    key: key ?? state.pageKey,
    style: context.read<AppSettings>().transitionStyle,
    child: child,
  );
}

final GoRouter _router = GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      pageBuilder: (context, state, navigationShell) => _page(
        context,
        state,
        HomeShell(navigationShell: navigationShell),
        key: const ValueKey<String>('home-shell'),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeContent(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/news',
              builder: (context, state) => const TrafficNews(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/route/:slug',
      pageBuilder: (context, state) {
        final String slug = state.pathParameters['slug'] ?? '';
        final String? stopId = state.uri.queryParameters['stop'];
        final bool fade = state.uri.queryParameters['fade'] == '1';
        if (fade) {
          final PageTransitionsBuilder reverseBuilder = transitionBuilderFor(
            context.read<AppSettings>().transitionStyle,
          );
          return FadeForwardPage<void>(
            key: state.pageKey,
            reverseBuilder: reverseBuilder,
            child: RoutePageRoute(slug: slug, initialStopId: stopId),
          );
        }
        return _page(
          context,
          state,
          RoutePageRoute(slug: slug, initialStopId: stopId),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) =>
          _page(context, state, const SettingsPageRoute()),
    ),
    GoRoute(
      path: '/updateData',
      pageBuilder: (context, state) =>
          _page(context, state, const UpdateDataPageRoute()),
    ),
    GoRoute(
      path: '/proprietaryData',
      pageBuilder: (context, state) =>
          _page(context, state, const ProprietaryDataPage()),
    ),
    GoRoute(
      path: '/notice',
      pageBuilder: (context, state) {
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return const OpenUpwardsPageTransitionsBuilder()
                .buildTransitions<void>(
                  null,
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                );
          },
          child: NoticeViewerPage(
            url: state.uri.queryParameters['url'] ?? '',
            title: state.uri.queryParameters['title'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/credits',
      pageBuilder: (context, state) =>
          _page(context, state, const CreditsPage()),
    ),
    GoRoute(
      path: '/licenses',
      pageBuilder: (context, state) =>
          _page(context, state, const LicensesPage()),
    ),
    GoRoute(
      path: '/favoriteGroups',
      pageBuilder: (context, state) =>
          _page(context, state, const FavoriteGroupsPage()),
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
  if (!settings.isProprietaryEnabled(ProprietaryDataSource.kmb)) {
    await const BbiService().clearCache();
  }
  final bool citybusEnabled = settings.isProprietaryEnabled(
    ProprietaryDataSource.citybus,
  );
  if (citybusEnabled) {
    unawaited(
      CitybusRoutelistService.instance.ensureDownloaded().catchError((
        Object error,
      ) {
        debugPrint('Unable to download Citybus routelist: $error');
      }),
    );
  } else {
    unawaited(
      CitybusRoutelistService.instance.delete().catchError((Object error) {
        debugPrint('Unable to delete Citybus routelist: $error');
      }),
    );
  }
  final BusRepository repository = BusRepository(settings);
  await repository.initialize();
  final LocationController location = LocationController(settings);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<BusRepository>.value(value: repository),
        Provider<EtaService>(
          create: (_) => EtaService(language: settings.language),
        ),
        ChangeNotifierProvider<PinnedStopsController>(
          create: (_) => PinnedStopsController(),
        ),
        ChangeNotifierProvider<LocationController>.value(value: location),
      ],
      child: const MyApp(),
    ),
  );
  repository.startAutoUpdate();
  unawaited(location.ensureStarted());
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
                  title: 'HKTransports',
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
                    return AppColorSchemes(
                      light: lightScheme,
                      dark: darkScheme,
                      child: M3EScope(
                        scheme: Theme.of(context).colorScheme,
                        child: MediaQuery(
                          data: media.copyWith(
                            textScaler: TextScaler.linear(
                              systemScale * settings.textScale,
                            ),
                          ),
                          child: PinnedStopsHost(
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
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

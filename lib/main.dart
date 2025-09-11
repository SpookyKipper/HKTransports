import 'dart:async';
import 'dart:io';

import 'package:dynamik_theme/dynamik_theme.dart';
import 'package:hktransports/dataStore/objectbox.dart';
import 'package:hktransports/functions/app.dart';
import 'package:hktransports/functions/platform.dart';
import 'package:hktransports/objectBox/store.dart';
import 'package:hktransports/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:hktransports/pages/route.dart';
import 'package:hktransports/pages/update_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_handler/share_handler.dart';
import 'functions/ui.dart';
import 'pages/settings_page.dart';

import 'package:go_router/go_router.dart';

import 'package:hkbusapi/hkbusapi.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePageRoute()),
    GoRoute(
      path: '/route',
      builder: (context, state) => const RoutePageRoute(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPageRoute(),
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: SettingsPageRoute(),
          transitionDuration: const Duration(milliseconds: 750),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Use a fastOutSlowIn curve for the slide transition, with a 100ms delay
            final delayedAnimation = CurvedAnimation(
              parent: animation,
              curve: Interval(0.2, 1.0, curve: Curves.fastEaseInToSlowEaseOut),
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0), // Starts from the right
                end: Offset.zero, // Ends at the center
              ).animate(delayedAnimation),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/updateData',
      builder: (context, state) => const UpdateDataPageRoute(),
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Directory dir = await getApplicationDocumentsDirectory();
  String path = dir.path;
  await initObjectBox();
  await initBusApiObjectBox(dir: "$path/hktransports/busapi");
  // await FlutterDisplayMode.setHighRefreshRate();
  runApp(Phoenix(child: MyApp()));
}

bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamikTheme(
      config: ThemeConfig(
        useMaterial3: true,
        // You can also generate color schemes from:
        // https://m3.material.io/theme-builder#/custom
        lightScheme: ColorScheme.fromSeed(seedColor: Color(0xff6f65dc)),
        darkScheme: ColorScheme.fromSeed(
          seedColor: Color(0xff6f65dc),
          brightness: Brightness.dark,
        ),
        defaultThemeState: SimpleThemeType.dynamik.themeState,
        builder: (themeData) {
          // Add more customization on ThemeData.
          return themeData.copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
            ),
          );
        },
      ),
      builder: (theme, darkTheme, themeMode) {
        return MaterialApp.router(
          themeMode: themeMode,
          theme: theme,
          darkTheme: darkTheme,
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          // scaffoldMessengerKey: snackbarKey,
        );
        // MaterialApp(
        //   themeMode: themeMode,
        //   theme: theme,
        //   darkTheme: darkTheme,
        //   debugShowCheckedModeBanner: false,
        //   home: MyHomePage(),
        //   // scaffoldMessengerKey: snackbarKey,
        // );
      },
    );
  }
}

class MyAppState extends ChangeNotifier {}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  SharedMedia? media;

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    final handler = ShareHandlerPlatform.instance;
    media = await handler.getInitialSharedMedia();

    if (!mounted) return;

    setState(() {
      // _platformVersion = platformVersion;
    });
  }

  // Main route
  @override
  void initState() {
    super.initState();

    void checkTheme() {
      final int currentThemeMode = sp.getInt('themeMode') ?? 0;
      if (currentThemeMode == 1) {
        DynamikTheme.of(context).setThemeMode(ThemeMode.light);
      } else if (currentThemeMode == 2) {
        DynamikTheme.of(context).setThemeMode(ThemeMode.dark);
      }
    }

    checkTheme();
  }

  var selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              Expanded(
                child: Container(
                  color: uf.cLD(
                    context: context,
                    color: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Colors.black12,
                    ],
                  ), // Set the background color of the sidebar
                  child: Center(
                    child: SizedBox(
                      width: 350,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 150,
                            height: 150,
                          ),
                          Center(
                            child: Text(
                              "HKTransports",
                              style: TextStyle(fontSize: 30),
                            ),
                          ),
                          SizedBox(height: 8),
                          // w.button(
                          //   context: context,
                          //   onPressed: () {
                          //     Navigator.pushReplacement(
                          //       context,
                          //       MaterialPageRoute(
                          //         builder: (context) => AuthPageRoute(),
                          //       ),
                          //     );
                          //   },
                          //   child: Text("Login"),
                          // ),
                          SizedBox(height: 10),
                          Center(
                            child: af.getVersionBuilder(
                              builder: (res) =>
                                  Text("Version: $res [EARLY ACCESS]"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:dynamik_theme/dynamik_theme.dart';
import 'package:hktransports/auth/logout_page.dart';
import 'package:hktransports/customWidgets/nullWidget.dart';
import 'package:hktransports/customWidgets/stackedWidgets.dart';
import 'package:hktransports/dataStore/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:hktransports/customWidgets/nullWidget.dart';
import 'package:hktransports/customWidgets/stackedWidgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../functions/platform.dart';
import '../functions/text.dart';
import '../functions/ui.dart';
import '../functions/app.dart';
import '../multiplat_ui.dart';

import 'package:go_router/go_router.dart';

class HomePageRoute extends StatelessWidget {
  const HomePageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: w.appBar(
        context: context,
        title: 'HKTransports',
        backgroundColor: uf.cLD(
          context: context,
          color: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.onPrimary,
          ],
        ), // Add background color to the app bar
        foregroundColor: Colors.white.withValues(
          alpha: 0.9,
        ), // Add foreground color to the app bar
      ),
      body: HomePage(), // Use the HomePage widget
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return w.tabUiPage(
      context: context,
      tabTitles: [
        Tab(text: 'Homae'),
        Tab(text: 'Settings'),
        Tab(text: 'Profile'),
        Tab(text: 'Profile'),
        Tab(text: 'Profile'),
        Tab(text: 'Profile'),
        Tab(text: 'Profile'),
        Tab(text: 'Profile'),
        Tab(text: 'Profile'),
        Tab(text: 'Profile'),
        Tab(text: 'Profile'),
        Tab(text: 'Profile'),
      ],
      children: [
        RouteTile(
          route: "290A",
          operator: "九巴",
          dest: "荃灣西站",
          onBoardStop: "培城路",
        ),
        ElevatedButton(
          onPressed: () => context.push('/settings'),
          child: Text("a"),
        ),
        nullWidget(),
        nullWidget(),
        nullWidget(),
        nullWidget(),
        nullWidget(),
        nullWidget(),
        nullWidget(),
        nullWidget(),
        nullWidget(),
        nullWidget(),
      ],
    );

    dynamic a = DefaultTabController(
      length: 3,
      child: Column(
        children: [
          w.tabBar(
            context: context,
            tabs: [
              Tab(text: 'Home'),
              Tab(text: 'Settings'),
              Tab(text: 'Profile'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                RouteTile(
                  route: "290A",
                  operator: "九巴",
                  dest: "荃灣西站",
                  onBoardStop: "培城路",
                ),
                ElevatedButton(
                  onPressed: () => context.push('/settings'),
                  child: Text("a"),
                ),
                nullWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RouteTile extends StatelessWidget {
  const RouteTile({
    super.key,
    required this.route,
    required this.operator,
    required this.dest,
    required this.onBoardStop,
  });

  final String route;
  final String operator;
  final String dest;
  final String onBoardStop;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        GestureDetector(
          onTap: () => {context.push('/route?route=$route&bound=I')},
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  // Leading section
                  stackedWidgets(
                    nullWidget(),
                    Text(route, style: TextStyle(fontSize: 20)),
                    Text(operator, style: TextStyle(fontSize: 12)),
                  ),
                  Padding(padding: EdgeInsets.only(right: 10)),
                  // Title and subtitle section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      stackedWidgets(
                        nullWidget(),
                        Row(
                          children: [
                            Column(
                              children: [
                                Padding(padding: EdgeInsets.only(top: 5.5)),
                                Text("往 ", style: TextStyle(fontSize: 15)),
                              ],
                            ),
                            Text(dest, style: TextStyle(fontSize: 20)),
                          ],
                        ),
                        Text(onBoardStop, style: TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                  Spacer(),
                  // Trailing section
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.access_time, size: 15.8),
                              Padding(padding: EdgeInsets.only(bottom: 2.25)),
                            ],
                          ),
                          Text(
                            " 12:30 ",
                            style: TextStyle(fontSize: 16.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          Text(
                            "10",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          SizedBox(width: 3),
                          Text(
                            "分鐘",
                            style: TextStyle(fontSize: 16.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 13),
                          Text(
                            " 12:30 ",
                            style: TextStyle(fontSize: 13.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          Text(
                            "10",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          SizedBox(width: 2),
                          Text(
                            "分鐘",
                            style: TextStyle(fontSize: 13.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 13),
                          Text(
                            " 12:30 ",
                            style: TextStyle(fontSize: 13.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          Text(
                            "10",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          SizedBox(width: 2),
                          Text(
                            "分鐘",
                            style: TextStyle(fontSize: 13.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        //
      ],
    );
  }
}

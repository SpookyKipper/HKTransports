import 'package:dynamik_theme/dynamik_theme.dart';
import 'package:flow_by_spooky_services/auth/logout_page.dart';
import 'package:flow_by_spooky_services/customWidgets/nullWidget.dart';
import 'package:flow_by_spooky_services/customWidgets/stackedWidgets.dart';
import 'package:flow_by_spooky_services/dataStore/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
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
        backButton: true,
      ),
      body: HomePage(), // Use the HomePage widget
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        GestureDetector(
          onTap: () => {context.go('/settings')},
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  // Leading section
                  stackedWidgets(
                    nullWidget(),
                    Text("290A", style: TextStyle(fontSize: 20)),
                    Text("九巴", style: TextStyle(fontSize: 12)),
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
                            Text("荃灣西站", style: TextStyle(fontSize: 20)),
                          ],
                        ),
                        Text("南豐廣場", style: TextStyle(fontSize: 15)),
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
                          Icon(Icons.access_time, size: 13),
                          Text(" 12:30 ", style: TextStyle(fontSize: 16.5), strutStyle: StrutStyle(forceStrutHeight: true)),
                          Text("10", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary), strutStyle: StrutStyle(forceStrutHeight: true)),
                          SizedBox(width: 3),
                          Text("分鐘", style: TextStyle(fontSize: 16.5), strutStyle: StrutStyle(forceStrutHeight: true)),
                        ],
                      ),
                      SizedBox(height: 2.5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 13),
                          Text(" 12:30 ", style: TextStyle(fontSize: 13.5), strutStyle: StrutStyle(forceStrutHeight: true)),
                          Text("10", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.outline), strutStyle: StrutStyle(forceStrutHeight: true)),
                          SizedBox(width: 2),
                          Text("分鐘", style: TextStyle(fontSize: 13.5), strutStyle: StrutStyle(forceStrutHeight: true)),
                        ],
                      ),
                      SizedBox(height: 2.5),
                     Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 13),
                          Text(" 12:30 ", style: TextStyle(fontSize: 13.5), strutStyle: StrutStyle(forceStrutHeight: true)),
                          Text("10", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.outline), strutStyle: StrutStyle(forceStrutHeight: true)),
                          SizedBox(width: 2),
                          Text("分鐘", style: TextStyle(fontSize: 13.5), strutStyle: StrutStyle(forceStrutHeight: true)),
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

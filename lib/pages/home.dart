import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide AppBar;
import 'package:hktransports/pages/homeIndexPage/home.dart';
import 'package:hktransports/pages/homeIndexPage/traffic_news.dart';
import 'package:spookyservices/helpers/language.dart';
import 'package:window_manager/window_manager.dart';
import 'package:spookyservices/widgets/widgets.dart';

import 'package:go_router/go_router.dart';

class HomePageRoute extends StatefulWidget {
  const HomePageRoute({super.key});

  @override
  State<HomePageRoute> createState() => _HomePageRouteState();
}

class _HomePageRouteState extends State<HomePageRoute> with WindowListener {
  Widget currentPage = HomePage();
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    bool _isPreventClose = await windowManager.isPreventClose();
    if (_isPreventClose) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text('Are you sure you want to close this window?'),
            actions: [
              TextButton(child: Text('No'), onPressed: () {}),
              TextButton(
                child: Text('Yes'),
                onPressed: () async {
                  await windowManager.destroy();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: 'HKTransports',
        // backgroundColor: uf.cLD(
        //   context: context,
        //   color: [
        //     Theme.of(context).colorScheme.primary,
        //     Theme.of(context).colorScheme.onPrimary,
        //   ],
        // ), // Add background color to the app bar
        // foregroundColor: Colors.white.withValues(
        //   alpha: 0.9,
        // ), // Add foreground color to the app bar
        // backButton: context.canPop(),
        actions: [
          CupertinoButton(
            padding: EdgeInsets.only(left: 30),
            onPressed: () {
              context.push('/settings');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.settings,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 24,
                ),
              ],
            ),
          ),
        ],
      ),
      body: currentPage, // Use the HomePage widget
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentPageIndex,
        destinations: <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home), label: lh.lt("主頁", "Home")),
          NavigationDestination(icon: Icon(Icons.search), label: lh.lt("搜尋", "Search")),
          NavigationDestination(icon: Icon(Icons.article), label: lh.lt("交通快訊", "Traffic News")),
        ],
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
            if (index == 0) {
              currentPage = HomePage();
            } else if (index == 1) {
              currentPage = SizedBox.shrink();
            } else if (index == 2) {
              currentPage = TrafficNews();
            }
          });
        },
      ),
    );
  }
}

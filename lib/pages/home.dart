import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/pages/homeIndexPage/home.dart';
import 'package:hktransports/pages/homeIndexPage/traffic_news.dart';
import 'package:hktransports/pages/search_page.dart';
import 'package:provider/provider.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _pages = [
    HomeContent(),
    SearchPage(),
    TrafficNews(),
  ];

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final List<String> titles = [
      settings.text('主頁', 'Home'),
      settings.text('路線搜尋', 'Search routes'),
      settings.text('交通快訊', 'Traffic news'),
    ];

    return Scaffold(
      appBar: buildPageBar(
        context,
        title: titles[_index],
        actions: [
          IconButton(
            tooltip: settings.text('設定', 'Settings'),
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          setState(() => _index = value);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: settings.text('主頁', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            selectedIcon: const Icon(Icons.search),
            label: settings.text('搜尋', 'Search'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.campaign_outlined),
            selectedIcon: const Icon(Icons.campaign),
            label: settings.text('快訊', 'News'),
          ),
        ],
      ),
    );
  }
}

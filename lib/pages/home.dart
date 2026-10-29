import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/pages/homeIndexPage/home.dart';
import 'package:hktransports/pages/homeIndexPage/traffic_news.dart';
import 'package:hktransports/pages/search_page.dart';
import 'package:m3e_core/m3e_core.dart';
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Center(
            heightFactor: 1,
            child: M3EHorizontalFloatingToolbar(
              expanded: true,
              decoration: const M3EFloatingToolbarDecoration(
                shape: StadiumBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                expandedShadowElevation: 0,
                collapsedShadowElevation: 0,
              ),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolbarDestination(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: settings.text('主頁', 'Home'),
                    selected: _index == 0,
                    onTap: () => setState(() => _index = 0),
                  ),
                  _ToolbarDestination(
                    icon: Icons.search,
                    selectedIcon: Icons.search,
                    label: settings.text('搜尋', 'Search'),
                    selected: _index == 1,
                    onTap: () => setState(() => _index = 1),
                  ),
                  _ToolbarDestination(
                    icon: Icons.campaign_outlined,
                    selectedIcon: Icons.campaign,
                    label: settings.text('快訊', 'News'),
                    selected: _index == 2,
                    onTap: () => setState(() => _index = 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarDestination extends StatelessWidget {
  const _ToolbarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(selected ? selectedIcon : icon),
      label: selected ? Text(label) : const SizedBox.shrink(),
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant,
        backgroundColor: selected
            ? scheme.secondaryContainer
            : Colors.transparent,
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 10),
        shape: const StadiumBorder(),
      ),
    );
  }
}

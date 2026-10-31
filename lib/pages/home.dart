import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int get _index => widget.navigationShell.currentIndex;

  void _selectPage(int index) {
    widget.navigationShell.goBranch(index, initialLocation: index == _index);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final List<String> titles = [
      settings.text('主頁', 'Home'),
      settings.text('路線搜尋', 'Search routes'),
      settings.text('交通快訊', 'Traffic news'),
    ];

    return Scaffold(
      extendBody: true,
      appBar: buildPageBar(
        context,
        title: titles[_index],
        actions: [
          M3EIconButton(
            tooltip: settings.text('設定', 'Settings'),
            variant: M3EIconButtonVariant.standard,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: widget.navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              height: 64,
              child: M3EToolbar(
                expanded: true,
                size: M3EToolbarSize.medium,
                elevation: 0,
                screenOffset: 0,
                safeArea: false,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                actions: [
                  M3EToolbarAction(
                    icon: _index == 0 ? Icons.home : Icons.home_outlined,
                    label: settings.text('主頁', 'Home'),
                    tooltip: settings.text('主頁', 'Home'),
                    active: _index == 0,
                    onPressed: () => _selectPage(0),
                  ),
                  M3EToolbarAction(
                    icon: Icons.search,
                    label: settings.text('搜尋', 'Search'),
                    tooltip: settings.text('搜尋', 'Search'),
                    active: _index == 1,
                    onPressed: () => _selectPage(1),
                  ),
                  M3EToolbarAction(
                    icon: _index == 2
                        ? Icons.campaign
                        : Icons.campaign_outlined,
                    label: settings.text('快訊', 'News'),
                    tooltip: settings.text('快訊', 'News'),
                    active: _index == 2,
                    onPressed: () => _selectPage(2),
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

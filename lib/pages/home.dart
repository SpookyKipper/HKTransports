import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/pages/search_page.dart';
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
    final bool enteringSearch = index == 1 && _index != 1;
    widget.navigationShell.goBranch(index, initialLocation: index == _index);
    if (index == 1) {
      if (enteringSearch && !searchKeypadVisible.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) searchKeypadVisible.value = true;
        });
      } else if (!enteringSearch) {
        searchKeypadVisible.value = true;
      }
    }
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
                fabExpandsToolbar: false,
                floatingActionButton: _SearchKeypadFab(
                  searchActive: _index == 1,
                  onSearch: () => _selectPage(1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                actions: [
                  M3EToolbarWidget(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToolbarDestination(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home,
                          label: settings.text('主頁', 'Home'),
                          selected: _index == 0,
                          onTap: () => _selectPage(0),
                        ),
                        _ToolbarDestination(
                          icon: Icons.campaign_outlined,
                          selectedIcon: Icons.campaign,
                          label: settings.text('快訊', 'News'),
                          selected: _index == 2,
                          onTap: () => _selectPage(2),
                        ),
                      ],
                    ),
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

class _SearchKeypadFab extends StatelessWidget {
  const _SearchKeypadFab({required this.searchActive, required this.onSearch});

  final bool searchActive;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    if (!searchActive) {
      return M3EFab(
        icon: const Icon(Icons.search),
        tooltip: settings.text('搜尋路線', 'Search routes'),
        size: M3EFabSize.regular,
        color: M3EFabColor.secondary,
        onPressed: onSearch,
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: searchKeypadVisible,
      builder: (BuildContext context, bool keypadVisible, _) {
        return M3EFab(
          icon: Icon(
            keypadVisible
                ? Icons.keyboard_hide_outlined
                : Icons.keyboard_outlined,
          ),
          tooltip: keypadVisible
              ? settings.text('隱藏鍵盤', 'Hide keypad')
              : settings.text('顯示鍵盤', 'Show keypad'),
          size: M3EFabSize.regular,
          color: M3EFabColor.secondary,
          onPressed: () => searchKeypadVisible.value = !keypadVisible,
        );
      },
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
    return Tooltip(
      message: label,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(selected ? selectedIcon : icon),
        label: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: selected ? Text(label) : const SizedBox(width: 0, height: 0),
        ),
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
      ),
    );
  }
}

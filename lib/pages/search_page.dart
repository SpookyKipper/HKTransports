import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/route_category.dart';
import 'package:hktransports/bus/model/route_display_name.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/citybus_route_description.dart';
import 'package:hktransports/bus/ui/nlb_route_special_tag.dart';
import 'package:hktransports/bus/ui/route_name_subtitle.dart';
import 'package:hktransports/bus/ui/route_special_tag.dart';
import 'package:hktransports/bus/ui/route_number_pad.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

final ValueNotifier<bool> searchKeypadVisible = ValueNotifier<bool>(true);

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = '';
  RouteCategory _category = RouteCategory.all;

  @override
  void initState() {
    super.initState();
    searchKeypadVisible.addListener(_onKeypadVisibilityChanged);
  }

  @override
  void dispose() {
    searchKeypadVisible.removeListener(_onKeypadVisibilityChanged);
    super.dispose();
  }

  void _onKeypadVisibilityChanged() {
    if (mounted) setState(() {});
  }

  void _appendNumber(String value) {
    setState(() => _query += value);
  }

  void _backspaceNumber() {
    if (_query.isEmpty) return;
    setState(() => _query = _query.substring(0, _query.length - 1));
  }

  void _clearNumber() {
    if (_query.isEmpty) return;
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();

    if (!repository.hasData) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          Center(
            child: Text(settings.text('請先下載路線資料', 'Download route data first')),
          ),
          const SizedBox(height: 16),
          Center(
            child: M3EButton.filled(
              onPressed: () => context.push('/updateData'),
              child: Text(settings.text('下載路線資料', 'Download route data')),
            ),
          ),
        ],
      );
    }

    final List<RouteEntry> allResults = repository.searchRouteNumbers(_query);
    final List<RouteEntry> results = allResults
        .where((RouteEntry route) => routeMatchesCategory(route, _category))
        .toList();
    final double leftColumnWidth = results.fold<double>(
      routeCompactColumnWidth,
      (double width, RouteEntry route) =>
          math.max(width, routeColumnWidth(route, settings.language)),
    );
    final Set<String> possibleChars = repository.possibleRouteChars(_query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildNumberBar(context, settings),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final RouteCategory category in RouteCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category.label(settings.language)),
                      selected: _category == category,
                      onSelected: (bool selected) {
                        if (!selected) return;
                        setState(() => _category = category);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    allResults.isEmpty
                        ? settings.text('沒有符合的路線', 'No matching routes')
                        : settings.text(
                            '此類別沒有符合的路線',
                            'No routes in this category',
                          ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(
                    bottom: searchKeypadVisible.value ? 8 : 120,
                  ),
                  itemCount: results.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final RouteEntry route = results[index];
                    return InkWell(
                      onTap: () {
                        repository.addRecent(route);
                        context.push('/route/${route.slug}');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: leftColumnWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      routeDisplayName(
                                        route,
                                        settings.language,
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  Text(
                                    route.companiesLabel(settings.language),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          height: 1.1,
                                        ),
                                  ),
                                  if (route.isSpecial)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: RouteSpecialTag(
                                          label: settings.text(
                                            '特別班',
                                            'Special',
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    NlbRouteSpecialTag(
                                      route: route,
                                      language: settings.language,
                                      enabled: routeNameEnabled(
                                        route,
                                        settings,
                                      ),
                                      padding: const EdgeInsets.only(top: 2),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
                                  ),
                                  RouteNameSubtitle(
                                    key: ValueKey<String>(
                                      '${route.key}|${settings.language}|'
                                      '${routeNameEnabled(route, settings)}',
                                    ),
                                    route: route,
                                    text: route.orig.get(settings.language),
                                    language: settings.language,
                                    enabled: routeNameEnabled(route, settings),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  CitybusRouteDescription(
                                    route: route,
                                    language: settings.language,
                                    enabled: settings.isProprietaryEnabled(
                                      ProprietaryEndpoint.citybusDatabase,
                                    ),
                                    fallback: '',
                                    builder:
                                        (BuildContext context, String label) {
                                          if (label.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          );
                                        },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (searchKeypadVisible.value)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
            child: RouteNumberPad(
              possibleChars: possibleChars,
              hasQuery: _query.isNotEmpty,
              onCharacter: _appendNumber,
              onBackspace: _backspaceNumber,
              onClear: _clearNumber,
              clearTooltip: settings.text('清除', 'Clear'),
              backspaceTooltip: settings.text('刪除', 'Backspace'),
            ),
          ),
      ],
    );
  }

  Widget _buildNumberBar(BuildContext context, AppSettings settings) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _query.isEmpty ? settings.text('路線號碼', 'Route number') : _query,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _query.isEmpty
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  letterSpacing: _query.isEmpty ? null : 2,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              M3EIconButton(
                tooltip: settings.text('清除', 'Clear'),
                variant: M3EIconButtonVariant.standard,
                onPressed: _clearNumber,
                icon: const Icon(Icons.close),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

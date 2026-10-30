import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/route_number_pad.dart';
import 'package:provider/provider.dart';

enum _SearchMode { number, text }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  _SearchMode _mode = _SearchMode.number;
  String _numberQuery = '';
  String _textQuery = '';

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _appendNumber(String value) {
    setState(() => _numberQuery += value);
  }

  void _backspaceNumber() {
    if (_numberQuery.isEmpty) return;
    setState(
      () => _numberQuery = _numberQuery.substring(0, _numberQuery.length - 1),
    );
  }

  void _clearNumber() {
    if (_numberQuery.isEmpty) return;
    setState(() => _numberQuery = '');
  }

  void _clearText() {
    _textController.clear();
    setState(() => _textQuery = '');
  }

  void _switchToText() {
    FocusScope.of(context).unfocus();
    setState(() => _mode = _SearchMode.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocus.requestFocus();
    });
  }

  void _switchToNumber() {
    FocusScope.of(context).unfocus();
    setState(() => _mode = _SearchMode.number);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();

    if (!repository.hasData) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          SearchBar(
            controller: _textController,
            elevation: const WidgetStatePropertyAll(0),
            hintText: settings.text('路線號碼或目的地', 'Route number or destination'),
            leading: const Icon(Icons.search),
            onChanged: (value) => setState(() => _textQuery = value),
          ),
          const SizedBox(height: 48),
          Center(
            child: Text(settings.text('請先下載路線資料', 'Download route data first')),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => context.push('/updateData'),
              child: Text(settings.text('下載路線資料', 'Download route data')),
            ),
          ),
        ],
      );
    }

    final bool numberMode = _mode == _SearchMode.number;
    final List<RouteEntry> results = numberMode
        ? repository.searchRouteNumbers(_numberQuery)
        : repository.search(_textQuery);
    final Set<String> possibleChars = numberMode
        ? repository.possibleRouteChars(_numberQuery)
        : const {};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: numberMode
              ? _buildNumberBar(context, settings)
              : _buildTextBar(context, settings),
        ),
        if (numberMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: RouteNumberPad(
              possibleChars: possibleChars,
              hasQuery: _numberQuery.isNotEmpty,
              onCharacter: _appendNumber,
              onBackspace: _backspaceNumber,
              onClear: _clearNumber,
              clearTooltip: settings.text('清除', 'Clear'),
              backspaceTooltip: settings.text('刪除', 'Backspace'),
            ),
          ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    settings.text('沒有符合的路線', 'No matching routes'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 112),
                  itemCount: results.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final RouteEntry route = results[index];
                    return ListTile(
                      leading: SizedBox(
                        width: 64,
                        child: Text(
                          route.route,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      title: Text(
                        '${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
                      ),
                      subtitle: Text(
                        '${route.orig.get(settings.language)} · ${route.companiesLabel(settings.language)}',
                      ),
                      trailing: route.isSpecial
                          ? Text(
                              settings.text('特別班', 'Special'),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            )
                          : null,
                      onTap: () {
                        repository.addRecent(route);
                        context.push('/route/${route.slug}');
                      },
                    );
                  },
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
                _numberQuery.isEmpty
                    ? settings.text('路線號碼', 'Route number')
                    : _numberQuery,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _numberQuery.isEmpty
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  letterSpacing: _numberQuery.isEmpty ? null : 2,
                ),
              ),
            ),
            if (_numberQuery.isNotEmpty)
              IconButton(
                tooltip: settings.text('清除', 'Clear'),
                onPressed: _clearNumber,
                icon: const Icon(Icons.close),
              ),
            IconButton(
              tooltip: settings.text('文字搜尋', 'Text search'),
              onPressed: _switchToText,
              icon: const Icon(Icons.keyboard_outlined),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBar(BuildContext context, AppSettings settings) {
    return SearchBar(
      controller: _textController,
      focusNode: _textFocus,
      elevation: const WidgetStatePropertyAll(0),
      hintText: settings.text('路線號碼或目的地', 'Route number or destination'),
      leading: const Icon(Icons.search),
      trailing: [
        if (_textQuery.isNotEmpty)
          IconButton(
            tooltip: settings.text('清除', 'Clear'),
            onPressed: _clearText,
            icon: const Icon(Icons.close),
          ),
        IconButton(
          tooltip: settings.text('數字鍵盤', 'Number pad'),
          onPressed: _switchToNumber,
          icon: const Icon(Icons.dialpad),
        ),
      ],
      onChanged: (value) => setState(() => _textQuery = value),
    );
  }
}

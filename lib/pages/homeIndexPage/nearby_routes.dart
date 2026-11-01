import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/data/nearby_routes.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/route_eta_view.dart';
import 'package:hktransports/location/location_service.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

const String nearbyHomeTabId = '__nearby__';
const List<int> nearbyRadiusOptions = <int>[100, 200, 400];

class NearbyRoutesView extends StatefulWidget {
  const NearbyRoutesView({super.key, required this.active});

  final bool active;

  @override
  State<NearbyRoutesView> createState() => _NearbyRoutesViewState();
}

class _NearbyRoutesViewState extends State<NearbyRoutesView>
    with WidgetsBindingObserver {
  static const LocationService _location = LocationService();

  LocationAccessStatus? _access;
  Position? _position;
  List<NearbyRouteResult> _results = const [];
  bool _loading = false;
  bool _started = false;
  bool _lastEnabled = false;
  int? _computedRadius;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppSettings settings = context.read<AppSettings>();
    final bool wasEnabled = _lastEnabled;
    _lastEnabled = settings.locationEnabled;
    if (!settings.locationEnabled) {
      _started = false;
      return;
    }
    if (!wasEnabled) _started = false;
    if (!widget.active) return;

    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    } else if (_position != null &&
        _access == LocationAccessStatus.granted &&
        _computedRadius != settings.nearbyRadiusMeters) {
      _computedRadius = settings.nearbyRadiusMeters;
      _results = _findRoutes(_position!, settings.nearbyRadiusMeters);
    }
  }

  @override
  void didUpdateWidget(covariant NearbyRoutesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _started = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!context.read<AppSettings>().locationEnabled) return;
        if (_access == LocationAccessStatus.denied ||
            _access == LocationAccessStatus.unsupported) {
          return;
        }
        _refresh();
      });
    } else if (!widget.active) {
      _started = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !widget.active ||
        _loading ||
        !context.read<AppSettings>().locationEnabled) {
      return;
    }
    if (_access != LocationAccessStatus.deniedForever &&
        _access != LocationAccessStatus.serviceDisabled) {
      return;
    }
    unawaited(_refresh());
  }

  List<NearbyRouteResult> _findRoutes(Position position, int radius) {
    final BusRepository repository = context.read<BusRepository>();
    return findNearbyRoutes(
      database: repository.database,
      routesAtStop: repository.routesAtStop,
      latitude: position.latitude,
      longitude: position.longitude,
      radiusMeters: radius.toDouble(),
    );
  }

  Future<void> _refresh() async {
    final AppSettings settings = context.read<AppSettings>();
    if (!settings.locationEnabled) {
      if (mounted) {
        setState(() {
          _loading = false;
          _access = null;
          _position = null;
          _results = const [];
        });
      }
      return;
    }

    final int requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _access = null;
        _position = null;
        _results = const [];
      });
    }

    final LocationAccessStatus access = await _location.requestAccess();
    if (!mounted || requestId != _requestId) return;
    if (access != LocationAccessStatus.granted) {
      setState(() {
        _loading = false;
        _access = access;
      });
      return;
    }

    final Position? position = await _location.currentPosition();
    if (!mounted || requestId != _requestId) return;
    if (!context.read<AppSettings>().locationEnabled) {
      setState(() => _loading = false);
      return;
    }
    if (position == null) {
      setState(() {
        _loading = false;
        _access = LocationAccessStatus.granted;
        _position = null;
      });
      return;
    }

    final int radius = context.read<AppSettings>().nearbyRadiusMeters;
    final List<NearbyRouteResult> results = _findRoutes(position, radius);
    setState(() {
      _loading = false;
      _access = LocationAccessStatus.granted;
      _position = position;
      _computedRadius = radius;
      _results = results;
    });
  }

  Future<void> _enableLocation() async {
    final AppSettings settings = context.read<AppSettings>();
    if (!settings.locationEnabled) {
      settings.setLocationEnabled(true);
      return;
    }
    await _refresh();
  }

  Future<void> _editRadius(int current) async {
    final int? value = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => _RadiusDialog(initialValue: current),
    );
    if (value == null || !mounted) return;
    context.read<AppSettings>().setNearbyRadiusMeters(value);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    if (!settings.locationEnabled) {
      return _LocationMessage(
        icon: Icons.location_off_outlined,
        title: settings.text('定位服務未開啟', 'Location is off'),
        body: settings.text(
          '開啟定位服務後，即可查看附近半徑內的路線。',
          'Enable location to see routes with stops nearby.',
        ),
        actionLabel: settings.text('開啟定位服務', 'Enable location'),
        onAction: _enableLocation,
      );
    }

    if (_loading) {
      return const Center(child: M3ELoadingIndicator());
    }

    final LocationAccessStatus? access = _access;
    if (access == LocationAccessStatus.denied ||
        access == LocationAccessStatus.deniedForever) {
      final bool forever = access == LocationAccessStatus.deniedForever;
      return _LocationMessage(
        icon: Icons.location_disabled_outlined,
        title: settings.text('需要定位權限', 'Location permission required'),
        body: settings.text(
          forever ? '定位權限已被永久拒絕，請在系統設定中允許。' : '允許定位權限後，即可查看附近路線。',
          forever
              ? 'Location permission was permanently denied. Allow it in system settings.'
              : 'Allow location access to see nearby routes.',
        ),
        actionLabel: forever
            ? settings.text('開啟應用程式設定', 'Open app settings')
            : settings.text('授予權限', 'Grant permission'),
        onAction: forever ? _location.openAppSettings : () async => _refresh(),
      );
    }
    if (access == LocationAccessStatus.serviceDisabled) {
      return _LocationMessage(
        icon: Icons.location_off_outlined,
        title: settings.text('系統定位未開啟', 'Location services are off'),
        body: settings.text(
          '請在系統設定中開啟定位服務。',
          'Turn on location services in system settings.',
        ),
        actionLabel: settings.text('開啟定位設定', 'Open location settings'),
        onAction: _location.openLocationSettings,
      );
    }
    if (access == LocationAccessStatus.unsupported) {
      return _LocationMessage(
        icon: Icons.location_off_outlined,
        title: settings.text('此裝置不支援定位', 'Location is not supported'),
        body: settings.text(
          '附近路線需要裝置定位服務。',
          'Nearby routes require device location services.',
        ),
      );
    }
    if (access == null) {
      return const Center(child: M3ELoadingIndicator());
    }
    if (_position == null) {
      return _LocationMessage(
        icon: Icons.location_searching,
        title: settings.text('無法取得位置', 'Could not get location'),
        body: settings.text(
          '請確認定位服務已開啟並再試一次。',
          'Check that location services are on and try again.',
        ),
        actionLabel: settings.text('重試', 'Retry'),
        onAction: _refresh,
      );
    }

    final int radius = settings.nearbyRadiusMeters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRadiusSelector(settings),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  settings.text(
                    '${_results.length} 條路線 · $radius 米內',
                    '${_results.length} routes within $radius m',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              M3EIconButton(
                tooltip: settings.text('重新定位', 'Refresh location'),
                variant: M3EIconButtonVariant.standard,
                onPressed: _refresh,
                icon: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 72, 24, 112),
                  children: [
                    Icon(
                      Icons.location_searching,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      settings.text('此半徑內沒有路線', 'No routes within this radius'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      settings.text(
                        '可嘗試擴大搜尋半徑，或重新定位。',
                        'Try a larger radius or refresh your location.',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 112),
                  itemCount: _results.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final NearbyRouteResult result = _results[index];
                    return _NearbyRouteTile(
                      result: result,
                      showEta: widget.active,
                      onTap: () {
                        repository.addRecent(result.route);
                        final String stopQuery = result.routeStopId.isEmpty
                            ? ''
                            : '?stop=${Uri.encodeQueryComponent(result.routeStopId)}';
                        context.push('/route/${result.route.slug}$stopQuery');
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRadiusSelector(AppSettings settings) {
    final int radius = settings.nearbyRadiusMeters;
    final bool custom = !nearbyRadiusOptions.contains(radius);
    final String customLabel = custom
        ? '$radius m'
        : settings.text('自訂', 'Custom');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final int value in nearbyRadiusOptions)
            ChoiceChip(
              label: Text('$value m'),
              selected: !custom && radius == value,
              onSelected: (bool selected) {
                if (selected) settings.setNearbyRadiusMeters(value);
              },
            ),
          ChoiceChip(
            label: Text(customLabel),
            selected: custom,
            onSelected: (bool selected) => _editRadius(radius),
          ),
        ],
      ),
    );
  }
}

class _LocationMessage extends StatelessWidget {
  const _LocationMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              M3EButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.my_location),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NearbyRouteTile extends StatelessWidget {
  const _NearbyRouteTile({
    required this.result,
    required this.onTap,
    required this.showEta,
  });

  final NearbyRouteResult result;
  final VoidCallback onTap;
  final bool showEta;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final RouteEntry route = result.route;
    final StopEntry stop = result.stop;
    final int seq = result.routeSeq;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    route.route,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    route.companiesLabel(settings.language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
                  ),
                  Text(
                    '${stop.displayName(settings.language)} · '
                    '${_distanceLabel(result.distanceMeters)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (showEta && seq >= 0) ...[
              const SizedBox(width: 8),
              RouteEtaView(route: route, seq: seq),
            ],
          ],
        ),
      ),
    );
  }

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class _RadiusDialog extends StatefulWidget {
  const _RadiusDialog({required this.initialValue});

  final int initialValue;

  @override
  State<_RadiusDialog> createState() => _RadiusDialogState();
}

class _RadiusDialogState extends State<_RadiusDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialValue}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final int? value = int.tryParse(_controller.text.trim());
    if (value == null || value < 20 || value > 2000) {
      setState(() => _error = 'invalid');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return AlertDialog(
      title: Text(settings.text('自訂搜尋半徑', 'Custom search radius')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: settings.text('搜尋半徑（米）', 'Radius (m)'),
          errorText: _error == null
              ? null
              : settings.text('請輸入 20–2000 米', 'Enter 20–2000 m'),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(settings.text('取消', 'Cancel')),
        ),
        M3EButton.text(
          onPressed: _submit,
          child: Text(settings.text('確定', 'Set')),
        ),
      ],
    );
  }
}

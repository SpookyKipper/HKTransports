import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:hkbusapi/kmb/classes.dart';
import 'package:hktransports/customWidgets/nullWidget.dart';
import 'package:hktransports/customWidgets/stackedWidgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../functions/ui.dart';
import '../multiplat_ui.dart';

import 'package:hkbusapi/kmb/functions.dart' as kmb;

class RoutePageRoute extends StatefulWidget {
  const RoutePageRoute({super.key});

  @override
  State<RoutePageRoute> createState() => _RoutePageRouteState();
}

class _RoutePageRouteState extends State<RoutePageRoute> {
  String dest = "Loading...";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final String route = GoRouter.of(context).routeInformationProvider.value.uri.queryParameters['route'] ?? 'N/A';
    // final String bound = GoRouter.of(context).routeInformationProvider.value.uri.queryParameters['bound'] ?? 'N/A';
    // final String servicetype = GoRouter.of(context).routeInformationProvider.value.uri.queryParameters['servicetype'] ?? 'N/A';

    // dev, hot reloads break the URL so hard code it while testing
    final String route = "290A";
    final String bound = "I";
    final String servicetype = "1";

    Future<void> getDest() async {
      final KMBRoute routeData = await kmb.getRoute(
        route: route,
        bound: bound,
        servicetype: servicetype,
      );
      final String dest = routeData.dest[0];
      setState(() {
        this.dest = dest;
      });
    }

    if (dest == "Loading...") {
      getDest();
    }

    return Scaffold(
      appBar: w.appBar(
        context: context,
        title: '$route - $dest',
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
      body: FutureBuilder(
        future: kmb.getRouteStops(
          route: route,
          bound: bound,
          servicetype: servicetype,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: w.loadingIcon(context: context));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No data available'));
          } else {
            // Data is available, build the ListView
            final stops = snapshot.data!;
            return RoutePage(
              routeStops: stops,
              route: route,
              servicetype: servicetype,
              bound: bound,
            ); // Replace with actual data handling
          }
        },
      ), // Use the RoutePage widget
    );
  }
}

class RoutePage extends StatelessWidget {
  final List<KMBRouteStop> routeStops;
  final String route;
  final String servicetype;
  final String bound;

  const RoutePage({
    super.key,
    required this.routeStops,
    required this.route,
    required this.servicetype,
    required this.bound,
  });

  List<StationTile> getStopListUI() {
    return routeStops.map((routeStop) {
      return StationTile(
        stopSeq: routeStop.seq,
        stationName: routeStop.stop.name[0],
        stopid: routeStop.stop.stopid,
        price: 1,
        route: route,
        servicetype: servicetype,
        bound: bound,
      );
    }).toList();
  }

  List<LatLng> getStopLatLngs() {
    return routeStops.map((routeStop) {
      return LatLng(routeStop.stop.lat, routeStop.stop.lng);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            SizedBox(
              height: constraints.maxHeight * 0.4,
              child: //nullWidget(),
              Maptiler(
                latlng: LatLng(22.3193, 114.1694),
                markerPoints: getStopLatLngs(),
                markerWidget: Image(
                  image: AssetImage("assets/images/mapMarkers/kmb.png"),
                ),
              ),
            ),
            Divider(height: 0.025),
            SizedBox(
              height: constraints.maxHeight * 0.6 - 0.025,
              child: ListView(children: getStopListUI()),
            ),
          ],
        );
      },
    );
  }
}

class Maptiler extends StatelessWidget {
  const Maptiler({
    super.key,
    required this.latlng,
    this.markerWidget,
    this.markerPoints,
  });

  final LatLng latlng;
  final Widget? markerWidget;
  final List<LatLng>? markerPoints;

  @override
  Widget build(BuildContext context) {
    if (!((markerWidget != null && markerPoints != null) ||
        (markerWidget == null && markerPoints == null))) {
      throw Exception(
        "Either both markerWidget and markerPoints should be provided, or neither should be provided.",
      );
    }
    final screenHeight = MediaQuery.of(context).size.height;
    // FlutterDisplayMode.active.then((mode) {
    //   print("Current active mode: ${mode.width}x${mode.height} @ ${mode.refreshRate}Hz");
    // });
    return FlutterMap(
      mapController: MapController(),
      options: MapOptions(
        initialZoom: 11.5,
        initialCenter: latlng,
        maxZoom: 22,
        minZoom: 10.5,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            LatLng(22.05729, 113.75606), // Southwest coordinates
            LatLng(22.60008, 114.487967), // Northeast coordinates
          ),
        ),
        interactionOptions: InteractionOptions(
          cursorKeyboardRotationOptions:
              CursorKeyboardRotationOptions.disabled(),
          enableMultiFingerGestureRace: false,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              "https://apiproxy.spookysrv.com/HKTransports/MapTiles/Maptiler/{z}/{x}/{y}",
          // "https://apiproxy.spookysrv.com/HKTransports/MapTiles/{z}/{x}/{y}",
          userAgentPackageName: 'com.spookysrv.hktransports',
          maxNativeZoom: 22,
        ),
        if (markerWidget != null && markerPoints != null)
          MarkerLayer(
            markers: [
              for (var point in markerPoints!)
                Marker(
                  point: point,
                  width: 38,
                  height: 38,
                  child: markerWidget!,
                  alignment: Alignment.topCenter,
                ),
            ],
          ),
        if (screenHeight > 950)
          SimpleAttributionWidget(
            source: SizedBox(
              height: 20,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        launchUrl(Uri.parse('https://maptiler.com/')),
                    child: Text(
                      "© MapTiler",
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright'),
                    ),
                    child: Text(
                      "© OpenStreetMap contributors",
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            alignment: Alignment.bottomRight,
            backgroundColor: Colors.white70,
          ),
        if (screenHeight > 950)
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [],
            showFlutterMapAttribution: false,
            openButton: (_, open) => Row(
              children: [
                LogoSourceAttribution(
                  Image(image: AssetImage('assets/images/maptiler.png')),
                  onTap: () => launchUrl(
                    Uri.parse('https://maptiler.com/'),
                  ), // (external)
                ),
              ],
            ),
            closeButton: (_, close) => nullWidget(),
          ),
        if (screenHeight <= 950)
          RichAttributionWidget(
            alignment: AttributionAlignment.topLeft,
            attributions: [
              TextSourceAttribution(
                'MapTiler',
                onTap: () => launchUrl(
                  Uri.parse('hhttps://maptiler.com/'),
                ), // (external)
              ),
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ), // (external)
              ),
            ],
            showFlutterMapAttribution: false,
            openButton: (_, open) => Row(
              children: [
                IconButton(
                  icon: Icon(Icons.info_outline),
                  color: Colors.black,
                  onPressed: open,
                ),
                LogoSourceAttribution(
                  Image(image: AssetImage('assets/images/maptiler.png')),
                  onTap: () => launchUrl(
                    Uri.parse('https://maptiler.com/'),
                  ), // (external)
                ),
              ],
            ),
            closeButton: (_, close) => nullWidget(),
          ),
      ],
    );
  }
}

class EtaRow extends StatelessWidget {
  final String time;
  final int seconds;
  final int minutes;
  final String? remarks;
  final int etaSeq;
  final int stopSeq;

  const EtaRow({
    super.key,
    required this.time,
    required this.seconds,
    required this.minutes,
    this.remarks,
    required this.etaSeq,
    required this.stopSeq,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.5, top: 2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (minutes > 1)
            Row(
              children: [
                Text(
                  " $time ",
                  style: TextStyle(fontSize: 14.5),
                  strutStyle: StrutStyle(forceStrutHeight: true),
                ),
                SizedBox(width: 5),
                Text(
                  minutes.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: etaSeq == 1
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondaryFixedDim,
                  ),
                  strutStyle: StrutStyle(forceStrutHeight: true),
                ),
                SizedBox(width: 3),
                Text(
                  "分鐘",
                  style: TextStyle(fontSize: 13.5),
                  strutStyle: StrutStyle(forceStrutHeight: true),
                ),
                SizedBox(width: 5),
              ],
            ),
          if (minutes <= 1) SizedBox(width: 4),
          if (minutes == 1 && seconds > 14)
            Text(
              stopSeq == 1 ? "準備出車  " : "即將到達  ",
              style: TextStyle(
                fontSize: 16,
                // fontWeight: FontWeight.bold,
                color: etaSeq == 1
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryFixedDim,
              ),
              strutStyle: StrutStyle(forceStrutHeight: true),
            ),
          if (seconds <= 14 && seconds > -7)
            Text(
              "已到達  ",
              style: TextStyle(
                fontSize: 16,
                // fontWeight: FontWeight.bold,
                color: etaSeq == 1
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryFixedDim,
              ),
              // strutStyle: StrutStyle(forceStrutHeight: true),
            ),
          if (seconds <= -7)
            Text(
              "正在離開  ",
              style: TextStyle(
                fontSize: 16,
                // fontWeight: FontWeight.bold,
                color: etaSeq == 1
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryFixedDim,
              ),
              // strutStyle: StrutStyle(forceStrutHeight: true),
            ),
          Text(
            remarks ?? "",
            style: TextStyle(
              fontSize: 13.5,
              color: Theme.of(context).colorScheme.outline,
            ),
            strutStyle: StrutStyle(forceStrutHeight: true),
          ),
        ],
      ),
    );
  }
}

class StationTile extends StatefulWidget {
  const StationTile({
    super.key,
    required this.stopSeq,
    required this.stationName,
    required this.price,
    required this.stopid,
    required this.route,
    required this.servicetype,
    required this.bound,
  });

  final int stopSeq;
  final String stopid;
  final String route;
  final String bound;
  final String servicetype;
  final String stationName;
  final double price;

  @override
  State<StationTile> createState() => _StationTileState();
}

class _StationTileState extends State<StationTile> {
  DateTime? _lastFetched;
  List<Widget> _etarows = [];
  bool _hasFetchedOnce = false;
  Timer? _refreshTimer;

  Future<void> fetchEta() async {
    // await Future.delayed(Duration(milliseconds: 1000)); // Simulate network delay
    setState(() {
      _etarows = [w.loadingIcon(context: context)];
    });
    final List<KMBEta> etas = await kmb.getEta(
      stopid: widget.stopid,
      route: widget.route,
      servicetype: widget.servicetype,
      bound: widget.bound,
    );
    // print("ETA FETCHED: $etas");
    setState(() {
      _lastFetched = DateTime.now();
      _hasFetchedOnce = true;
      if (etas.isEmpty) {
        _etarows = [
          Text(
            "暫無資料 No Data",
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
        ];
      } else {
        _etarows = etas.map((eta) {
          DateTime now = DateTime.now();
          Duration difference = eta.eta.difference(now);
          int seconds = difference.inSeconds;
          int minutes = difference.inMinutes;

          return EtaRow(
            time: DateFormat('HH:mm').format(eta.eta),
            seconds: seconds,
            minutes: minutes,
            remarks: eta.remarks.isEmpty ? null : eta.remarks[0],
            etaSeq: eta.etaSeq,
            stopSeq: widget.stopSeq,
          );
        }).toList();
      }
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: 17), (timer) {
      fetchEta();
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String originalName = widget.stationName;
    final RegExp platformRegex = RegExp(r' \([A-Z][0-9]{1,2}\)');
    final RegExp stationCodeRegex = RegExp(r' \([A-Z]{2}[0-9]{3}\)');

    final String? stationCode = stationCodeRegex
        .firstMatch(originalName)
        ?.group(0);
    final String? platformCode = platformRegex
        .firstMatch(originalName)
        ?.group(0);
    final String processedName = originalName
        .replaceFirst("$stationCode", "")
        .replaceFirst("$platformCode", "");

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            SizedBox(
              width: 30,
              child: Center(
                child: Text(
                  widget.stopSeq.toString(),
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stackedWidgets(
                  nullWidget(),
                  Text(processedName, style: TextStyle(fontSize: 18.5)),
                  Row(
                    children: [
                      Text(
                        "車費 \$${widget.price}",
                        style: TextStyle(fontSize: 15),
                      ),

                      if (stationCode != null)
                        Text(
                          " • 站碼 ${stationCode.replaceFirst(" (", "").replaceFirst(")", "")}",
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      if (platformCode != null)
                        Text(
                          " • 月台 ${platformCode.replaceFirst(" (", "").replaceFirst(")", "")}",
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          ListTile(
            title: Padding(
              padding: EdgeInsets.only(left: 10, bottom: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _etarows.isNotEmpty
                    ? _etarows
                    : [w.loadingIcon(context: context)],
              ),
            ),
          ),
        ],
        onExpansionChanged: (expanded) {
          if (expanded) {
            final now = DateTime.now();
            if (!_hasFetchedOnce ||
                _lastFetched == null ||
                now.difference(_lastFetched!).inSeconds >= 10) {
              fetchEta();
            }
            _startAutoRefresh();
          } else {
            _stopAutoRefresh();
          }
        },
      ),
    );
  }
}

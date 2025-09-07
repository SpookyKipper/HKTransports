import 'package:flutter_map/flutter_map.dart';
import 'package:hktransports/customWidgets/nullWidget.dart';
import 'package:hktransports/customWidgets/stackedWidgets.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../functions/ui.dart';
import '../multiplat_ui.dart';

import 'package:go_router/go_router.dart';

class RoutePageRoute extends StatelessWidget {
  const RoutePageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    // String route = GoRouter.of(context).routeInformationProvider.value.uri.queryParameters['route'] ?? 'N/A';
    // String bound = GoRouter.of(context).routeInformationProvider.value.uri.queryParameters['bound'] ?? 'N/A';

    // dev
    String route = "290A";
    String bound = "I";

    return Scaffold(
      appBar: w.appBar(
        context: context,
        title: "$route - $bound",
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
      body: RoutePage(), // Use the RoutePage widget
    );
  }
}

class RoutePage extends StatelessWidget {
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
              ),
            ),
            Divider(height: 0.025),
            SizedBox(
              height: constraints.maxHeight * 0.6 - 0.025,
              child: ListView(
                children: [
                  StationTile(stopnum: 10, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                  StationTile(stopnum: 1, station: "彩明", price: 1),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class Maptiler extends StatelessWidget {
  const Maptiler({super.key, required this.latlng});

  final LatLng latlng;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // FlutterDisplayMode.active.then((mode) {
    //   print("Current active mode: ${mode.width}x${mode.height} @ ${mode.refreshRate}Hz");
    // });
    return FlutterMap(
      mapController: MapController(),
      options: MapOptions(
        initialZoom: 13.0,
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
                    onPressed: () =>
                        launchUrl(Uri.parse('https://openstreetmap.org/')),
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
                  Uri.parse('https://www.openstreetmap.org/'),
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

class StationTile extends StatelessWidget {
  const StationTile({
    super.key,
    required this.stopnum,
    required this.station,
    required this.price,
  });

  final int stopnum;
  final String station;
  final double price;

  @override
  Widget build(BuildContext context) {
    return Container( // remove for no border
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            // Leading section
            SizedBox(
              width: 30,
              child: Center(
                child: Text(
                  stopnum.toString(),
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            SizedBox(width: 20),
            // Title and subtitle section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stackedWidgets(
                  nullWidget(),
                  Text(station, style: TextStyle(fontSize: 20)),
                  Text("車費: \$$price", style: TextStyle(fontSize: 15)),
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
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                     
                      Text(
                        " 12:30 ",
                        style: TextStyle(fontSize: 14.5),
                        strutStyle: StrutStyle(forceStrutHeight: true),
                      ),
                      SizedBox(width: 5),
                      Text(
                        "10",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        strutStyle: StrutStyle(forceStrutHeight: true),
                      ),
                      SizedBox(width: 3),
                      Text(
                        "分鐘",
                        style: TextStyle(fontSize: 13.5),
                        strutStyle: StrutStyle(forceStrutHeight: true),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      
                      Text(
                        " 12:30 ",
                        style: TextStyle(fontSize: 14.5),
                        strutStyle: StrutStyle(forceStrutHeight: true),
                      ),
                      SizedBox(width: 5),
                      Text(
                        "10",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        strutStyle: StrutStyle(forceStrutHeight: true),
                      ),
                      SizedBox(width: 2),
                      Text(
                        "分鐘",
                        style: TextStyle(fontSize: 13.5),
                        strutStyle: StrutStyle(forceStrutHeight: true),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      
                      Text(
                        " 12:30 ",
                        style: TextStyle(fontSize: 14.5),
                        strutStyle: StrutStyle(forceStrutHeight: true),
                      ),
                      SizedBox(width: 5),
                      Text(
                        "10",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        strutStyle: StrutStyle(forceStrutHeight: true),
                      ),
                      SizedBox(width: 2),
                      Text(
                        "分鐘",
                        style: TextStyle(fontSize: 13.5),
                        strutStyle: StrutStyle(forceStrutHeight: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

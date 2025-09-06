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
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: Mapbox(latlng: LatLng(22.3193, 114.1694)),
    );
  }
}

class Mapbox extends StatelessWidget {
  const Mapbox({super.key, required this.latlng});

  final LatLng latlng;

  @override
  Widget build(BuildContext context) {

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
            LatLng(22.628782, 114.427859), // Northeast coordinates
          ),
        ),
        interactionOptions: InteractionOptions(
          cursorKeyboardRotationOptions: CursorKeyboardRotationOptions.disabled(),
          enableMultiFingerGestureRace: false,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              "https://apiproxy.spookysrv.com/HKTransports/MapTiles/{z}/{x}/{y}",
          userAgentPackageName: 'com.spookysrv.hktransports',
          maxNativeZoom: 22,
        ),
        RichAttributionWidget(
          alignment: AttributionAlignment.topLeft,
          attributions: [
            TextSourceAttribution(
              'Mapbox',
              onTap: () => launchUrl(
                Uri.parse('https://www.mapbox.com/about/maps'),
              ), // (external)
            ),
            TextSourceAttribution(
              'OpenStreetMap',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright/'),
              ), // (external)
            ),
            TextSourceAttribution(
              'Improve this map',
              onTap: () => launchUrl(
                Uri.parse('https://apps.mapbox.com/feedback/'),
              ), // (external)
              prependCopyright: false,
            ),
          ],
          showFlutterMapAttribution: false,
          openButton: (_, open) => LogoSourceAttribution(
              Image(image: AssetImage('assets/images/mapbox-logo-black.png')),
              onTap: open, // (external)
            ),
          closeButton: (_, close) => Column( // TODO: cannot click links above
            children: [
              SizedBox(height: 63),
              w.button(context: context, child: Row(
                children: [
                  Icon(Icons.close),
                  Text(" Close")
                ],
              ), onPressed: close),
            ],
          )
        ),
        
      ],
    );
  }
}

class StationTile extends StatelessWidget {
  const StationTile({
    super.key,
    required this.route,
    required this.operator,
    required this.dest,
    required this.onBoardStop,
  });

  final String route;
  final String operator;
  final String dest;
  final String onBoardStop;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        GestureDetector(
          onTap: () => {context.pushNamed('/route?route=$route&bound=I')},
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  // Leading section
                  stackedWidgets(
                    nullWidget(),
                    Text(route, style: TextStyle(fontSize: 20)),
                    Text(operator, style: TextStyle(fontSize: 12)),
                  ),
                  Padding(padding: EdgeInsets.only(right: 10)),
                  // Title and subtitle section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      stackedWidgets(
                        nullWidget(),
                        Row(
                          children: [
                            Column(
                              children: [
                                Padding(padding: EdgeInsets.only(top: 5.5)),
                                Text("往 ", style: TextStyle(fontSize: 15)),
                              ],
                            ),
                            Text(dest, style: TextStyle(fontSize: 20)),
                          ],
                        ),
                        Text(onBoardStop, style: TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                  Spacer(),
                  // Trailing section
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.access_time, size: 15.8),
                              Padding(padding: EdgeInsets.only(bottom: 2.25)),
                            ],
                          ),
                          Text(
                            " 12:30 ",
                            style: TextStyle(fontSize: 16.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          Text(
                            "10",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          SizedBox(width: 3),
                          Text(
                            "分鐘",
                            style: TextStyle(fontSize: 16.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 13),
                          Text(
                            " 12:30 ",
                            style: TextStyle(fontSize: 13.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          Text(
                            "10",
                            style: TextStyle(
                              fontSize: 15,
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
                      SizedBox(height: 2.5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 13),
                          Text(
                            " 12:30 ",
                            style: TextStyle(fontSize: 13.5),
                            strutStyle: StrutStyle(forceStrutHeight: true),
                          ),
                          Text(
                            "10",
                            style: TextStyle(
                              fontSize: 15,
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
                ],
              ),
            ),
          ),
        ),
        //
      ],
    );
  }
}

<p align="center">
  <img src="assets/images/logo.png" width="104" alt="HKTransports icon">
</p>

<h1 align="center">HKTransports</h1>

<p align="center">
  A clean, fast and flexible Hong Kong public transport app for real-time bus and minibus arrivals.
</p>

HKTransports brings routes, stops, arrivals, nearby services, maps, timetables, notices and interchange information together in one place. It is built for everyday use in Hong Kong, with an interface available in Chinese and English.

## Features

### Real-time arrivals

- Live ETA information for KMB, Citybus, NLB, green minibus and MTR feeder services.
- See the next arrivals for any route and stop.
- Search routes by number and browse all directions and service variants.
- See route timetables, service-day information and estimated journey times.
- Follow live traffic news from the Transport Department.

### Favourites and home screen

- Save routes and stops for quick access.
- Organise routes into custom favourite groups.
- Reorder custom groups and the default Favourites group.
- Pin frequently used stops for at-a-glance arrival information.
- The home screen remembers your last-used tab.

### Nearby routes

- Find routes with stops within a selected radius of your current location.
- Choose 100 m, 200 m, 400 m or a custom radius.
- Results are ordered by distance and show the nearest stop for each route.
- Opening a nearby route automatically focuses the relevant stop.
- Location is optional and disabled by default.

### Route details and maps

- View the full route and all stops on an interactive map.
- Automatically focus the nearest station when it is within 2 km; otherwise, the whole route is shown.
- Use the locate button to show your current position, accuracy circle and travel direction.
- Your map position and direction update as you move or turn.
- Switch between route directions with a smooth in-place crossfade.
- See official operator links, route remarks and operator notices in the same place.

### Optional direct operator data

HKTransports can optionally connect directly to selected operator data sources. These features are **off by default** and can be enabled one source at a time in Settings.

When enabled, the app can provide:

- **Direct interchange discount information** from KMB and Citybus, with first-leg and second-leg views and route search.
- **Operator passenger notices**, including KMB route news and Citybus special, route and stop notices.
- **Citybus route names**, such as line names shown in search results, the home screen and route details.
- **Citybus remarks**, including fare remarks and other route notes, with Bus-Bus Interchange sections removed.
- **Correct operator branding**, showing Cityflyer for Citybus airport routes and LWB for Long Win routes while keeping the original operator data underneath.

All optional operator requests are made directly from your device. No proxy server is used.

> These sources are not fully licensed and are not affiliated with or endorsed by the operators. Enabling them may be subject to the operators' terms of use. Use them at your own risk.

### Interface

- Chinese and English interface.
- Light, dark and system themes, including dynamic colour options.
- Adjustable text size and page transitions.
- Clean layouts designed for quick scanning at a bus stop.

## What makes HKTransports different?

Many Hong Kong transport apps stop at arrival times. HKTransports goes further by bringing the useful operator information into the app while keeping it optional and transparent:

- **Interchange discounts are readable inside the app**, not just hidden behind an operator website or a single external link.
- **Passenger notices are integrated by route and stop**, so service changes and special arrangements are easier to find.
- **Citybus route names and fare/route remarks** appear where they are useful instead of requiring a separate lookup.
- **Operator branding is presented correctly**, including Cityflyer and LWB, without changing the underlying operator data.
- **Optional proprietary sources are controlled individually**, so you can choose exactly how much direct operator data you want to use.
- **Nearby routes and the route map are designed around the stop you actually need**, with distance-aware results, nearest-station focus and live location direction.
- **No proxy is used for optional operator sources** — requests go directly from your device.

## Installation

### Method 1: F-Droid (Recommended)

You may get this app from the F-Droid repository:

**https://repo.spookysrv.com/fdroid/repo/**

Add the repository to your F-Droid client, then install HKTransports from there. Updates are delivered automatically through F-Droid.

> **Note:** This is not the official F-Droid repository. Anti-Features may not be fully accurate according to the official F-Droid definitions.

### Method 2: APK sideload

Download the latest APK from the Releases page:

**https://github.com/SpookyKipper/HKTransports/releases**

HKTransports does not check for updates itself. To stay up to date, check the Releases page periodically, or add the Releases page to an update tracker such as [Obtainium](https://github.com/ImranR98/Obtainium) so you are notified when a new APK is available.

## Data and privacy

- Route and stop information is downloaded to your device and can be browsed without a live connection.
- Live arrivals, optional operator notices, route names and remarks require an internet connection.
- Location is off by default. When enabled, it is used for nearby routes and the route map.
- Optional operator requests are sent directly from your device, without a proxy.

## Credits

HKTransports is inspired by [HK Bus ETA (hkbus.app)](https://hkbus.app), originally started by [Law Wai Chun (chunlaw)](https://github.com/chunlaw) and built with many [contributors](https://github.com/hkbus/hk-independent-bus-eta/graphs/contributors). The route data, arrival logic and user experience in this app draw heavily from that project.

Source code for the original project: [github.com/hkbus/hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta).

### Data sources

- [DATA.GOV.HK](https://data.gov.hk)
- [HK Bus Crawling](https://github.com/SpookyKipper/hk-bus-crawling/)
- [Transport Route Waypoints](https://github.com/SpookyKipper/hk-transports-route-waypoints)
- [Common Spatial Data Infrastructure](https://portal.csdi.gov.hk)
- KMB, Citybus, NLB, Green Minibus, MTR and the ferry operators
- [HK Bus ETA notices](https://notice.hkbus.app)
- [Transport Department traffic news](https://www.td.gov.hk/tc/special_news/trafficnews.xml)

### Map data

- [Lands Department](https://api.portal.hkmapservice.gov.hk/disclaimer)
- [CSDI](https://portal.csdi.gov.hk)

## License

The original HK Bus ETA project and the `hk-bus-eta` package are licensed under GPL-3.0-only. This project follows the same license. See [LICENSE](LICENSE).

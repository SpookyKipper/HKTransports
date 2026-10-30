import 'package:flutter/material.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class OfficialLinks extends StatelessWidget {
  const OfficialLinks({super.key, required this.route});

  final RouteEntry route;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final List<BusCompany> companies = route.sortedCompanies;
    final List<Widget> buttons = [];
    for (final BusCompany company in companies) {
      final String url = officialUrl(
        route: route,
        company: company,
        language: settings.language,
      );
      if (url.isEmpty) continue;
      buttons.add(
        M3EButton.icon(
          onPressed: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          style: M3EButtonStyle.text,
          icon: const Icon(Icons.open_in_new),
          label: Text(company.label(settings.language)),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.text('官方路線資料', 'Official route information'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: buttons),
        ],
      ),
    );
  }
}

String officialUrl({
  required RouteEntry route,
  required BusCompany company,
  required String language,
}) {
  final bool zh = language != 'en';
  switch (company) {
    case BusCompany.ctb:
      return 'https://mobile.citybus.com.hk/nwp3/?f=1&ds=${route.route}'
          '&dsmode=1&l=${zh ? 0 : 1}';
    case BusCompany.kmb:
      return 'https://search.kmb.hk/KMBWebSite/?action=routesearch'
          '&route=${route.route}&lang=${zh ? 'zh-hk' : 'en'}';
    case BusCompany.gmb:
      final String? gtfsId = route.gtfsId;
      if (gtfsId == null) return '';
      return 'https://h2-app-rr.hkemobility.gov.hk/ris_page/get_gmb_detail.php'
          '?lang=${zh ? 'TC' : 'EN'}&route_id=$gtfsId';
    case BusCompany.nlb:
      return 'https://www.nlb.com.hk/${zh ? 'tc' : 'en'}/route?q=${route.route}';
    case BusCompany.lrtfeeder:
      return 'https://www.mtr.com.hk/${zh ? 'ch' : 'en'}'
          '/customer/services/searchBusRouteDetails.php?routeID=${route.route}';
    case BusCompany.lightRail:
      return 'https://www.mtr.com.hk/${zh ? 'ch' : 'en'}'
          '/customer/services/schedule_index.html';
    case BusCompany.mtr:
      return 'https://www.mtr.com.hk/${zh ? 'ch' : 'en'}'
          '/customer/services/train_service_index.html';
    case BusCompany.sunferry:
    case BusCompany.fortuneferry:
    case BusCompany.hkkf:
      return '';
  }
}

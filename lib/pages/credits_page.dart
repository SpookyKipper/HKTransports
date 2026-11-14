import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: buildPageBar(context, title: settings.text('鳴謝', 'Credits')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SectionTitle(settings.text('原項目', 'Original project')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              settings.text(
                'HK Bus ETA（hkbus.app）由 Law Wai Chun（chunlaw）發起，並由一眾貢獻者共同開發。本應用程式的路線資料、到站時間邏輯及使用體驗均受該項目啟發。',
                'HK Bus ETA (hkbus.app) was started by Law Wai Chun (chunlaw) and built with many contributors. This app is inspired by its route data, arrival logic and user experience.',
              ),
            ),
          ),
          _LinkTile(
            icon: Icons.code,
            title: settings.text('HK Bus ETA 原始碼', 'HK Bus ETA source code'),
            subtitle: 'github.com/hkbus/hk-independent-bus-eta',
            url: 'https://github.com/hkbus/hk-independent-bus-eta',
          ),
          const Divider(),
          _SectionTitle(settings.text('資料來源', 'Data sources')),
          _LinkTile(
            icon: Icons.data_object,
            title: 'DATA.GOV.HK',
            subtitle: settings.text('香港開放數據', 'Hong Kong open data'),
            url: 'https://data.gov.hk',
          ),
          _LinkTile(
            icon: Icons.route,
            title: 'HK Bus Crawling',
            subtitle: settings.text('路線及收費資料', 'Route and fare data'),
            url: 'https://github.com/SpookyKipper/hk-bus-crawling/',
          ),
          _LinkTile(
            icon: Icons.schedule,
            title: 'HK Bus Time Between Stops',
            subtitle: settings.text(
              '歷史車站之間車程資料',
              'Historical stop-to-stop journey times',
            ),
            url: 'https://github.com/HK-Bus-ETA/hk-bus-time-between-stops',
          ),
          _LinkTile(
            icon: Icons.alt_route,
            title: 'Transport Route Waypoints',
            subtitle: settings.text('路線走線資料', 'Route alignment data'),
            url:
                'https://github.com/SpookyKipper/hk-transports-route-waypoints',
          ),
          _LinkTile(
            icon: Icons.map_outlined,
            title: 'CSDI',
            subtitle: settings.text('空間數據', 'Spatial data'),
            url: 'https://portal.csdi.gov.hk',
          ),
          _LinkTile(
            icon: Icons.directions_bus,
            title: settings.text('公共交通營運商', 'Public transport operators'),
            subtitle: 'KMB, Citybus, NLB, GMB, MTR',
            url:
                'https://data.gov.hk/en-data/dataset/hk-td-tis_3-routes-and-fares-of-public-transport',
          ),
          const Divider(),
          _SectionTitle(settings.text('地圖', 'Map')),
          _LinkTile(
            icon: Icons.map_outlined,
            title: settings.text('地政總署', 'Lands Department'),
            subtitle: settings.text(
              '© 地圖由地政總署提供',
              '© Map provided by Lands Department',
            ),
            url: 'https://api.portal.hkmapservice.gov.hk/disclaimer',
          ),
          _LinkTile(
            icon: Icons.layers_outlined,
            title: settings.text('地理空間數據', 'GeoData Hong Kong'),
            subtitle: settings.text('地圖標籤', 'Map labels'),
            url: 'https://portal.csdi.gov.hk',
          ),
          const Divider(),
          _SectionTitle(settings.text('其他', 'Other')),
          _LinkTile(
            icon: Icons.traffic_outlined,
            title: settings.text('交通快訊（運輸署）', 'Traffic news (TD)'),
            subtitle: 'www.td.gov.hk',
            url: 'https://www.td.gov.hk/tc/special_news/trafficnews.xml',
          ),
          _LinkTile(
            icon: Icons.traffic_outlined,
            title: settings.text(
              '交通快訊（DATA.GOV.HK）',
              'Traffic news (DATA.GOV.HK)',
            ),
            subtitle: 'resource.data.one.gov.hk',
            url:
                'https://resource.data.one.gov.hk/td/en/specialtrafficnews.xml?date=1',
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(settings.text('開源授權', 'Open source licenses')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/licenses'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}

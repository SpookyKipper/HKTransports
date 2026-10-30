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
          _LinkTile(
            icon: Icons.public,
            title: 'hkbus.app',
            subtitle: settings.text('原網站', 'Original website'),
            url: 'https://hkbus.app',
          ),
          _LinkTile(
            icon: Icons.people_outline,
            title: settings.text('貢獻者', 'Contributors'),
            subtitle: settings.text('完整名單', 'Full list'),
            url:
                'https://github.com/hkbus/hk-independent-bus-eta/graphs/contributors',
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
            url: 'https://github.com/hkbus/hk-bus-crawling',
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
                'https://data.gov.hk/en-data/dataset/hk-td-tis_18-transport-routes-and-fares',
          ),
          const Divider(),
          _SectionTitle(settings.text('地圖', 'Map')),
          _LinkTile(
            icon: Icons.copyright,
            title: 'OpenStreetMap',
            subtitle: settings.text('地圖資料', 'Map data'),
            url: 'https://www.openstreetmap.org/copyright',
          ),
          _LinkTile(
            icon: Icons.map,
            title: 'TomTom',
            subtitle: settings.text('地圖及交通資料', 'Map and traffic data'),
            url: 'https://www.tomtom.com/legal/en_gb/product-attributions/',
          ),
          _LinkTile(
            icon: Icons.layers_outlined,
            title: 'MapTiler',
            subtitle: settings.text('地圖圖層', 'Map tiles'),
            url: 'https://www.maptiler.com/',
          ),
          const Divider(),
          _SectionTitle(settings.text('其他', 'Other')),
          _LinkTile(
            icon: Icons.campaign_outlined,
            title: settings.text('通知', 'Notices'),
            subtitle: 'notice.hkbus.app',
            url: 'https://notice.hkbus.app',
          ),
          _LinkTile(
            icon: Icons.traffic_outlined,
            title: settings.text('交通快訊', 'Traffic news'),
            subtitle: settings.text('運輸署', 'Transport Department'),
            url: 'https://www.td.gov.hk/tc/special_news/trafficnews.xml',
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(settings.text('開源授權', 'Open source licenses')),
            subtitle: Text(
              settings.text(
                '本應用程式採用 GPL-3.0 授權。',
                'This app is licensed under GPL-3.0.',
              ),
            ),
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

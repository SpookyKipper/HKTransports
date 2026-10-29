import 'package:flutter/material.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: Text(settings.text('鳴謝', 'Credits'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            settings.text(
              '香港巴士到站預報由 HK Bus ETA 項目啟發。',
              'HKTransports is inspired by the HK Bus ETA project.',
            ),
          ),
        ],
      ),
    );
  }
}

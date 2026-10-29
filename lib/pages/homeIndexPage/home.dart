import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.text('香港巴士到站預報', 'Hong Kong bus arrivals'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  settings.text(
                    '路線與車站資料會儲存在裝置上，只有到站時間需要網絡。',
                    'Routes and stops are stored on this device. Only arrival times need the network.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => context.push('/updateData'),
          icon: const Icon(Icons.download_outlined),
          label: Text(settings.text('更新路線資料', 'Update route data')),
        ),
      ],
    );
  }
}

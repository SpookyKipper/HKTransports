import 'package:flutter/material.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class UpdateDataPageRoute extends StatefulWidget {
  const UpdateDataPageRoute({super.key});

  @override
  State<UpdateDataPageRoute> createState() => _UpdateDataPageRouteState();
}

class _UpdateDataPageRouteState extends State<UpdateDataPageRoute> {
  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: Text(settings.text('更新資料', 'Update data'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_download_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                settings.text(
                  '路線資料更新將於下一個版本提供。',
                  'Route data updates will be available in the next build.',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

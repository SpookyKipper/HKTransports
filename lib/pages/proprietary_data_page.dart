import 'package:flutter/material.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/proprietary_settings_section.dart';
import 'package:provider/provider.dart';

class ProprietaryDataPage extends StatelessWidget {
  const ProprietaryDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: buildPageBar(
        context,
        title: settings.text('專有 API', 'Proprietary APIs'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 24),
        child: ProprietarySettingsSection(),
      ),
    );
  }
}

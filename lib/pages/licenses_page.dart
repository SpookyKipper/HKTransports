import 'package:flutter/material.dart';

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LicensePage(
      applicationName: 'HKTransports',
      applicationLegalese:
          'Based on HK Bus ETA by Law Wai Chun and contributors. GPL-3.0-only.',
    );
  }
}

import 'package:flutter/material.dart';

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LicensePage(
      applicationName: 'HKTransports',
      applicationLegalese: 'This app is licensed under GPL-3.0',
    );
  }
}

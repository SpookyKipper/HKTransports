import 'package:flutter/material.dart';

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LicensePage(
      applicationName: 'HKTransports',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/logo.png',
          width: 72,
          height: 72,
          fit: BoxFit.cover,
        ),
      ),
      applicationLegalese: 'This app is licensed under GPL-3.0',
    );
  }
}

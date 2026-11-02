import 'package:flutter/material.dart';
import 'package:hktransports/functions/app.dart';

class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  String? _version;
  String? _buildNumber;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final List<String> values = await Future.wait(<Future<String>>[
      af.getVersion(),
      af.getBuildNumber(),
    ]);
    if (!mounted) return;
    setState(() {
      _version = values[0];
      _buildNumber = values[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? version = _version == null
        ? null
        : 'Version $_version ($_buildNumber)';
    return LicensePage(
      applicationName: 'HKTransports',
      applicationVersion: version,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/logo.png',
          width: 72,
          height: 72,
          fit: BoxFit.cover,
        ),
      ),
      applicationLegalese:
          '© Spooky Kipper\nThis app is licensed under GPL-3.0',
    );
  }
}

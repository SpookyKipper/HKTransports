import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hkbusapi/universal/functions.dart';
import 'package:hktransports/dataStore/objectbox.dart';
import '../multiplat_ui.dart';

import 'package:hkbusapi/kmb/functions.dart' as kmb;

class UpdateDataPageRoute extends StatefulWidget {
  const UpdateDataPageRoute({super.key});

  @override
  State<UpdateDataPageRoute> createState() => _UpdateDataPageRouteState();
}

class _UpdateDataPageRouteState extends State<UpdateDataPageRoute> {
  String updateStatus = "準備開始更新 Preparing to update...";

  @override
  void initState() {
    super.initState();
    _updateData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _updateData() async {
    setState(() {
      updateStatus = "正在下載路線資料 Downloading route data...";
    });
    await kmb.saveAllRoutes();
    await refreshUniversalData();
    setState(() {
      updateStatus = "✅ 成功更新路線資料 Route data update successful";
    });
    setState(() {
      updateStatus = "正在下載車站資料 Downloading stop data...";
    });
    await kmb.saveAllStops();
    setState(() {
      updateStatus = "✅ 成功更新車站資料 Stop data update successful";
    });
    
    await Future.delayed(Duration(milliseconds: 100));
    setState(() {
      updateStatus = "更新完成 Update complete!";
    });
    sp.setInt("dataLastUpdated", DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await Future.delayed(Duration(milliseconds: 100));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(
            child: Text(
              '✅ 資料更新成功 Data update successful',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17.5),
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(50),
          duration: Duration(milliseconds: 2500),
        ),
      );
      final String returnPage =
          GoRouter.of(
            context,
          ).routeInformationProvider.value.uri.queryParameters['return'] ??
          'N/A';
      if (returnPage == 'home') {
        context.go('/');
      } else {
        context.go('/?return=settings');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更新資料 Update Data')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            w.loadingIcon(context: context),
            SizedBox(height: 20),
            Text(updateStatus),
          ],
        ),
      ),
    );
  }
}

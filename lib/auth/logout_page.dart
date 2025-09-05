import 'package:hktransports/dataStore/shared_preferences.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:http/http.dart' as http;
import 'package:hktransports/multiplat_ui.dart';
import 'package:flutter/material.dart';
import 'package:protocol_handler/protocol_handler.dart';

class LogoutPageRoute extends StatelessWidget {
  const LogoutPageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LogoutPage(), // Use the SettingsPage widget
    );
  }
}

class LogoutPage extends StatefulWidget {
  @override
  _LogoutPageState createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> with ProtocolListener {
  String _statusText = "Logging out...";

  Future<void> _logout() async {
    final url = Uri.parse('https://flow.spookysrv.com/logout');
    final headers = {'Content-Type': 'application/x-www-form-urlencoded'};
    String? device = await sp.getString("convoToken");
    final body = {'device': device};

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200 && response.body == "success") {
      setState(() {
        _statusText = "Clearing device session data...";
      });
      bool res =
          await sp.removeValue("startingPage") &&
          await sp.removeValue("convoToken") &&
          await sp.removeValue("deviceId");
      if (res == true) {
        setState(() {
        _statusText = "Logout success!";
      });
        Phoenix.rebirth(context);
      }
    } else {
      print('Error: ${response.statusCode} ${response.body}');
    }
  }

  @override
  void initState() {
    _logout();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(child: w.loadingIcon(context: context)),
            SizedBox(height: 50),
            Center(child: Text(_statusText, style: TextStyle(fontSize: 20))),
          ],
        ),
      ),
    );
  }
}

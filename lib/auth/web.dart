import 'dart:convert';
import 'package:flow_by_spooky_services/dataStore/shared_preferences.dart';
import 'package:flow_by_spooky_services/pages/chat_page.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:http/http.dart' as http;
import 'package:flow_by_spooky_services/multiplat_ui.dart';
import 'package:flutter/material.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'dart:html' as html; // fix this so it builds on linux
class WebAuthVerifyRoute extends StatelessWidget {
  const WebAuthVerifyRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebAuthVerify(), // Use the SettingsPage widget
    );
  }
}

class WebAuthVerify extends StatefulWidget {
  @override
  WebAuthVerifyState createState() => WebAuthVerifyState();
}

class WebAuthVerifyState extends State<WebAuthVerify> with ProtocolListener {
  String _statusText = "Loading...";

  Future<void> completeAuth(String? token) async {
    print(token);
    setState(() {
      _statusText = "Checking token, Please wait...";
    });
    final url = Uri.parse(
      "https://flow.spookysrv.com/checkToken?convoId=$token",
    );
    final response = await http.get(url);
    print("done fuck");
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      print(data["validity"]); // Use your decoded data
      if (data["validity"] == "valid") {
        setState(() {
          _statusText = "Token Valid!";
        });
        bool res =
            await sp.setString("convoToken", token!) &&
            await sp.setString("startingPage", "loggedIn");
        if (res) {
          html.window.history.replaceState(
            null,
            'Flow by Spooky Services',
            '/',
          );
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ChatPageRoute()),
          );
        }
      } else {
        Phoenix.rebirth(context);
      }
    } else {
      print('Request failed with status: ${response.statusCode}');
    }
  }

  @override
  Future<void> initState() async {
    super.initState();
    completeAuth(await sp.getString("webCallbackToken"));
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

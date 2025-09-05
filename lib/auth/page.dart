import 'dart:convert';
import 'dart:io';
import 'package:hktransports/dataStore/shared_preferences.dart';
import 'package:hktransports/pages/chat_page.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:http/http.dart' as http;
import 'package:hktransports/functions/platform.dart';
import 'package:hktransports/multiplat_ui.dart';
import 'package:flutter/material.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:url_launcher/url_launcher.dart';

Future<Uri> _authHttpListener() async {
  final server = await HttpServer.bind('localhost', 48371);
  final request = await server.first;
  final uri = request.uri;
  request.response
    ..statusCode = 200
    ..headers.set('content-type', 'text/html')
    ..write(
      '<center>Authentication successful!<br>You may close this window.<br>Please go back to the app.</center>',
    )
    ..close();
  print("new request");
  Future.delayed(const Duration(milliseconds: 250), () async {
    await server.close(force: true);
  });
  return uri;
}

class AuthPageRoute extends StatelessWidget {
  const AuthPageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthPage(), // Use the SettingsPage widget
    );
  }
}

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with ProtocolListener {
  String _statusText = pf.isWeb() ? "Please wait..." : "Please continue in your browser...";

  Future<void> completeAuth(String token) async {
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
            await sp.setString("convoToken", token) &&
            await sp.setString("startingPage", "loggedIn");
        if (res) {
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
  void initState() {
    Future<void> startAuth() async {
      print(pf.getPlatformName(context));
      String authurl =
          "https://we-could-not-determine-your-device-operating-system/";
      if (pf.isDesktop(context)) {
        authurl = "https://flow.spookysrv.com/auth?plat=desktop";
      } else if (pf.isAndroid(context)) {
        authurl = "https://flow.spookysrv.com/auth?plat=android";
      } else if (pf.isWeb()) {
        authurl = "https://flow.spookysrv.com/auth?plat=web";
      }
      final Uri url = Uri.parse(authurl);
      if (!await launchUrl(url, webOnlyWindowName: '_self')) {
        throw Exception('Could not launch $url');
      }

      if (pf.isDesktop(context)) {
        final redirectUri = await _authHttpListener();
        String token = redirectUri.queryParameters['token']!;
        completeAuth(token);
      } else if (pf.isAndroid(context)) {
        protocolHandler.addListener(this);
      }

      // completeAuth("8Bxd7bkEusrtgdnVQgkj8ElpJQuiTY4z1ERtEtbYlIL2CGL6cS");
    }


    Future.delayed(const Duration(seconds: 1), () {
      startAuth();
    });

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

  @override
  void onProtocolUrlReceived(String url) {
    String token = url.replaceFirst("spookysrvflow://convotoken/", "");
    completeAuth(token);
  }

  @override
  void dispose() {
    protocolHandler.removeListener(this);
    super.dispose();
  }
}

import 'package:dynamik_theme/dynamik_theme.dart';
import 'package:hktransports/auth/logout_page.dart';
import 'package:hktransports/dataStore/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:url_launcher/url_launcher.dart';
import '../functions/platform.dart';
import '../functions/text.dart';
import '../functions/ui.dart';
import '../functions/app.dart';
import '../multiplat_ui.dart';

class SettingsPageRoute extends StatelessWidget {
  const SettingsPageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: w.appBar(
        context: context,
        title: 'Flow Settings',
        backgroundColor: uf.cLD(
          context: context,
          color: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.onPrimary,
          ],
        ), // Add background color to the app bar
        foregroundColor: Colors.white.withValues(
          alpha: 0.9,
        ), // Add foreground color to the app bar
        backButton: true,
      ),
      body: SettingsPage(), // Use the SettingsPage widget
    );
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.5),
          child: Center(
            child: Text("Settings", style: TextStyle(fontSize: 24)),
          ),
        ),
        ListTile(
          title: Text('Theme Mode'),
          trailing: FutureBuilder(
            future: uf.getCurrentThemeMode(),
            builder: (context, asyncSnapshot) {
              return DropdownButton<ThemeMode>(
                value: asyncSnapshot.data ?? ThemeMode.system,
                items: ThemeMode.values.map((ThemeMode mode) {
                  return DropdownMenuItem<ThemeMode>(
                    value: mode,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        tf.capitalizeFirst(mode.toString().split('.').last),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (ThemeMode? newValue) {
                  if (newValue != null) {
                    DynamikTheme.of(context).setThemeMode(newValue);
                    sp.setIntSync(
                      'themeMode',
                      ThemeMode.values.indexOf(newValue),
                    );
                  }
                },
              );
            },
          ),
        ),

        ListTile(
          title: Text('Theme Template'),
          subtitle: Text("App will restart on change"),
          trailing: FutureBuilder(
            future: uf.getCurrentThemePlatform(),
            builder: (context, asyncSnapshot) {
              return DropdownButton<String>(
                value: asyncSnapshot.data,
                items: uf.themePlatforms.map((String platform) {
                  return DropdownMenuItem<String>(
                    value: platform,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(tf.capitalizeFirst(platform)),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) async {
                  if (newValue != null) {
                    bool res =
                        await uf.setCurrentThemePlatform(newValue) &&
                        await sp.setString('startingPage', 'settings');
                    if (res == true) {
                      Phoenix.rebirth(context);
                    }
                  }
                },
              );
            },
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (pf.isAppleOS(context))
              w.button(
                context: context,
                child: Text("Get iOS Shortcut"),
                onPressed: () async {
                  launchUrl(
                    Uri.parse(
                      "https://flow.spookysrv.com/ios-shortcut?device=${await sp.getString('convoToken')}",
                    ),
                  );
                },
              ),
            if (pf.isAppleOS(context)) SizedBox(width: 15),
            w.button(
              context: context,
              child: Text("Logout"),
              onPressed: () async {
                Navigator.pushReplacement(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(builder: (context) => LogoutPageRoute()),
                );
              },
            ),
          ],
        ),

        Divider(
          color: Theme.of(context).colorScheme.secondary,
          height: 50, // Increased height for more vertical spacing
        ),

        Center(child: Text("About Flow", style: TextStyle(fontSize: 24))),

        ListTile(
          title: Text('Platform'),
          subtitle: Text(pf.getPlatformName(context).replaceAll("GNOME", "")),
        ),
        ListTile(
          title: Text("App Version"),
          subtitle: af.getVersionBuilder(
            builder: (res) => Text("$res [EARLY ACCESS]"),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            w.button(
              context: context,
              child: Text("View Changelog"),
              onPressed: () {
                launchUrl(Uri.parse("https://changelog.flow.spookysrv.com"));
              },
            ),
            SizedBox(width: 15), // Add space between buttons
            w.button(
              context: context,
              child: Text("View Licenses"),
              onPressed: () async {
                showLicensePage(
                  context: context,
                  applicationName: 'Flow by Spooky Services',
                  applicationVersion:
                      "${await af.getVersion()} (${await af.getBuildNumber()})",
                  applicationIcon: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 100),
                    child: Image.asset("assets/images/logo.png"),
                  ),
                  applicationLegalese: "© Spooky Services",
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

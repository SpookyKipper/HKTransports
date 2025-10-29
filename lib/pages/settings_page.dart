import 'package:dynamik_theme/dynamik_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/dataStore/objectbox.dart';
import 'package:flutter/material.dart' hide AppBar;
import '../functions/platform.dart';
import '../functions/text.dart';
import '../functions/ui.dart';
import '../functions/app.dart';
import '../multiplat_ui.dart';
import 'package:spookyservices/widgets/widgets.dart';
import 'package:spookyservices/helpers/language.dart';


class SettingsPageRoute extends StatelessWidget {
  const SettingsPageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: 'HKTransports Settings',
        // backgroundColor: uf.cLD(
        //   context: context,
        //   color: [
        //     Theme.of(context).colorScheme.primary,
        //     Theme.of(context).colorScheme.onPrimary,
        //   ],
        // ), // Add background color to the app bar
        // foregroundColor: Colors.white.withValues(
        //   alpha: 0.9,
        // ), // Add foreground color to the app bar
        backButton: context.canPop(),
      ),
      body: SettingsPage(), // Use the SettingsPage widget
    );
  }
}

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showContent = true;
  bool trafficLayer = sp.getBool("trafficLayer") ?? false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 300), () {
      setState(() {
        _showContent = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showContent
        ? ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.5),
                child: Center(
                  child: Text("Settings", style: TextStyle(fontSize: 24)),
                ),
              ),
              ListTile(
                title: Text('Theme Mode'),
                trailing: DropdownButton<ThemeMode>(
                  value: uf.getCurrentThemeMode(),
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
                      sp.setInt(
                        'themeMode',
                        ThemeMode.values.indexOf(newValue),
                      );
                    }
                  },
                ),
              ),

              // ListTile(
              //   title: Text('Theme Template'),
              //   subtitle: Text("App will restart on change"),
              //   trailing: DropdownButton<String>(
              //     value: uf.getCurrentThemePlatform(),
              //     items: uf.themePlatforms.map((String platform) {
              //       return DropdownMenuItem<String>(
              //         value: platform,
              //         child: Padding(
              //           padding: const EdgeInsets.all(8.0),
              //           child: Text(tf.capitalizeFirst(platform)),
              //         ),
              //       );
              //     }).toList(),
              //     onChanged: (String? newValue) async {
              //       if (newValue != null) {
              //         bool res =
              //             uf.setCurrentThemePlatform(newValue) &&
              //             sp.setString('startingPage', 'settings');
              //         if (res == true) {
              //           Phoenix.rebirth(context);
              //         }
              //       }
              //     },
              //   ),
              // ),

              ListTile(
                title: Text('界面語言 (App Language)'),
                trailing: DropdownButton<String>(
                  value: LangHelper().getLang(),
                  items: ["繁體中文", "English"].map((String lang) {
                    late final String langVal;
                    if (lang == "繁體中文") {
                      langVal = "zh";
                    } else if (lang == "English") {
                      langVal = "en";
                    }
                    return DropdownMenuItem<String>(
                      value: langVal,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(lang),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) async {
                    LangHelper().setLang(newValue!);
                    setState(() {
                      // Update the UI to reflect the language change
                    });
                  },
                ),
              ),

              ListTile(
                title: Text('顯示交通狀況'),
                subtitle: Text("在地圖上顯示即時交通狀況 (需要一定 zoom level 才會顯示)"),
                trailing: Switch(
                  value: trafficLayer,
                  onChanged: (bool value) {
                    sp.setBool("trafficLayer", value);
                    setState(() {
                      trafficLayer = value;
                    });
                  },
                ),
              ),

              ListTile(
                title: Text('更新路線及車站資料'),
                trailing: Button(
                  text: "立即更新",
                  onPressed: () {
                    context.go("/updateData");
                  },
                ),
              ),

              Divider(
                color: Theme.of(context).colorScheme.secondary,
                height: 50, // Increased height for more vertical spacing
              ),

              Center(child: Text("About Flow", style: TextStyle(fontSize: 24))),

              ListTile(
                title: Text('Platform'),
                subtitle: Text(
                  pf.getPlatformName(context).replaceAll("GNOME", ""),
                ),
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
                  Button(
                    text: "View Licenses",
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
                  SizedBox(width: 15), // Add space between buttons
                  Button(
                    text: "Other Copyright Info",
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text("Other Copyright Info"),
                            content: Text(
                              "This app makes use of:\nHK Bus Crawling@2021, https://github.com/hkbus/hk-bus-crawling",
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: Text("Close"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          )
        : Center(child: w.loadingIcon(context: context));
  }
}

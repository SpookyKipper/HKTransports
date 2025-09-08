// Return UI Elements based on platform
import 'package:hktransports/customWidgets/nullWidget.dart';
import 'package:hktransports/functions/platform.dart';
import 'package:hktransports/packageMods/chat_bubbles/one.dart';
import 'package:hktransports/packageMods/chat_bubbles/three.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'functions/ui.dart';

class MultiplatWidgets {
  String themeTemplate = "system"; // Default to material
  Future<String> updateTemplate(BuildContext context) async {
    String template = await uf.getCurrentThemeTemplate(context);
    if (template == "system") {
      final platformName = pf.getPlatformName(context, noWeb: true);
      if (platformName == "iOS") {
        themeTemplate = "cupertino";
      } else {
        themeTemplate = "material"; // Default for other platforms
      }
      return themeTemplate;
    } else {
      themeTemplate = template;
      return themeTemplate;
    }
  }

  Widget button({
    required BuildContext context,
    onPressed,
    required Widget child,
  }) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return CupertinoButton(onPressed: onPressed, child: child);
    } else {
      return ElevatedButton(onPressed: onPressed, child: child);
    }
  }

  Widget buttonIcon({
    required BuildContext context,
    required onPressed,
    required IconData icon,
    required Widget label,
  }) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return CupertinoButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon), const SizedBox(width: 8), label],
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: label,
      );
    }
  }

  Widget iconButton({
    required BuildContext context,
    required onPressed,
    required IconData icon,
    String tooltip = "",
    Color color = Colors.white,
    double iconSize = 30.0,
    iOSBackgroundColor = Colors.transparent,
  }) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        color: iOSBackgroundColor,
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, color: color)],
        ),
      );
    } else {
      return IconButton(
        icon: Icon(icon), // Required: The icon to display
        onPressed: onPressed,
        tooltip: tooltip, // Optional: A tooltip for accessibility
        iconSize: iconSize, // Optional: Adjust the size of the icon
        color: color, // Optional: Set the color of the icon
      );
    }
  }

  Widget chatBubble({
    required BuildContext context,
    required String text,
    required Color color,
    bool isSender = true,
    bool tail = false,
    TextStyle textStyle = const TextStyle(color: Colors.white, fontSize: 16),
  }) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return BubbleSpecialImessage(
        text: text,
        color: color,
        isSender: isSender,
        tail: false,
        textStyle: textStyle,
      );
    } else {
      return BubbleSpecialWhatsapp(
        text: text,
        color: color,
        isSender: isSender,
        tail: false,
        textStyle: textStyle,
      );
    }
  }

  Widget textField({
    required BuildContext context,
    required String hintText,
    required borderRadius,
    TextStyle hintStyle = const TextStyle(),
    onSubmitted,
    TextEditingController? controller,
  }) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return CupertinoTextField(
        controller: controller,
        onSubmitted: onSubmitted,
        placeholder: hintText,
        placeholderStyle: TextStyle(
          color: uf.cLD(
            context: context,
            color: [CupertinoColors.black, CupertinoColors.white],
          ),
        ),
        style: TextStyle(
          color: uf.cLD(
            context: context,
            color: [CupertinoColors.black, CupertinoColors.white],
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          border: Border.all(color: CupertinoColors.systemGrey, width: 1.0),
          borderRadius: borderRadius,
        ),
      );
    } else {
      return TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: borderRadius),
          hintText: hintText,
          contentPadding: EdgeInsets.only(top: 12, left: 16, right: 16),
          // hintStyle: hintStyle
        ),
      );
    }
  }

  Widget loadingIcon({
    required BuildContext context,
    double size = 24.0,
    Color color = Colors.white,
  }) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return CupertinoActivityIndicator(
        // radius: size / 2,
        // color: color,
      );
    } else {
      return CircularProgressIndicator(
        // strokeWidth: 2.0,
        // valueColor: AlwaysStoppedAnimation<Color>(color),
      );
    }
  }

  PreferredSizeWidget appBar({
    required BuildContext context,
    String? title,
    required backgroundColor,
    required foregroundColor,
    List<Widget>? actions,
    Widget? bottom,
    bool backButton = false,
  }) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return CupertinoNavigationBar(
        middle: (title != null && title.isNotEmpty)
            ? Text(title, style: TextStyle(color: foregroundColor))
            : nullWidget(),
        backgroundColor: backgroundColor,
        trailing: (actions != null && actions.isNotEmpty) ? actions[0] : null,
        leading: (backButton)
            ? CupertinoNavigationBarBackButton(
                color: (!uf.isDarkMode(context))
                    ? foregroundColor
                    : null, // set your desired color
                onPressed: () => context.pop(),
              )
            : null,
        bottom: (bottom != null) ? bottom as PreferredSizeWidget : null,
      );
    } else {
      return AppBar(
        title: (title != null && title.isNotEmpty) ? Text(title) : nullWidget(),
        backgroundColor: backgroundColor, // Add background color to the app bar
        foregroundColor: foregroundColor,
        actions: (actions != null && actions.isNotEmpty) ? actions : null,
        leading: (backButton)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: foregroundColor),
                onPressed: () => context.pop(),
              )
            : null,
        bottom: (bottom != null) ? bottom as PreferredSizeWidget : null,
      );
    }
  }

  Widget tabBar({required BuildContext context, required List<Tab> tabs}) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return CupertinoTabBar(
        items: tabs.map((tab) {
          return BottomNavigationBarItem(
            icon: Icon(Icons.circle), // Placeholder icon
            label: tab.text,
          );
        }).toList(),
      );
    } else {
      return TabBar(tabs: tabs);
    }
  }

  Widget tabUiPage({
    required BuildContext context,
    required List<Widget> tabTitles,
    required List<Widget> children,
  }) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          items: tabTitles.map((tab) {
            return BottomNavigationBarItem(
              icon: nullWidget(), // Placeholder icon
              label: (tab is Tab) ? tab.text : 'Tab',
            );
          }).toList(),
        ),
        tabBuilder: (BuildContext context, int index) {
          return CupertinoTabView(
            builder: (BuildContext context) {
              return children[index];
            },
          );
        },
      );
    } else {
      return DefaultTabController(
        length: tabTitles.length,
        child: Column(
          children: [
            TabBar(tabs: tabTitles, isScrollable: true, tabAlignment: TabAlignment.start,),
            Expanded(child: TabBarView(children: children)),
          ],
        ),
      );
    }
  }

  FutureBuilder<String?> ensureUpdated({
    required Widget Function(String value) builder,
    required BuildContext context,
  }) {
    return FutureBuilder<String>(
      future: updateTemplate(context),
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text("Loading...");
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return builder(snapshot.data ?? "Get version failed");
        }
      },
    );
  }
}

final w = MultiplatWidgets(); // UI Elements based on platform

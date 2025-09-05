// Return UI Elements based on platform
import 'package:hktransports/functions/platform.dart';
import 'package:hktransports/packageMods/chat_bubbles/one.dart';
import 'package:hktransports/packageMods/chat_bubbles/three.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yaru/yaru.dart';
import 'functions/ui.dart';

class MultiplatWidgets {
  String themeTemplate = "material"; // Default to material
  void updateTemplate(BuildContext context) {
    uf.getCurrentThemeTemplate(context).then((template) {
      if (template == "system") {
        final platformName = pf.getPlatformName(context, noWeb: true);
        if (platformName == "iOS") {
          themeTemplate = "cupertino";
        } else if (platformName == "Linux GNOME") {
          themeTemplate = "yaru";
        } else {
          themeTemplate = "material"; // Default for other platforms
        }
      }
      themeTemplate = template;
    });
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
    } else if (themeTemplate == "yaru") {
      return YaruIconButton(
        icon: Icon(icon, color: color), // Required: The icon to display
        onPressed: onPressed,
        tooltip: tooltip, // Optional: A tooltip for accessibility
        iconSize: iconSize, // Optional: Adjust the size of the icon
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
    required String title,
    required backgroundColor,
    required foregroundColor,
    List<Widget>? actions,
    bool backButton = false,
  }) {
    updateTemplate(context);
    if (themeTemplate == "cupertino") {
      return CupertinoNavigationBar(
        middle: Text(title, style: TextStyle(color: foregroundColor)),
        backgroundColor: backgroundColor,
        trailing: (actions != null && actions.isNotEmpty) ? actions[0] : null,
        leading:
            (backButton) ?
            CupertinoNavigationBarBackButton(
              color: (!uf.isDarkMode(context)) ? foregroundColor : null, // set your desired color
              onPressed: () => context.pop(),
            ) : null,
      );
    } else {
      return AppBar(
        title: Text(title),
        backgroundColor: backgroundColor, // Add background color to the app bar
        foregroundColor: foregroundColor,
        actions: (actions != null && actions.isNotEmpty) ? actions : null,
        leading: (backButton)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: foregroundColor),
                onPressed: () => context.pop(),
              )
            : null,
      );
    }
  }
}

final w = MultiplatWidgets(); // UI Elements based on platform

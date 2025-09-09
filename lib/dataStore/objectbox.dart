import 'package:hktransports/objectBox/store.dart';
import 'package:hktransports/objectbox.g.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesFunctions {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  // Future<String?> getString1(String key) async {
  //   try {
  //     final SharedPreferences prefs = await _prefs;
  //     return prefs.getString(key);
  //   } catch (e) {
  //     print('Error reading value: $e');
  //     return null;
  //   }
  // }

  String? getString(String key) {
    return objectBox!.keyValueStringBox
        .query(BoxKeyPairString_.key.equals(key))
        .build()
        .findFirst()?.value;
  }

  // FutureBuilder<String?> getStringBuilder({
  //   required String key,
  //   required Widget Function(String? value) builder,
  // }) {
  //   return FutureBuilder<String?>(
  //     future: getString(key),
  //     builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
  //       if (snapshot.connectionState == ConnectionState.waiting) {
  //         return Text("Loading...");
  //       } else if (snapshot.hasError) {
  //         return Text('Error: ${snapshot.error}');
  //       } else {
  //         return builder(snapshot.data);
  //       }
  //     },
  //   );
  // }

  // Future<int?> getInt(String key) async {
  //   try {
  //     final SharedPreferences prefs = await _prefs;
  //     return prefs.getInt(key);
  //   } catch (e) {
  //     print('Error reading value: $e');
  //     return null;
  //   }
  // }

  int? getInt(String key) {
    return objectBox!.keyValueIntBox
        .query(BoxKeyPairInt_.key.equals(key))
        .build()
        .findFirst()?.value;
  }

  bool? getBool(String key) {
    return objectBox!.keyValueBoolBox
        .query(BoxKeyPairBool_.key.equals(key))
        .build()
        .findFirst()?.value;
  }

  // FutureBuilder<int?> getIntBuilder({
  //   required String key,
  //   required Widget Function(int? value) builder,
  // }) {
  //   return FutureBuilder<int?>(
  //     future: getInt(key),
  //     builder: (BuildContext context, AsyncSnapshot<int?> snapshot) {
  //       if (snapshot.connectionState == ConnectionState.waiting) {
  //         return Text("Loading...");
  //       } else if (snapshot.hasError) {
  //         return Text('Error: ${snapshot.error}');
  //       } else {
  //         return builder(snapshot.data);
  //       }
  //     },
  //   );
  // }

  bool setString(String key, String value) {
    final box = objectBox!.keyValueStringBox;
    box.query(BoxKeyPairString_.key.equals(key)).build().remove();
    box.put(BoxKeyPairString(key:key, value:value));
    return true;
  }

  bool setBool(String key, bool value) {
    final box = objectBox!.keyValueBoolBox;
    box.query(BoxKeyPairBool_.key.equals(key)).build().remove();
    box.put(BoxKeyPairBool(key:key, value:value));
    return true;
  }

  // void setStringSync(String key, String value) {
  //   _prefs
  //       .then((prefs) {
  //         prefs.setString(key, value);
  //       })
  //       .catchError((e) {
  //         print('Error setting value synchronously: $e');
  //       });
  // }

  bool setInt(String key, int value) {
    final box = objectBox!.keyValueIntBox;
    box.query(BoxKeyPairInt_.key.equals(key)).build().remove();
    box.put(BoxKeyPairInt(key:key, value:value));
    return true;
  }

  // void setIntSync(String key, int value) {
  //   setInt(key, value);
  // }

  Future<bool> removeValue(String key) async {
    final SharedPreferences prefs = await _prefs;
    return await prefs.remove(key);
  }

  bool removeInt(String key) {
    final box = objectBox!.keyValueIntBox;
    box.query(BoxKeyPairInt_.key.equals(key)).build().remove();
    return true;
  }

  bool removeString(String key) {
    final box = objectBox!.keyValueStringBox;
    box.query(BoxKeyPairString_.key.equals(key)).build().remove();
    return true;
  }

  // void removeValueSync(String key) {
  //   removeValue(key);
  // }
}

final sp = SharedPreferencesFunctions();

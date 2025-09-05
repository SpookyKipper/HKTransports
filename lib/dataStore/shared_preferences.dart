import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesFunctions {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<String?> getString(String key) async {
    try {
      final SharedPreferences prefs = await _prefs;
      return prefs.getString(key);
    } catch (e) {
      print('Error reading value: $e');
      return null;
    }
  }

  FutureBuilder<String?> getStringBuilder({
    required String key,
    required Widget Function(String? value) builder,
  }) {
    return FutureBuilder<String?>(
      future: getString(key),
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text("Loading...");
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return builder(snapshot.data);
        }
      },
    );
  }

  Future<int?> getInt(String key) async {
    try {
      final SharedPreferences prefs = await _prefs;
      return prefs.getInt(key);
    } catch (e) {
      print('Error reading value: $e');
      return null;
    }
  }

  FutureBuilder<int?> getIntBuilder({
    required String key,
    required Widget Function(int? value) builder,
  }) {
    return FutureBuilder<int?>(
      future: getInt(key),
      builder: (BuildContext context, AsyncSnapshot<int?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text("Loading...");
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return builder(snapshot.data);
        }
      },
    );
  }

  Future<bool> setString(String key, String value) async {
    try {
      final SharedPreferences prefs = await _prefs;
      return prefs.setString(key, value);
    } catch (e) {
      print('Error setting value: $e');
      return false;
    }
  }

  void setStringSync(String key, String value) {
    _prefs
        .then((prefs) {
          prefs.setString(key, value);
        })
        .catchError((e) {
          print('Error setting value synchronously: $e');
        });
  }

  Future<bool> setInt(String key, int value) async {
    try {
      final SharedPreferences prefs = await _prefs;
      return await prefs.setInt(key, value);
    } catch (e) {
      print('Error setting value: $e');
      return false;
    }
  }

  void setIntSync(String key, int value) {
    setInt(key, value);
  }

  Future<bool> removeValue(String key) async {
    final SharedPreferences prefs = await _prefs;
    return await prefs.remove(key);
  }

  void removeValueSync(String key) {
    removeValue(key);
  }
}

final sp = SharedPreferencesFunctions();

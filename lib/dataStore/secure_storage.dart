// import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// final storage = FlutterSecureStorage();

// class SecureStorageMethods {
//   Future<String?> getValue(key) async {
//     try {
//       String? value = await storage.read(key: key);
//       return value;
//     } catch (e) {
//       print('Error reading value: $e');
//       return null;
//     }
//   }

//   FutureBuilder<String?> getValueBuilder({
//     required String key,
//     required Widget Function(String? value) builder,
//   }) {
//     return FutureBuilder<String?>(
//       future: getValue(key),
//       builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Text("Loading...");
//         } else if (snapshot.hasError) {
//           return Text('Error: ${snapshot.error}');
//         } else {
//           return builder(snapshot.data);
//         }
//       },
//     );
//   }
// }

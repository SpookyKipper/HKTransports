import 'dart:io';

import '../objectbox.g.dart';
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';

@Entity()
class BoxKeyPairString {
  int id;
  String key;
  String value;
  BoxKeyPairString({required this.key, this.id = 0, required this.value});
}

@Entity()
class BoxKeyPairInt {
  int id;
  String key;
  int value;
  BoxKeyPairInt({required this.key, this.id = 0, required this.value});
}

@Entity()
class BoxKeyPairBool {
  int id;
  String key;
  bool value;
  BoxKeyPairBool({required this.key, this.id = 0, required this.value});
}

class ObjectBox {
  late final Store store;
  late final Box<BoxKeyPairString> keyValueStringBox;
  late final Box<BoxKeyPairInt> keyValueIntBox;
  late final Box<BoxKeyPairBool> keyValueBoolBox;

  ObjectBox._create(this.store) {
    keyValueStringBox = store.box<BoxKeyPairString>();
    keyValueIntBox = store.box<BoxKeyPairInt>();
    keyValueBoolBox = store.box<BoxKeyPairBool>();
  }

  static Future<ObjectBox> create() async {
    Directory dir = await getApplicationDocumentsDirectory();
    String path = dir.path;
    final store = await openStore(
      directory: "$path/hktransports/appdata",
    ); // uses default model from objectbox.g.dart
    return ObjectBox._create(store);
  }

  Future<void> close() async {
    store.close();
  }
}

ObjectBox? objectBox;

Future<void> initObjectBox() async {
  objectBox ??= await ObjectBox.create();
}

ObjectBox getObjectBox() {
  return objectBox!;
}

import '../objectbox.g.dart';
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

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

class ObjectBox {
  late final Store store;
  late final Box<BoxKeyPairString> keyValueStringBox;
  late final Box<BoxKeyPairInt> keyValueIntBox;

  ObjectBox._create(this.store) {
    keyValueStringBox = store.box<BoxKeyPairString>();
    keyValueIntBox = store.box<BoxKeyPairInt>();
  }

  static Future<ObjectBox> create() async {
    final store = await openStore(
      directory: "hktransports",
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

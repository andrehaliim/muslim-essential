import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';

class ObjectBox {
  final Store store;

  ObjectBox._(this.store);

  static Future<ObjectBox> open({String? directory}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbDir = directory ?? p.join(docsDir.path, "obx-example");

    final store = await openStore(directory: dbDir);
    return ObjectBox._(store);
  }
}


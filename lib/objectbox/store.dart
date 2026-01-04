import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../objectbox.g.dart';

class ObjectBox {
  late final Store store;

  static ObjectBox? _instance;

  ObjectBox._create(this.store);

  static Future<ObjectBox> create() async {
    if (_instance != null) {
      return _instance!;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(
      directory: p.join(docsDir.path, "obx-example"),
    );

    _instance = ObjectBox._create(store);
    return _instance!;
  }
}


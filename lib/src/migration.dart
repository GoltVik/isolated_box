part of 'isolated_box.dart';

class _IsolatedBoxMigration<T> {
  final MigrationStrategy policy;
  final String boxName;
  final String path;

  _IsolatedBoxMigration({
    required this.policy,
    required this.path,
    required this.boxName,
  });

  Future<Map<dynamic, T>> migrate() async {
    final migrationObjects = <dynamic, T>{};

    if (policy.shouldMigrate) {
      policy.initAdapters?.call();
      final box = await Hive.openBox<T>(boxName, path: path);

      for (var i = 0; i < box.length; i++) {
        final key = box.keyAt(i);
        final value = box.getAt(i);
        if (key != null && value != null) {
          migrationObjects[key] = value;
        }
      }

      await box.close();
    }

    await Hive.deleteBoxFromDisk(boxName, path: path);
    return migrationObjects;
  }
}

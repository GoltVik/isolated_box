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
    Hive.init(path);
    final box = await Hive.openBox<T>(boxName);
    final migrationObjects = <dynamic, T>{};

    switch (policy) {
      case MigrationStrategy.deleteAndCreate:
        await box.clear();

      case MigrationStrategy.migrate:
        for (var i = 0; i < box.length; i++) {
          final key = box.keyAt(i);
          final value = box.getAt(i);
          if (key != null && value != null) {
            migrationObjects[key] = value;
          }
        }
    }

    await box.close();
    await Hive.deleteBoxFromDisk(boxName);
    return migrationObjects;
  }
}

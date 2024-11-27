import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isolated_box/isolated_box.dart';
import 'package:path_provider/path_provider.dart';

import 'test_model_hive.dart';

void main() {
  const boxName = 'box_migrate';

  Future<String> getPath() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );

    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  TestModelHive mockModel([int? index]) {
    return TestModelHive(
      id: index?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      updatedAt: DateTime.now(),
    );
  }

  setUp(() async {
    Hive.init(await getPath());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TestModelHiveImplAdapter());
    }
    final box = await Hive.openBox<TestModelHive>(boxName);
    if (box.isEmpty) {
      final items = List.generate(3, mockModel);
      await box.addAll(items);
    }
    await box.close();
  });

  test('migration test with deleteAndCreate policy', () async {
    final isolatedBox = await IsolatedBox.init<TestModelHive>(
      boxName: boxName,
      migrationStrategy: MigrationStrategy.deleteAndCreate,
      fromJson: TestModelHive.fromJson,
      toJson: TestModelHive.toJsonString,
    );

    final objects = await isolatedBox.getAll();
    expect(objects.length, 0);

    await isolatedBox.deleteFromDisk();
  });

  test('migration test with migrate policy', () async {
    final isolatedBox = await IsolatedBox.init<TestModelHive>(
      boxName: boxName,
      migrationStrategy: MigrationStrategy.migrate,
      fromJson: TestModelHive.fromJson,
      toJson: TestModelHive.toJsonString,
    );

    final objects = await isolatedBox.getAll();
    expect(objects.length, 3);

    await isolatedBox.deleteFromDisk();
  });
}

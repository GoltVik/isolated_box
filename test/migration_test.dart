import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isolated_box/isolated_box.dart';
import 'package:path_provider/path_provider.dart';

import 'test_model.dart';

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

  TestModel mockModel([int? index]) {
    return TestModel(
      id: index?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      updatedAt: DateTime.now(),
    );
  }

  setUp(() async{
    Hive.init(await getPath());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TestModelImplAdapter());
    }
    final box = await Hive.openBox<TestModel>('box_migrate');
    if (box.isEmpty) {
      final items = List.generate(3, mockModel);
      await box.addAll(items);
    }
    await box.close();
  });


  test('migration test with deleteAndCreate policy', () async {
    final isolatedBox = await IsolatedBox.init<TestModel>(
      boxName: boxName,
      migrationPolicy: MigrationPolicy.deleteAndCreate,
      fromJson: TestModel.fromJson,
      toJson: TestModel.toJsonString,
    );

    final objects = await isolatedBox.getAll();
    expect(objects.length, 0);
    await isolatedBox.deleteFromDisk();
  });

  test('migration test with migrate policy', () async {
    final isolatedBox = await IsolatedBox.init<TestModel>(
      boxName: boxName,
      migrationPolicy: MigrationPolicy.migrate,
      fromJson: TestModel.fromJson,
      toJson: TestModel.toJsonString,
    );

    final objects = await isolatedBox.getAll();
    expect(objects.length, 3);
    await isolatedBox.deleteFromDisk();
  });
}

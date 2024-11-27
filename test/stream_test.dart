import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isolated_box/isolated_box.dart';

import 'test_model.dart';

void main() {
  const boxName = 'box_stream';

  TestModel mockModel([int? index]) {
    return TestModel(
      id: index?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      updatedAt: DateTime.now(),
    );
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
  });

  test('stream test on collection', () async {
    final isolatedBox = await IsolatedBox.init<TestModel>(
      boxName: boxName,
      migrationStrategy: MigrationStrategy.deleteAndCreate,
      fromJson: TestModel.fromJson,
      toJson: TestModel.toJsonString,
    );

    BoxEvent? boxEvent;

    final controller = isolatedBox.watch().listen((event) {
      boxEvent = event;
    });

    await isolatedBox.add(mockModel());

    await Future.delayed(const Duration(seconds: 1));

    expect(boxEvent, isNotNull);

    await controller.cancel();

    await isolatedBox.deleteFromDisk();
  });

  test('stream test on collection addAll', () async {
    final isolatedBox = await IsolatedBox.init<TestModel>(
      boxName: boxName,
      migrationStrategy: MigrationStrategy.deleteAndCreate,
      fromJson: TestModel.fromJson,
      toJson: TestModel.toJsonString,
    );

    int eventCount = 0;

    final controller = isolatedBox.watch().listen((event) {
      eventCount++;
    });

    final items = List.generate(3, mockModel);
    await isolatedBox.addAll(items);

    await Future.delayed(const Duration(seconds: 1));

    expect(eventCount, 3);

    await controller.cancel();

    await isolatedBox.deleteFromDisk();
  });

  test('stream test on key', () async {
    final isolatedBox = await IsolatedBox.init<TestModel>(
      boxName: boxName,
      migrationStrategy: MigrationStrategy.deleteAndCreate,
      fromJson: TestModel.fromJson,
      toJson: TestModel.toJsonString,
    );

    BoxEvent? boxEvent;

    final key = await isolatedBox.add(mockModel());

    final controller = isolatedBox.watch(key: key).listen((event) {
      boxEvent = event;
    });

    final model = mockModel();
    await isolatedBox.put(key, model);

    await Future.delayed(const Duration(seconds: 1));

    expect(boxEvent, isNotNull);
    expect(boxEvent!.value, model);

    await controller.cancel();

    await isolatedBox.deleteFromDisk();
  });

  test('stream test on key with deletion', () async {
    final isolatedBox = await IsolatedBox.init<TestModel>(
      boxName: boxName,
      migrationStrategy: MigrationStrategy.deleteAndCreate,
      fromJson: TestModel.fromJson,
      toJson: TestModel.toJsonString,
    );

    BoxEvent? boxEvent;

    final key = await isolatedBox.add(mockModel());

    final controller = isolatedBox.watch(key: key).listen((event) {
      boxEvent = event;
    });

    await isolatedBox.delete(key);

    await Future.delayed(const Duration(seconds: 1));

    expect(boxEvent, isNotNull);
    expect(boxEvent!.value, null);
    expect(boxEvent!.deleted, true);

    await controller.cancel();

    await isolatedBox.deleteFromDisk();
  });
}

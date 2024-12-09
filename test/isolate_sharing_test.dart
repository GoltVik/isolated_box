import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isolated_box/isolated_box.dart';

import 'test_model.dart';

void main() {
  const boxName = 'isolated_queries';
  IsolatedBox<TestModel>? isolatedBox;

  Future<void> preInit() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
  }

  setUpAll(() async => await preInit());

  tearDown(() async {
    try {
      await isolatedBox?.clear();
    } catch (_) {}
  });

  tearDownAll(() async {
    try {
      await isolatedBox?.deleteFromDisk();
    } catch (_) {}
  });

  Future<int> addFromIsolate(int count) async {
    final box = await IsolatedBox.init<TestModel>(
      boxName: boxName,
      fromJson: TestModel.fromJson,
      toJson: TestModel.toJsonString,
    );
    for (var i = 0; i < count; i++) {
      await box.add(TestModel.mock(i));
    }
    return count;
  }

  test('read after edit from another isolate', () async {
    isolatedBox = await IsolatedBox.init<TestModel>(
      boxName: boxName,
      fromJson: TestModel.fromJson,
      toJson: TestModel.toJsonString,
    );

    final count = 10;
    var materialFromBox = await isolatedBox?.getAll();
    expect(materialFromBox, isEmpty);

    await compute(addFromIsolate, count);

    materialFromBox = await isolatedBox?.getAll();
    expect(materialFromBox?.length, count);
  });
}

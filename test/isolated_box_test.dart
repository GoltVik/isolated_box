import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isolated_box/isolated_box.dart';
import 'package:path_provider/path_provider.dart';

import 'test_model.dart';

void main() {
  IsolatedBox<TestModel>? isolatedBox;

  TestModel mockModel() => TestModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        updatedAt: DateTime.now(),
      );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );

    final appDir = await getApplicationDocumentsDirectory();
    isolatedBox = await IsolatedBox.init<TestModel>(
      dirPath: appDir.path,
      boxName: 'files',
      fromJson: TestModel.fromJson,
      toJson: TestModel.toJsonString,
    );
    await isolatedBox?.clear();
  });

  tearDown(() async {
    try {
      await isolatedBox?.clear();
    } catch (_) {}
  });

  tearDownAll(() async => await isolatedBox?.dispose());

  test('name', () async {
    final name = await isolatedBox?.name;
    expect(name, 'files');
  });

  test('path', () async {
    final path = await isolatedBox?.path;
    expect(path, isNotNull);
    expect(path, './files.hive');
  });

  test('length', () async {
    var count = await isolatedBox?.length;
    expect(count, 0);

    final items = List.generate(3, (index) => mockModel());
    await isolatedBox?.addAll(items);

    count = await isolatedBox?.length;
    expect(count, items.length);

    await isolatedBox?.clear();

    count = await isolatedBox?.length;
    expect(count, 0);
  });

  test('isEmpty', () async {
    var isEmpty = await isolatedBox?.isEmpty;
    expect(isEmpty, true);

    await isolatedBox?.add(mockModel());

    isEmpty = await isolatedBox?.isEmpty;
    expect(isEmpty, false);
  });

  test('isNotEmpty', () async {
    var isEmpty = await isolatedBox?.isNotEmpty;
    expect(isEmpty, false);

    await isolatedBox?.add(mockModel());

    isEmpty = await isolatedBox?.isNotEmpty;
    expect(isEmpty, true);
  });

  test('keyAt', () async {
    final key = await isolatedBox?.keyAt(0);
    expect(key, isNull);

    final items = List.generate(3, (index) => mockModel());
    final ids = items.map((e) => e.id);
    await isolatedBox?.putAll({for (var e in items) e.id: e});

    final keyAt0 = await isolatedBox?.keyAt(0);
    expect(keyAt0, isNotNull);
    expect(keyAt0, ids.first);

    final keyAt1 = await isolatedBox?.keyAt(1);
    expect(keyAt1, isNotNull);
    expect(keyAt1, ids.elementAt(1));

    final keyAt2 = await isolatedBox?.keyAt(2);
    expect(keyAt2, isNotNull);
    expect(keyAt2, ids.last);
  });

  test('keyAt when index not found in db', () async {
    final result = await isolatedBox?.keyAt(0);
    expect(result, isNull);
  });

  test('keyAt when index is generated', () async {
    final item = mockModel();
    await isolatedBox?.add(item);

    final result = await isolatedBox?.keyAt(0);
    expect(result, isNotNull);
    expect(result, 0);
  });

  test('keyAt when index is defined', () async {
    final item = mockModel();
    await isolatedBox?.put(item.id, item);

    final result = await isolatedBox?.keyAt(0);
    expect(result, isNotNull);
    expect(result, item.id);
  });

  test('keys', () async {
    var keys = await isolatedBox?.keys;
    expect(keys?.length, 0);

    final items = List.generate(3, (index) => mockModel());
    final ids = items.map((e) => e.id);
    await isolatedBox?.putAll({for (var e in items) e.id: e});

    keys = await isolatedBox?.keys;
    expect(keys?.length, 3);
    expect(keys, ids);
  });

  test('getAll', () async {
    final materialFromBox = await isolatedBox?.getAll();

    expect(materialFromBox, isA<List<TestModel>>());
    expect(materialFromBox, isEmpty);
  });

  test('add', () async {
    final id = await isolatedBox?.add(mockModel());

    expect(id, isA<int>());

    final materialFromBox = await isolatedBox?.getAll();

    expect(materialFromBox, isA<List<TestModel>>());
    expect(materialFromBox, isNotEmpty);
    expect(materialFromBox?.length, 1);
  });

  test('addAll', () async {
    final items = List.generate(3, (index) => mockModel());
    final ids = await isolatedBox?.addAll(items);

    expect(ids, isA<List<int>>());

    final materialFromBox = await isolatedBox?.getAll();

    expect(materialFromBox, isA<List<TestModel>>());
    expect(materialFromBox, isNotEmpty);
    expect(materialFromBox?.length, 3);
  });

  test('put', () async {
    final material = mockModel();
    await isolatedBox?.put(material.id, material);
    final materialFromBox = await isolatedBox?.getAll();

    expect(materialFromBox, isA<List<TestModel>>());
    expect(materialFromBox, isNotEmpty);
    expect(materialFromBox?.length, 1);

    expect(materialFromBox?[0].id, material.id);
  });

  test('putAt when is empty ', () async {
    try {
      final material = mockModel();
      await isolatedBox?.putAt(0, material);
    } catch (e) {
      expect(e, isA<Exception>());
    }
  });

  test('putAt when is not empty ', () async {
    final material = mockModel();
    final index = await isolatedBox?.add(material);

    var materialFromBox = await isolatedBox?.getAt(index!);
    expect(materialFromBox, isNotNull);
    expect(materialFromBox?.id, material.id);

    await isolatedBox?.putAt(0, material.copyWith(id: '1'));

    materialFromBox = await isolatedBox?.getAt(0);
    expect(materialFromBox, isNotNull);
    expect(materialFromBox?.id, '1');
  });

  test('putAll', () async {
    final items = List.generate(3, (index) => mockModel());
    await isolatedBox?.putAll({for (var e in items) e.id: e});

    final materialFromBox = await isolatedBox?.getAll();

    expect(materialFromBox, isA<List<TestModel>>());
    expect(materialFromBox, isNotEmpty);
    expect(materialFromBox?.length, 3);

    expect(materialFromBox?[0].id, items[0].id);
    expect(materialFromBox?[1].id, items[1].id);
    expect(materialFromBox?[2].id, items[2].id);
  });

  test('get null when key is not found', () async {
    final key = '1';
    final result = await isolatedBox?.get(key);
    expect(result, isNull);
  });

  test('get defaultValue when key is not found', () async {
    final defaultValue = mockModel();
    final result = await isolatedBox?.get(
      defaultValue.id,
      defaultValue: defaultValue,
    );

    expect(result, isNotNull);
    expect(result, defaultValue);
  });

  test('get', () async {
    final defaultValue = mockModel();

    await isolatedBox?.put(defaultValue.id, defaultValue);

    final result = await isolatedBox?.get(defaultValue.id);

    expect(result, isA<TestModel>());
    expect(result, isNotNull);
    expect(result, defaultValue);
  });

  test('getAll when empty', () async {
    final result = await isolatedBox?.getAll();

    expect(result, isA<List<TestModel>>());
    expect(result, isEmpty);
  });

  test('getAll when prefilled', () async {
    final items = List.generate(3, (index) => mockModel());
    await isolatedBox?.addAll(items);

    final result = await isolatedBox?.getAll();

    expect(result, isA<List<TestModel>>());
    expect(result, isNotNull);
    expect(result!.length, 3);
  });

  test('when key is not exist', () async {
    final result = await isolatedBox?.containsKey('1');

    expect(result, isA<bool>());
    expect(result, false);
  });

  test('when key exists in db', () async {
    final item = mockModel();
    await isolatedBox?.put(item.id, item);

    final result = await isolatedBox?.containsKey(item.id);

    expect(result, isA<bool>());
    expect(result, true);
  });

  test('delete when key is not exist', () async {
    var exists = await isolatedBox?.containsKey('1');
    expect(exists, false);

    await isolatedBox?.delete('1');

    exists = await isolatedBox?.containsKey('1');
    expect(exists, false);
  });

  test('delete when key exists in db', () async {
    final item = mockModel();
    await isolatedBox?.put(item.id, item);

    var exists = await isolatedBox?.containsKey(item.id);
    expect(exists, true);

    await isolatedBox?.delete(item.id);

    exists = await isolatedBox?.containsKey(item.id);
    expect(exists, false);
  });

  test('deleteAt when key is not exist', () async {
    try {
      await isolatedBox?.deleteAt(0);
    } catch (e) {
      expect(e, isA<Exception>());
    }
  });

  test('deleteAt when key exist in db', () async {
    final item = mockModel();
    final index = await isolatedBox?.add(item);
    final key = await isolatedBox?.keyAt(index!);

    var exists = await isolatedBox?.containsKey(key!);
    expect(exists, true);

    await isolatedBox?.deleteAt(index!);

    exists = await isolatedBox?.containsKey(key!);
    expect(exists, false);
  });

  test('deleteAll when keys are not existing in db', () async {
    var items = await isolatedBox?.getAll();
    expect(items, isEmpty);

    await isolatedBox?.deleteAll(['1', '2', '3']);

    items = await isolatedBox?.getAll();
    expect(items, isEmpty);
  });

  test('deleteAll when keys are existing in db', () async {
    final data = List.generate(3, (index) => mockModel());
    final ids = data.map((e) => e.id);
    await isolatedBox?.putAll({for (final e in data) e.id: e});

    var items = await isolatedBox?.getAll();
    expect(items, isNotEmpty);
    expect(items?.length, 3);
    expect(items?.map((e) => e.id), ids);

    await isolatedBox?.deleteAll(ids);

    items = await isolatedBox?.getAll();
    expect(items, isEmpty);
  });

  test('clear when is empty', () async {
    var items = await isolatedBox?.getAll();
    expect(items, isEmpty);

    await isolatedBox?.clear();

    items = await isolatedBox?.getAll();
    expect(items, isEmpty);
  });

  test('clear when is not empty', () async {
    final data = List.generate(3, (index) => mockModel());
    final newIds = await isolatedBox?.addAll(data);
    expect(newIds?.length, data.length);

    await isolatedBox?.clear();

    final items = await isolatedBox?.getAll();
    expect(items, isEmpty);
  });

  test('isOpen', () async {
    var isOpen = await isolatedBox?.isOpen;
    expect(isOpen, true);

    await isolatedBox?.dispose();

    isOpen = await isolatedBox?.isOpen;
    expect(isOpen, false);
  });

  test('dispose', () async {
    await isolatedBox?.dispose();
    try {
      await isolatedBox?.getAll();
    } catch (e) {
      expect(e, isA<AssertionError>());
    }
  });

  // // 10   100   1000   10000   100000
  // // 3,5  5,10  13,52  30,199  197,1150
  // test('benchmark', () async {
  // Future<void> measureExecutionTime(Future? functionToExecute) async {
  //   final startTime = DateTime.now(); // Record start time
  //   await functionToExecute; // Execute the function
  //   final endTime = DateTime.now(); // Record end time
  //
  //   final executionTime = endTime.difference(startTime);
  //   print('Execution time: ${executionTime.inMilliseconds} ms');
  // }
  //
  //   const count = 10;
  //   final items = List.generate(count, (index) => mockMaterial());
  //
  //   await measureExecutionTime(isolatedBox?.addAll(items));
  //
  //   await measureExecutionTime(isolatedBox?.getAll());
  //   final materialFromBox = await isolatedBox?.getAll();
  //
  //   expect(materialFromBox, isA<List<BaseModel>>());
  //   expect(materialFromBox, isNotEmpty);
  //   expect(materialFromBox?.length, count);
  //
  //   expect(materialFromBox?[0].id, items[0].id);
  //   expect(materialFromBox?[1].id, items[1].id);
  //   expect(materialFromBox?[2].id, items[2].id);
  // });
}

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isolated_box/isolated_box.dart';
import 'package:path_provider/path_provider.dart';

import 'test_model_hive.dart';

void main() {
  const boxName = 'models';
  TestModelHive mockModel([int? index]) => TestModelHive(
        id: index?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        updatedAt: DateTime.now(),
      );

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

  final testCounts = [10, 100, 1000, 10000, 100000, 1000000];

  group('IsolatedBox', () {
    for (final count in testCounts) {
      test('benchmark for $count', () async {
        final isolatedBox = await IsolatedBox.init<TestModelHive>(
          boxName: boxName,
          fromJson: TestModelHive.fromJson,
          toJson: TestModelHive.toJsonString,
        );

        final items = List.generate(count, (index) => mockModel(index));

        await isolatedBox.addAll(items).measure('addAll');
        final materialFromBox = await isolatedBox.getAll().measure('getAll');

        expect(materialFromBox, isA<List<TestModelHive>>());
        expect(materialFromBox, isNotEmpty);
        expect(materialFromBox.length, count);

        expect(materialFromBox[0].id, items[0].id);
        expect(materialFromBox[1].id, items[1].id);
        expect(materialFromBox[2].id, items[2].id);

        await isolatedBox.clear();
        await isolatedBox.dispose();
        debugPrint('------------------------------------');
      });
    }
  });

  group('Hive', () {
    for (final count in testCounts) {
      test('benchmark for $count', () async {
        final path = (await getApplicationDocumentsDirectory()).path;
        Hive.init(path);
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(TestModelHiveImplAdapter());
        }

        final box = (await Hive.openBox<TestModelHive>(boxName));
        final items = List.generate(count, (index) => mockModel(index));

        await box.addAll(items).measure('addAll');
        final materialFromBox =
            await Future.value(box.values.toList()).measure('getAll');

        expect(materialFromBox, isA<List<TestModelHive>>());
        expect(materialFromBox, isNotEmpty);
        expect(materialFromBox.length, count);

        expect(materialFromBox[0].id, items[0].id);
        expect(materialFromBox[1].id, items[1].id);
        expect(materialFromBox[2].id, items[2].id);

        await box.deleteFromDisk();
        debugPrint('------------------------------------');
      });
    }
  });
}

extension FutureExt<T> on Future<T> {
  Future<T> measure(String label) async {
    final stopwatch = Stopwatch()..start();
    final T result = await this;
    stopwatch.stop();
    debugPrint('Execution time of $label: ${stopwatch.elapsedMilliseconds}ms');
    stopwatch.reset();
    return result;
  }
}

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart' as hive;
import 'package:isolated_box/isolated_box.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  const boxName = 'numbers';

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

  group('Hive', () {
    for (final count in testCounts) {
      test('benchmark for $count', () async {
        final path = (await getApplicationDocumentsDirectory()).path;
        hive.Hive.init(path);

        final box = (await hive.Hive.openBox<int>(boxName));
        final items = List.generate(count, (index) => index);

        await box.addAll(items).measure('addAll');
        final materialFromBox =
            await Future.value(box.values.toList()).measure('getAll');

        expect(materialFromBox, isNotEmpty);
        expect(materialFromBox.length, count);

        await box.deleteFromDisk();
        debugPrint('------------------------------------');
      });
    }
  });

  group('IsolatedBox', () {
    for (final count in testCounts) {
      test('benchmark for $count', () async {
        final isolatedBox = await IsolatedBox.init<int>(boxName: boxName);

        final items = List.generate(count, (index) => index);

        await isolatedBox.addAll(items).measure('addAll');
        final materialFromBox = await isolatedBox.getAll().measure('getAll');

        expect(materialFromBox, isNotEmpty);
        expect(materialFromBox.length, count);

        await isolatedBox.clear();
        await isolatedBox.dispose();
        debugPrint('------------------------------------');
      });
    }
  });

  group('IsolatedHiveBox', () {
    for (final count in testCounts) {
      test('benchmark for $count', () async {
        final path = (await getApplicationDocumentsDirectory()).path;
        await hive.IsolatedHive.init(path,
            isolateNameServer: StubIsolateNameServer());

        final box = (await hive.IsolatedHive.openBox<int>(boxName));
        final items = List.generate(count, (index) => index);

        await box.addAll(items).measure('addAll');
        final materialFromBox = await box.values.measure('getAll');

        expect(materialFromBox, isNotEmpty);
        expect(materialFromBox.length, count);

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

class StubIsolateNameServer implements hive.IsolateNameServer {
  final Map<String, dynamic> _ports = {};

  @override
  lookupPortByName(String name) {
    return _ports[name];
  }

  @override
  bool registerPortWithName(port, String name) {
    if (_ports.containsKey(name)) {
      return false; // Port with this name already exists
    }
    _ports[name] = port;
    return true;
  }

  @override
  bool removePortNameMapping(String name) {
    if (!_ports.containsKey(name)) {
      return false; // No port with this name exists
    }
    _ports.remove(name);
    return true;
  }
}

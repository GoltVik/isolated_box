import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isolated_box/isolated_box.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
  });

  test('int', () async {
    final isolatedBox = await IsolatedBox.init<int>(boxName: 'box');
    await isolatedBox.clear();

    final name = await isolatedBox.name;
    expect(name, 'box');

    await isolatedBox.add(1);
    final items = await isolatedBox.getAll();
    expect(items, [1]);

    await isolatedBox.dispose();
  });

  test('double', () async {
    final isolatedBox = await IsolatedBox.init<double>(boxName: 'box');
    await isolatedBox.clear();

    final name = await isolatedBox.name;
    expect(name, 'box');

    await isolatedBox.add(1.0);
    final items = await isolatedBox.getAll();
    expect(items, [1.0]);

    await isolatedBox.dispose();
  });

  test('string', () async {
    final isolatedBox = await IsolatedBox.init<String>(boxName: 'box');
    await isolatedBox.clear();

    final name = await isolatedBox.name;
    expect(name, 'box');

    await isolatedBox.add('1');
    final items = await isolatedBox.getAll();
    expect(items, ['1']);

    await isolatedBox.dispose();
  });
}

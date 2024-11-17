import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'migration.dart';

part 'isolated_box_worker.dart';

class IsolatedBoxException implements Exception {
  IsolatedBoxException(this.message);

  final String message;

  @override
  String toString() => 'HiveIsolatedBoxException: $message';
}

typedef FromJson<T> = T Function(Map<String, Object?>);
typedef ToJson<T> = Map<String, Object?> Function(T);

class IsolatedBox<T> {
  IsolatedBox._(
    this.boxName, {
    required this.fromJson,
    required this.toJson,
    required this.migrationPolicy,
  });

  static Future<IsolatedBox<T>> init<T>({
    required String boxName,
    FromJson<T>? fromJson,
    ToJson<T>? toJson,
    String? dirPath,
    MigrationPolicy? migrationPolicy,
  }) async {
    final box = IsolatedBox<T>._(
      boxName,
      fromJson: fromJson,
      toJson: toJson,
      migrationPolicy: migrationPolicy ?? MigrationPolicy.deleteAndCreate,
    );
    return box._init(dirPath: dirPath);
  }

  final String boxName;
  final FromJson<T>? fromJson;
  final ToJson<T>? toJson;
  Isolate? _isolate;
  SendPort? _sendPort;
  MigrationPolicy migrationPolicy;

  Future<IsolatedBox<T>> _init({
    required String? dirPath,
    Map<dynamic, T> items = const {},
  }) async {
    final sendPort = IsolateNameServer.lookupPortByName(boxName);
    if (await _isIsolateResponsive(sendPort)) {
      _sendPort = sendPort;
      return this;
    }

    dirPath ??= (await getApplicationDocumentsDirectory()).path;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _collectionIsolate<T>,
      [receivePort.sendPort, boxName, dirPath],
      debugName: boxName,
    );

    final response = await receivePort.first;

    if (response is String) {
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;

      if (response.startsWith('e: HiveError:')) {
        final items = await IsolatedBoxMigration<T>(
          policy: migrationPolicy,
          path: dirPath,
          boxName: boxName,
        ).migrate();
        return _init(dirPath: dirPath, items: items);
      } else {
        throw response.substring(3);
      }
    }

    _sendPort = response as SendPort;
    receivePort.close();

    if (items.isNotEmpty) await putAll(items);
    IsolateNameServer.registerPortWithName(_sendPort!, boxName);
    return this;
  }

  Future<bool> _isIsolateResponsive(SendPort? sendPort) async {
    if (sendPort == null) return false;

    try {
      final response = ReceivePort();
      sendPort.send(_ActionModel(_Functions.ping, null, response.sendPort));
      await response.first.timeout(const Duration(milliseconds: 300));
      response.close();
      return true;
    } catch (_) {
      IsolateNameServer.removePortNameMapping(boxName);
      return false;
    }
  }

  Future<E> _makeIsolateCall<E>(String action, [dynamic input]) async {
    Uint8List objectToBytes(T object) {
      final mapObject = toJson?.call(object) ?? object;
      final jsonString = jsonEncode(mapObject);
      return Uint8List.fromList(utf8.encode(jsonString));
    }

    T objectFromBytes(Uint8List bytes) {
      final jsonString = utf8.decode(bytes);
      final mapObject = jsonDecode(jsonString);
      return fromJson?.call(mapObject) ?? mapObject as T;
    }

    final formatedInput = () {
      if (input is MapEntry<int, T>) {
        return MapEntry(input.key, objectToBytes(input.value));
      }
      if (input is MapEntry<String, T>) {
        return MapEntry(input.key, objectToBytes(input.value));
      }
      if (input is MapEntry<dynamic, T>) {
        return MapEntry(input.key, objectToBytes(input.value));
      }
      if (input is Iterable<T> || input is List<T>) {
        return input.map(objectToBytes).toList();
      }
      if (input is Map<dynamic, T>) {
        return input.map((key, value) => MapEntry(key, objectToBytes(value)));
      }
      if (input is T && action == _Functions.add) {
        return objectToBytes(input);
      }
      return input;
    }();

    final response = ReceivePort();
    _sendPort!.send(_ActionModel(action, formatedInput, response.sendPort));

    final result = await response.first;
    response.close();

    if (result.toString().startsWith('e:')) {
      throw Exception(result.toString().substring(3));
    }

    final parsedResult = () {
      if (result is List<Uint8List>) {
        return result.map(objectFromBytes).toList();
      }
      if (result is Uint8List) return objectFromBytes(result);
      return result;
    }();

    return parsedResult as E;
  }

  //region Box methods
  Future<String> get name async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<String>(_Functions.name);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<bool> get isOpen async {
    if (_sendPort == null) return false;

    try {
      final result = await _makeIsolateCall<bool>(_Functions.isOpen);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<String?> get path async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<String?>(_Functions.path);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<int> get length async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<int>(_Functions.length);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<bool> get isEmpty async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await length;
      return result == 0;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<bool> get isNotEmpty async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    return !(await isEmpty);
  }

  Future<List<dynamic>> get keys async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<List<dynamic>>(_Functions.keys);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<dynamic> keyAt(int index) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final key = await _makeIsolateCall<dynamic>(_Functions.keyAt, index);
      return key;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<bool> containsKey(dynamic key) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<bool>(_Functions.containsKey, key);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> put(dynamic key, T value) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.put, MapEntry(key, value));
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> putAt(int index, T value) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.putAt, MapEntry(index, value));
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> putAll(Map<dynamic, T> entries) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.putAll, entries);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<int> add(T value) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final index = await _makeIsolateCall<int>(_Functions.add, value);
      return index;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<List<dynamic>> addAll(Iterable<T> values) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final keys = await _makeIsolateCall<List<dynamic>>(
        _Functions.addAll,
        values,
      );
      return keys;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> delete(dynamic key) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.delete, key);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> deleteAt(int index) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.deleteAt, index);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> deleteAll(Iterable<dynamic> keys) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.deleteAll, keys.cast<dynamic>());
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<T?> get(dynamic key, {T? defaultValue}) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final value = await _makeIsolateCall<T?>(_Functions.get, key);
      return value ?? defaultValue;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<T?> getAt(int index, {T? defaultValue}) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final value = await _makeIsolateCall<T?>(_Functions.getAt, index);
      return value ?? defaultValue;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<List<T>> getAll() async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final values = await _makeIsolateCall<List<T>>(_Functions.getAll);
      return values;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> clear() async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.clear);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> flush() async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.flush);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Stream<BoxEvent> watch({dynamic key}) {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    final receivePort = ReceivePort();
    _sendPort!.send(_ActionModel(_Functions.watch, key, receivePort.sendPort));

    return receivePort.cast<BoxEvent>().map((event) {
      if (event.value is Uint8List) {
        final jsonString = utf8.decode(event.value as Uint8List);
        final mapObject = jsonDecode(jsonString);
        final value = fromJson?.call(mapObject) ?? mapObject as T;
        return BoxEvent(event.key, value, event.deleted);
      }
      return event;
    }).asBroadcastStream(
      onCancel: (subscription) {
        _sendPort!.send(
          _ActionModel(_Functions.unwatch, key, receivePort.sendPort),
        );
        subscription.cancel();
        receivePort.close();
      },
    );
  }

  Future<void> deleteFromDisk() async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.deleteFromDisk);
      _sendPort = null;
      await dispose();
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> dispose() async {
    if (_sendPort != null) {
      await _makeIsolateCall<void>(_Functions.dispose);
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    IsolateNameServer.removePortNameMapping(boxName);
  }
//endregion
}

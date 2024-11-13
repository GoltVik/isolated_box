import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:hive/hive.dart';

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
  });

  static Future<IsolatedBox<T>> init<T>({
    required String dirPath,
    required String boxName,
    required FromJson<T> fromJson,
    required ToJson<T> toJson,
  }) async {
    final box = IsolatedBox<T>._(
      boxName,
      fromJson: fromJson,
      toJson: toJson,
    );
    return box._init(dirPath: dirPath);
  }

  final String boxName;
  final FromJson<T> fromJson;
  final ToJson<T> toJson;
  Isolate? _isolate;
  SendPort? _sendPort;

  Future<IsolatedBox<T>> _init({required String dirPath}) async {
    final sendPort = IsolateNameServer.lookupPortByName(boxName);
    if (await _isIsolateResponsive(sendPort)) {
      _sendPort = sendPort;
      return this;
    }

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _collectionIsolate<T>,
      [receivePort.sendPort, boxName, dirPath],
    );

    final response = await receivePort.first;

    if (response is String) {
      throw Exception('Error initializing HiveIsolatedBox: $response');
    }

    _sendPort = response as SendPort;

    await _preOpen();
    IsolateNameServer.registerPortWithName(_sendPort!, boxName);
    return this;
  }

  Future<bool> _isIsolateResponsive(SendPort? sendPort) async {
    if (sendPort == null) return false;
    final response = ReceivePort();
    sendPort.send([
      {'action': 'ping'},
      response.sendPort,
    ]);
    try {
      await response.first.timeout(const Duration(milliseconds: 300));
      return true;
    } catch (_) {
      IsolateNameServer.removePortNameMapping(boxName);
      return false;
    }
  }

  Future<E> _makeIsolateCall<E>(String action, [dynamic input]) async {
    final response = ReceivePort();

    Uint8List objectToBytes(T object) {
      final mapObject = toJson(object);
      final jsonString = jsonEncode(mapObject);
      return Uint8List.fromList(utf8.encode(jsonString));
    }

    T objectFromBytes(Uint8List bytes) {
      final jsonString = utf8.decode(bytes);
      final mapObject = jsonDecode(jsonString) as Map<String, Object?>;
      return fromJson(mapObject);
    }

    final formatedInput = () {
      if (input == null) return null;
      if (input is Map<int, T>) {
        return input.map((key, value) => MapEntry(key, objectToBytes(value)));
      }
      if (input is Map<String, Map<String, T>>) {
        return input.map(
          (key, value) => MapEntry(
            key,
            value.map((key, value) => MapEntry(key, objectToBytes(value))),
          ),
        );
      }
      if (input is Map<String, Iterable<T>>) {
        return input.map(
          (key, value) => MapEntry(key, value.map(objectToBytes).toList()),
        );
      }
      if (input is Map<String, Object?>) {
        return input.map((key, value) {
          return MapEntry(key, value is T ? objectToBytes(value) : value);
        });
      }
      return input as Map<String, Object?>;
    }();

    _sendPort!.send([
      {'action': action, if (formatedInput != null) ...formatedInput},
      response.sendPort,
    ]);

    final result = await response.first;

    if (result.toString().startsWith('e:')) {
      throw Exception(result.toString().substring(3));
    }
    response.close();

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
  Future<void> _preOpen() {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');
    return _makeIsolateCall(_Functions.preOpen);
  }

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
      final key = await _makeIsolateCall<dynamic>(_Functions.keyAt, {
        'index': index,
      });
      return key;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<bool> containsKey(dynamic key) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<bool>(_Functions.containsKey, {
        'key': key,
      });
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> put(String key, T value) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.put, {
        'key': key,
        'value': value,
      });
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> putAt(int index, T value) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.putAt, {
        'index': index,
        'value': value,
      });
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> putAll(Map<String, T> entries) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.putAll, {
        'entries': entries,
      });
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<int> add(T value) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final index = await _makeIsolateCall<int>(_Functions.add, {
        'value': value,
      });
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
        {'values': values},
      );
      return keys;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> delete(dynamic key) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.delete, {'key': key});
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> deleteAt(int index) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.deleteAt, {'index': index});
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> deleteAll(Iterable<dynamic> keys) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.deleteAll, {'keys': keys});
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<T?> get(String key, {T? defaultValue}) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final value = await _makeIsolateCall<T?>(_Functions.get, {'key': key});
      return value ?? defaultValue;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<T?> getAt(int index, {T? defaultValue}) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final value =
          await _makeIsolateCall<T?>(_Functions.getAt, {'index': index});
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

  Future<void> deleteFromDisk() async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.deleteFromDisk);
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

  Future<void> dispose() async {
    if (_sendPort != null) {
      await flush();
      await _makeIsolateCall<void>(_Functions.dispose);
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    IsolateNameServer.removePortNameMapping(boxName);
  }
//endregion
}
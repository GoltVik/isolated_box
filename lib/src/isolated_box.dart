import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

// import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'migration_strategy.dart';

part 'isolated_box_worker.dart';

part 'migration.dart';

/// Exception thrown when an error occurs in the [IsolatedBox] class.
class IsolatedBoxException implements Exception {
  /// Creates an [IsolatedBoxException] with the given [message].
  IsolatedBoxException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'HiveIsolatedBoxException: $message';
}

/// Parser function to convert a JSON map to a Dart object.
typedef FromJson<T> = T Function(Map<String, Object?>);

/// Parser function to convert a Dart object to a JSON map.
typedef ToJson<T> = Map<String, Object?> Function(T);

/// A Hive box that runs in an isolate.
class IsolatedBox<T> {
  IsolatedBox._(
    this._boxName, {
    required FromJson<T>? fromJson,
    required ToJson<T>? toJson,
    required MigrationStrategy migrationPolicy,
  })  : _migrationPolicy = migrationPolicy,
        _fromJson = fromJson,
        _toJson = toJson;

  /// Initializes an [IsolatedBox] with the given parameters.
  ///
  /// [boxName] is the name of the box.
  ///
  /// [fromJson] is a function that converts a JSON map to a Dart object.
  ///
  /// [toJson] is a function that converts a Dart object to a JSON map.
  ///
  /// [dirPath] is the path where the box will be stored.
  ///
  /// [migrationStrategy] is the strategy to use when migrating data from a non-isolated box.
  static Future<IsolatedBox<T>> init<T>({
    required String boxName,
    FromJson<T>? fromJson,
    ToJson<T>? toJson,
    String? dirPath,
    MigrationStrategy? migrationStrategy,
  }) async {
    final box = IsolatedBox<T>._(
      boxName,
      fromJson: fromJson,
      toJson: toJson,
      migrationPolicy: migrationStrategy ?? MigrationStrategy.deleteAndCreate,
    );
    return box._init(dirPath: dirPath);
  }

  final String _boxName;
  final FromJson<T>? _fromJson;
  final ToJson<T>? _toJson;
  final MigrationStrategy _migrationPolicy;
  Isolate? _isolate;
  SendPort? _sendPort;

  Future<IsolatedBox<T>> _init({
    required String? dirPath,
    Map<dynamic, T> items = const {},
  }) async {
    final sendPort = IsolateNameServer.lookupPortByName(_boxName);
    if (await _isIsolateResponsive(sendPort)) {
      _sendPort = sendPort;
      return this;
    }

    dirPath ??= (await getApplicationDocumentsDirectory()).path;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _collectionIsolate<T>,
      [receivePort.sendPort, _boxName, dirPath],
      debugName: _boxName,
    );

    final response = await receivePort.first;

    if (response is String) {
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;

      if (response.startsWith('e: HiveError:')) {
        final items = await _IsolatedBoxMigration<T>(
          policy: _migrationPolicy,
          path: dirPath,
          boxName: _boxName,
        ).migrate();
        return _init(dirPath: dirPath, items: items);
      } else {
        throw response.substring(3);
      }
    }

    _sendPort = response as SendPort;
    receivePort.close();

    if (items.isNotEmpty) await _migrateAll(items);
    IsolateNameServer.registerPortWithName(_sendPort!, _boxName);
    return this;
  }

  Future<bool> _isIsolateResponsive(SendPort? sendPort) async {
    if (sendPort == null) return false;

    try {
      final response = ReceivePort();
      sendPort.send(
        _ActionModel(_Functions.ping, null, response.sendPort).toJson(),
      );
      await response.first.timeout(const Duration(seconds: 1));
      response.close();
      return true;
    } catch (e) {
      IsolateNameServer.removePortNameMapping(_boxName);
      return false;
    }
  }

  List<int> _objectToBytes(T object) {
    final mapObject = _toJson?.call(object) ?? object;
    final jsonString = jsonEncode(mapObject);
    return utf8.encode(jsonString);
  }

  T _objectFromBytes(List<int> bytes) {
    final jsonString = utf8.decode(bytes);
    final mapObject = jsonDecode(jsonString);
    return _fromJson?.call(mapObject) ?? mapObject as T;
  }

  Future<E> _makeIsolateCall<E>(String action, [dynamic input]) async {
    dynamic formatInput({dynamic input, required String action}) {
      if (input is MapEntry<int, T>) {
        return {input.key, _objectToBytes(input.value)};
      }
      if (input is MapEntry<String, T>) {
        return {input.key, _objectToBytes(input.value)};
      }
      if (input is MapEntry<dynamic, T>) {
        return {input.key, _objectToBytes(input.value)};
      }
      if (input is Iterable<T> || input is List<T>) {
        return input.map(_objectToBytes).toList();
      }
      if (input is Map<dynamic, T>) {
        return input.map((key, value) => MapEntry(key, _objectToBytes(value)));
      }
      if (input is T && action == _Functions.add) {
        return _objectToBytes(input);
      }
      return input;
    }

    E formatOutput(dynamic output) {
      if (output is List<List<int>>) {
        return output.map(_objectFromBytes).toList() as E;
      }

      if (output is List<int> && action != _Functions.addAll) {
        return _objectFromBytes(output) as E;
      }

      return output;
    }

    final formatedInput = formatInput(input: input, action: action);

    final response = ReceivePort();
    _sendPort!.send(
      _ActionModel(action, formatedInput, response.sendPort).toJson(),
    );

    final result = await response.first;
    response.close();

    if (result.toString().startsWith('e:')) {
      throw Exception(result.toString().substring(3));
    }

    return formatOutput(result);
  }

  //region Box methods
  /// The name of the box.
  Future<String> get name async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<String>(_Functions.name);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Whether this box is currently open.
  Future<bool> get isOpen async {
    if (_sendPort == null) return false;

    try {
      final result = await _makeIsolateCall<bool>(_Functions.isOpen);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// The location of the box in the file system.
  Future<String?> get path async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<String?>(_Functions.path);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// The number of entries in the box.
  Future<int> get length async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<int>(_Functions.length);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Returns `true` if there are no entries in this box.
  Future<bool> get isEmpty async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await length;
      return result == 0;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Returns true if there is at least one entries in this box.
  Future<bool> get isNotEmpty async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    return !(await isEmpty);
  }

  /// All the keys in the box.
  Future<List<dynamic>> get keys async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<List<dynamic>>(_Functions.keys);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Get the n-th key in the box.
  Future<dynamic> keyAt(int index) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final key = await _makeIsolateCall<dynamic>(_Functions.keyAt, index);
      return key;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Checks whether the box contains the [key].
  Future<bool> containsKey(dynamic key) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final result = await _makeIsolateCall<bool>(_Functions.containsKey, key);
      return result;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Saves the [key] - [value] pair.
  Future<void> put(dynamic key, T value) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.put, MapEntry(key, value));
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Associates the [value] with the n-th key. An exception is raised if the
  /// key does not exist.
  Future<void> putAt(int index, T value) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.putAt, MapEntry(index, value));
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Saves all the key - value pairs in the [entries] map.
  Future<void> putAll(Map<dynamic, T> entries) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.putAll, entries);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  Future<void> _migrateAll(Map<dynamic, T> entries) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    final input = entries.map(
      (key, entry) => MapEntry(key, _objectToBytes(entry)),
    );

    try {
      await _makeIsolateCall<void>(_Functions.putAll, input);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Saves the [value] with an auto-increment key.
  Future<int> add(T value) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final index = await _makeIsolateCall<int>(_Functions.add, value);
      return index;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Saves all the [values] with auto-increment keys.
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

  /// Deletes the given [key] from the box.
  Future<void> delete(dynamic key) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.delete, key);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Deletes the n-th key from the box.
  Future<void> deleteAt(int index) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.deleteAt, index);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Deletes all the given [keys] from the box.
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.deleteAll, keys.cast<dynamic>());
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Returns the value associated with the [key].
  /// If the key does not exist, [defaultValue] is returned.
  Future<T?> get(dynamic key, {T? defaultValue}) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final value = await _makeIsolateCall<T?>(_Functions.get, key);
      return value ?? defaultValue;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Returns the value associated with the n-th key.
  /// If the key does not exist, [defaultValue] is returned.
  Future<T?> getAt(int index, {T? defaultValue}) async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final value = await _makeIsolateCall<T?>(_Functions.getAt, index);
      return value ?? defaultValue;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Returns all the values from the box.
  Future<List<T>> getAll() async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      final values = await _makeIsolateCall<List<T>>(_Functions.getAll);
      return values;
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Deletes all the entries in the box.
  Future<void> clear() async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.clear);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Induces compaction manually. This is rarely needed. You should consider
  /// providing a custom compaction strategy instead.
  Future<void> flush() async {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    try {
      await _makeIsolateCall<void>(_Functions.flush);
    } catch (e) {
      throw IsolatedBoxException(e.toString());
    }
  }

  /// Returns a broadcast stream of change events.
  /// If the [key] parameter is provided, only events for the specified key are
  /// broadcast.
  Stream<BoxEvent> watch({dynamic key}) {
    assert(_sendPort != null, 'HiveIsolatedBox is not initialized');

    final receivePort = ReceivePort();
    _sendPort!.send(_ActionModel(_Functions.watch, key, receivePort.sendPort));

    return receivePort.cast<BoxEvent>().map((event) {
      if (event.value is Uint8List) {
        final jsonString = utf8.decode(event.value as Uint8List);
        final mapObject = jsonDecode(jsonString);
        final value = _fromJson?.call(mapObject) ?? mapObject as T;
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

  /// Removes all entries from the box.
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

  /// Closes the box.
  Future<void> dispose() async {
    if (_sendPort != null) {
      await _makeIsolateCall<void>(_Functions.dispose);
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    IsolateNameServer.removePortNameMapping(_boxName);
  }
//endregion
}

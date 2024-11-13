part of 'isolated_box.dart';

Future<void> _collectionIsolate<T>(List<dynamic> args) async {
  final mainSendPort = args[0] as SendPort;
  final boxName = args[1] as String;
  final dirPath = args[2] as String;

  final Box<Uint8List> box;
  try {
    /// Initialize Hive with dirPath
    Hive.init(dirPath);
    box = await Hive.openBox<Uint8List>(boxName);
  } catch (e) {
    mainSendPort.send('e: $e');
    return;
  }

  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    final portInput = message as List;
    final data = portInput[0] as Map<Object, Object?>;
    final responsePort = portInput[1] as SendPort;

    try {
      switch (data['action']) {
        case _Functions.preOpen:
          if (box.length > 0) box.getAt(0);
          responsePort.send(true);

        case _Functions.name:
          responsePort.send(box.name);

        case _Functions.isOpen:
          responsePort.send(box.isOpen);

        case _Functions.path:
          responsePort.send(box.path);

        case _Functions.keys:
          final keys = box.keys.map((key) => key.toString()).toList();
          responsePort.send(keys);

        case _Functions.length:
          responsePort.send(box.length);

        case _Functions.keyAt:
          final index = data['index']! as int;
          try {
            final key = box.keyAt(index);
            responsePort.send(key);
          } catch (e) {
            responsePort.send(null);
          }

        case _Functions.containsKey:
          final key = data['key'];
          final contains = box.containsKey(key);
          responsePort.send(contains);

        case _Functions.put:
          final key = data['key']! as String;
          final value = data['value']! as Uint8List;
          await box.put(key, value);
          responsePort.send(true);

        case _Functions.putAt:
          final key = data['index']! as int;
          final value = data['value']! as Uint8List;
          await box.putAt(key, value);
          responsePort.send(true);

        case _Functions.putAll:
          final values = data['entries']! as Map<String, Uint8List>;
          await box.putAll(values);
          responsePort.send(true);

        case _Functions.add:
          final input = data['value']! as Uint8List;
          final key = await box.add(input);
          responsePort.send(key);

        case _Functions.addAll:
          final input = data['values']! as List<Uint8List>;
          final keys = await box.addAll(input);
          responsePort.send(keys.toList());

        case _Functions.delete:
          final key = data['key']! as String;
          await box.delete(key);
          responsePort.send(true);

        case _Functions.deleteAt:
          final index = data['index']! as int;
          await box.deleteAt(index);
          responsePort.send(true);

        case _Functions.deleteAll:
          final keys = data['keys']! as Iterable<dynamic>;
          await box.deleteAll(keys);
          responsePort.send(true);

        case _Functions.get:
          final key = data['key']! as String;
          final result = box.get(key);
          responsePort.send(result);

        case _Functions.getAt:
          final index = data['index']! as int;
          final result = box.getAt(index);
          responsePort.send(result);

        case _Functions.getAll:
          final values = box.values.toList();
          responsePort.send(values);

        case _Functions.clear:
          await box.clear();
          responsePort.send(true);

        case _Functions.deleteFromDisk:
          await box.deleteFromDisk();
          responsePort.send(true);

        case _Functions.flush:
          await box.flush();
          responsePort.send(true);

        case _Functions.dispose:
          await box.close();
          responsePort.send(true);
          receivePort.close();

        default:
          throw UnsupportedError("Unsupported action: ${data['action']}");
      }
    } catch (e) {
      responsePort.send('e: $e');
    }
  }
}

class _Functions {
  static const preOpen = 'preOpen';
  static const name = 'name';
  static const isOpen = 'isOpen';
  static const path = 'path';
  static const length = 'length';
  static const keys = 'keys';
  static const keyAt = 'keyAt';
  static const containsKey = 'containsKey';
  static const put = 'put';
  static const putAt = 'putAt';
  static const putAll = 'putAll';
  static const add = 'add';
  static const addAll = 'addAll';
  static const delete = 'delete';
  static const deleteAt = 'deleteAt';
  static const deleteAll = 'deleteAll';
  static const get = 'get';
  static const getAt = 'getAt';
  static const getAll = 'getAll';
  static const clear = 'clear';
  static const deleteFromDisk = 'deleteFromDisk';
  static const flush = 'flush';
  static const dispose = 'dispose';

  List<String> get values => [
        preOpen,
        name,
        isOpen,
        path,
        length,
        keys,
        keyAt,
        containsKey,
        put,
        putAt,
        putAll,
        add,
        addAll,
        delete,
        deleteAt,
        deleteAll,
        get,
        getAt,
        getAll,
        clear,
        deleteFromDisk,
        flush,
        dispose,
      ];
}

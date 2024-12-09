part of 'isolated_box.dart';

class _ActionModel {
  final String action;
  final dynamic data;
  final SendPort responsePort;

  //data as null
  //data as int
  //data as dynamic (key)
  //data as MapEntry<String,Uint8List>
  //data as MapEntry<int, Uint8List>
  //data as Map<dynamic, Uint8List>
  //data as Uint8List
  //data as List<Uint8List>
  //data as Iterable<dynamic> (keys)
  //data as List<int>

  _ActionModel(this.action, this.data, this.responsePort);

  factory _ActionModel.fromJson(Map<String, dynamic> json) {
    return _ActionModel(
      json['action'] as String,
      json['data'],
      json['responsePort'] as SendPort,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'data': data,
        'responsePort': responsePort,
      };
}

Future<void> _collectionIsolate<T>(List<dynamic> args) async {
  final mainSendPort = args[0] as SendPort;
  final boxName = args[1] as String;
  final dirPath = args[2] as String;

  final Box<List<int>> box;
  try {
    /// Initialize Hive with dirPath
    Hive.init(dirPath);
    box = await Hive.openBox<List<int>>(boxName);
  } catch (e) {
    mainSendPort.send('e: $e');
    return;
  }

  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  final Map<SendPort, StreamSubscription<BoxEvent>> subscriptions = {};

  await for (dynamic model in receivePort) {
    if (model is Map<String, dynamic>) {
      model = _ActionModel.fromJson(model);
    }

    if (model is! _ActionModel) {
      throw ArgumentError('Invalid model type: ${model.runtimeType}');
    }

    final data = model.data;

    try {
      switch (model.action) {
        case _Functions.ping:
          model.responsePort.send(receivePort.sendPort);
          break;

        case _Functions.name:
          model.responsePort.send(box.name);
          break;

        case _Functions.isOpen:
          model.responsePort.send(box.isOpen);
          break;

        case _Functions.path:
          model.responsePort.send(box.path);
          break;

        case _Functions.keys:
          final keys = box.keys.toList();
          model.responsePort.send(keys);
          break;

        case _Functions.length:
          model.responsePort.send(box.length);
          break;

        case _Functions.keyAt:
          final index = data as int;
          try {
            final key = box.keyAt(index);
            model.responsePort.send(key);
          } catch (e) {
            model.responsePort.send(null);
          }
          break;

        case _Functions.containsKey:
          final key = data;
          final contains = box.containsKey(key);
          model.responsePort.send(contains);
          break;

        case _Functions.put:
          final entry = data as Set;
          await box.put(entry.first, Uint8List.fromList(entry.last));
          model.responsePort.send(true);
          break;

        case _Functions.putAt:
          final entry = data as Set;
          await box.putAt(entry.first, Uint8List.fromList(entry.last));
          model.responsePort.send(true);
          break;

        case _Functions.putAll:
          final values = data as Map<dynamic, List<int>>;
          await box.putAll(values);
          model.responsePort.send(true);
          break;

        case _Functions.add:
          final input = data as Uint8List;
          final key = await box.add(input);
          model.responsePort.send(key);
          break;

        case _Functions.addAll:
          final input = data.cast<Uint8List>();
          final keys = await box.addAll(input);
          model.responsePort.send(keys.toList());
          break;

        case _Functions.delete:
          final key = data;
          await box.delete(key);
          model.responsePort.send(true);
          break;

        case _Functions.deleteAt:
          final index = data as int;
          await box.deleteAt(index);
          model.responsePort.send(true);
          break;

        case _Functions.deleteAll:
          final keys = data as Iterable<dynamic>;
          await box.deleteAll(keys);
          model.responsePort.send(true);
          break;

        case _Functions.get:
          final key = data;
          final result = box.get(key);
          model.responsePort.send(result);
          break;

        case _Functions.getAt:
          final index = data as int;
          final result = box.getAt(index);
          model.responsePort.send(result);
          break;

        case _Functions.getAll:
          final values = box.values.toList();
          model.responsePort.send(values);
          break;

        case _Functions.clear:
          await box.clear();
          model.responsePort.send(true);
          break;

        case _Functions.flush:
          await box.flush();
          model.responsePort.send(true);
          break;

        case _Functions.dispose:
          for (final subscription in subscriptions.entries) {
            await subscription.value.cancel();
            subscriptions.remove(subscription.key);
          }
          await box.close();
          model.responsePort.send(true);
          receivePort.close();
          break;

        case _Functions.deleteFromDisk:
          for (final subscription in subscriptions.entries) {
            await subscription.value.cancel();
            subscriptions.remove(subscription.key);
          }
          await box.deleteFromDisk();
          model.responsePort.send(true);
          receivePort.close();
          break;

        case _Functions.watch:
          final key = data;
          final subscription = box
              .watch(key: key)
              .listen((event) => model.responsePort.send(event));

          subscriptions[model.responsePort] = subscription;
          break;

        case _Functions.unwatch:
          final subscription = subscriptions.remove(model.responsePort);
          await subscription?.cancel();
          break;

        default:
          throw UnsupportedError("Unsupported action: ${data['action']}");
      }
    } catch (e) {
      model.responsePort.send('e: $e');
    }
  }
}

class _Functions {
  static const ping = 'ping';
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
  static const watch = 'watch';
  static const unwatch = 'unwatch';
}

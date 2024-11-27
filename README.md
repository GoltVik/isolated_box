# Isolated Box

If Hive this is a history of Bees, then this is a history of relocation.

Main goal of this project is to provide an isolated environment for Hive collections/boxes and to
support asynchronous operations in cross-isolate environment.

## Features

- Provides an isolated environment for Hive boxes.
- Supports cross-isolate operations.
- Includes various methods for CRUD operations on Hive boxes.
- Supports cross-isolate data stream.

### Installation

Add the following dependencies to your `pubspec.yaml` file:

```yaml
dependencies:
  isolated_box: ^1.0.0
```

Run flutter pub get to install the dependencies.

### Usage

Initializing the Isolated Box:

```dart
import 'package:isolated_box/isolated_box.dart';

void main() async {
  final IsolatedBox<int> isolatedBox = await IsolatedBox.init<int>('box_name');
}
````

API is similar to Hive Box, so no additional learning curve is required, only difference is that all
operations are asynchronous because of Isolate communication.

## Models

IsolatedBox provides is not using `HiveObject` anymore, so no `TypeAdapter` is needed too.
You free to work with `freezed` or other libraries, just working with custom models provide
serialization and deserialization methods directly to `IsolatedBox.init`
method.

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'test_model.freezed.dart';

@freezed
class TestModel with _$TestModel {
  factory TestModel({
    required String id,
    required DateTime updatedAt,
  }) = _TestModel;

  static TestModel fromJson(Map<String, dynamic> json) {
    return TestModel(
      id: json['id'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static Map<String, dynamic> toJsonString(TestModel model) {
    return {
      'id': model.id,
      'updatedAt': model.updatedAt.toIso8601String(),
    };
  }
}
````

```dart
import 'package:isolated_box/isolated_box.dart';

void main() async {
  final isolatedBox = await IsolatedBox.init<TestModel>(
    boxName: boxName,
    fromJson: TestModel.fromJson,
    toJson: TestModel.toJsonString,
  );
}
````

### Migration from Hive

To migrate from Hive to Isolated Box, you need to replace `Hive` with `IsolatedBox` and define
migration strategy. Currently, there is two migration strategies available:

- `MigrationStrategy.deleteAndCreate` - It deletes all data and creates new Box.
- `MigrationStrategy.migrate` - Migrate data from Hive to Isolated Box.

During the first run you may see error log from Hive during initialization, but it is safe to
ignore.

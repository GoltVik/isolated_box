# Isolated Box

Isolated Box for Hive project.
Main goal of this project is to provide an isolated environment for Hive boxes and make collections 
cross-isolated without loosing Hive functions. 

## Features

- Provides an isolated environment for Hive boxes.
- Supports asynchronous operations for better performance.
- Includes various methods for CRUD operations on Hive boxes.

## Getting started

### Installation

Add the following dependencies to your `pubspec.yaml` file:

```yaml
dependencies:
  isolated_box: ^0.0.4
```

Run flutter pub get to install the dependencies.

### Usage

Initializing the Isolated Box:

```dart
import 'package:isolated_box/isolated_box.dart';

void main() async {
  final isolatedBox = IsolatedBox.init(
    
  );
}
````
import 'package:flutter/foundation.dart';

/// A class with migration options for isolated boxes.
class MigrationStrategy {
  final VoidCallback? initAdapters;

  MigrationStrategy._(this.initAdapters);

  /// Deletes the box and creates a new one.
  static MigrationStrategy deleteAndCreate = MigrationStrategy._(null);

  /// Migrates the data from the old box to the new one.
  factory MigrationStrategy.migrate(VoidCallback initAdapters) =>
      MigrationStrategy._(initAdapters);

  /// Returns whether the box should be migrated.
  bool get shouldMigrate => initAdapters != null;
}

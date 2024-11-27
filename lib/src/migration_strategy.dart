/// A class with migration options for isolated boxes.
enum MigrationStrategy {
  /// Deletes the box and creates a new one.
  deleteAndCreate,

  /// Migrates the data from the old box to the new one.
  migrate;
}

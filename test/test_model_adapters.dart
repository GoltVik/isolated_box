import 'package:hive_ce/hive.dart';

import 'test_model_hive.dart';

part 'test_model_adapters.g.dart';

@GenerateAdapters([AdapterSpec<TestModelHive>()])
// Annotations must be on some element
// ignore: unused_element
void _() {}

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(TestModelHiveAdapter());
  }
}

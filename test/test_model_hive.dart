import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'test_model_hive.freezed.dart';


@freezed
abstract class TestModelHive extends HiveObject with _$TestModelHive {
  factory TestModelHive({
    required String id,
    required DateTime updatedAt,
  }) = _TestModelHive;

  TestModelHive._();

  static TestModelHive fromJson(Map<String, dynamic> json) {
    return TestModelHive(
      id: json['id'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static Map<String, dynamic> toJsonString(TestModelHive model) {
    return {
      'id': model.id,
      'updatedAt': model.updatedAt.toIso8601String(),
    };
  }

  static TestModelHive mock([int? index]) => TestModelHive(
        id: index?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        updatedAt: DateTime.now(),
      );

  static List<TestModelHive> mockList(int count) {
    return List.generate(count, (i) => mock(i));
  }
}

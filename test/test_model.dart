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

  static TestModel mock([int? index]) => TestModel(
    id: index?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    updatedAt: DateTime.now(),
  );

  static List<TestModel> mockList(int count) {
    return List.generate(count, (i) => mock(i));
  }
}

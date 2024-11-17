import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'test_model.freezed.dart';
part 'test_model.g.dart';

@freezed
class TestModel extends HiveObject with _$TestModel {
  @HiveType(typeId: 1)
  factory TestModel({
    @HiveField(0) required String id,
    @HiveField(1) required DateTime updatedAt,
  }) = _TestModel;

  TestModel._();

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

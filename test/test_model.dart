class TestModel {
  final String id;
  final DateTime updatedAt;

  TestModel({
    required this.id,
    required this.updatedAt,
  });

  TestModel copyWith({
    String? id,
    DateTime? updatedAt,
  }) {
    return TestModel(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TestModel && other.id == id && other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => id.hashCode ^ updatedAt.hashCode;
}

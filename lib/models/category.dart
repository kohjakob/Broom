class Category {
  final String categoryId;
  final String name;
  final String? emoji;

  const Category({
    required this.categoryId,
    required this.name,
    this.emoji,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': categoryId,
      'name': name,
      'emoji': emoji,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      categoryId: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String?,
    );
  }

  Category copyWith({
    String? categoryId,
    String? name,
    Object? emoji = _sentinel,
  }) {
    return Category(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      emoji: emoji == _sentinel ? this.emoji : emoji as String?,
    );
  }
}

const _sentinel = Object();

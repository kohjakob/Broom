import 'dart:convert';

const _sentinel = Object();

class Item {
  final String itemId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String description;
  final List<String> images;
  final String? thumbnailImage;
  final double ranking;
  final int ratingCount;
  final List<String> categories;

  const Item({
    required this.itemId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.images = const [],
    this.thumbnailImage,
    this.ranking = 5.0,
    this.ratingCount = 0,
    this.categories = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': itemId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'description': description,
      'images': jsonEncode(images),
      'thumbnail_image': thumbnailImage,
      'ranking': ranking,
      'rating_count': ratingCount,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map, {List<String>? categoryIds}) {
    return Item(
      itemId: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      description: map['description'] as String,
      images: List<String>.from(jsonDecode(map['images'] as String)),
      thumbnailImage: map['thumbnail_image'] as String?,
      ranking: (map['ranking'] as num).toDouble(),
      ratingCount: map['rating_count'] as int,
      categories: categoryIds ?? const [],
    );
  }

  Item copyWith({
    String? itemId,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    List<String>? images,
    Object? thumbnailImage = _sentinel,
    double? ranking,
    int? ratingCount,
    List<String>? categories,
  }) {
    return Item(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      images: images ?? this.images,
      thumbnailImage: thumbnailImage == _sentinel ? this.thumbnailImage : thumbnailImage as String?,
      ranking: ranking ?? this.ranking,
      ratingCount: ratingCount ?? this.ratingCount,
      categories: categories ?? this.categories,
    );
  }
}

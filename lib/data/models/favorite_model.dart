import 'package:flutter/material.dart';

/// Enum đại diện cho các loại mục yêu thích tương ứng với FavoriteTargetType của backend
enum FavoriteTargetType {
  all(0, 'Tất cả', Icons.apps_rounded),
  place(1, 'Địa điểm', Icons.location_on_rounded),
  food(2, 'Ẩm thực', Icons.restaurant_rounded),
  itinerary(3, 'Hành trình', Icons.explore_rounded),
  blog(4, 'Bài viết', Icons.menu_book_rounded);

  final int value;
  final String label;
  final IconData icon;

  const FavoriteTargetType(this.value, this.label, this.icon);

  static FavoriteTargetType fromValue(int val) {
    switch (val) {
      case 1:
        return FavoriteTargetType.place;
      case 2:
        return FavoriteTargetType.food;
      case 3:
        return FavoriteTargetType.itinerary;
      case 4:
        return FavoriteTargetType.blog;
      default:
        return FavoriteTargetType.all;
    }
  }
}

/// Model cho từng mục yêu thích đã lưu
class FavoriteItemModel {
  final int id;
  final int targetId;
  final int targetType;
  final String title;
  final String subtitle;
  final String coverImg;
  final String categoryTag;
  final double rating;
  final int reviewCount;
  final String? price;
  final String savedDate;
  final List<String> mediaUrls;

  const FavoriteItemModel({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.title,
    this.subtitle = '',
    this.coverImg = '',
    this.categoryTag = '',
    this.rating = 5.0,
    this.reviewCount = 0,
    this.price,
    this.savedDate = '',
    this.mediaUrls = const [],
  });

  FavoriteItemModel copyWith({
    int? id,
    int? targetId,
    int? targetType,
    String? title,
    String? subtitle,
    String? coverImg,
    String? categoryTag,
    double? rating,
    int? reviewCount,
    String? price,
    String? savedDate,
    List<String>? mediaUrls,
  }) {
    return FavoriteItemModel(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      coverImg: coverImg ?? this.coverImg,
      categoryTag: categoryTag ?? this.categoryTag,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      price: price ?? this.price,
      savedDate: savedDate ?? this.savedDate,
      mediaUrls: mediaUrls ?? this.mediaUrls,
    );
  }

  FavoriteTargetType get targetTypeEnum => FavoriteTargetType.fromValue(targetType);

  factory FavoriteItemModel.fromJson(Map<String, dynamic> json) {
    List<String> mediaList = [];
    if (json['mediaUrls'] is List) {
      mediaList = (json['mediaUrls'] as List).map((e) => e.toString()).toList();
    } else if (json['mediaUrls'] is String && (json['mediaUrls'] as String).isNotEmpty) {
      mediaList = [json['mediaUrls'] as String];
    }

    final cover = json['coverImg']?.toString() ??
        (mediaList.isNotEmpty ? mediaList.first : '');

    return FavoriteItemModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      targetId: json['targetId'] is num ? (json['targetId'] as num).toInt() : int.tryParse(json['targetId']?.toString() ?? '0') ?? 0,
      targetType: json['targetType'] is num ? (json['targetType'] as num).toInt() : int.tryParse(json['targetType']?.toString() ?? '1') ?? 1,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      coverImg: cover,
      categoryTag: json['categoryTag']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: json['reviewCount'] is num ? (json['reviewCount'] as num).toInt() : int.tryParse(json['reviewCount']?.toString() ?? '0') ?? 0,
      price: json['price']?.toString(),
      savedDate: json['savedDate']?.toString() ?? '',
      mediaUrls: mediaList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'targetId': targetId,
      'targetType': targetType,
      'title': title,
      'subtitle': subtitle,
      'coverImg': coverImg,
      'categoryTag': categoryTag,
      'rating': rating,
      'reviewCount': reviewCount,
      'price': price,
      'savedDate': savedDate,
      'mediaUrls': mediaUrls,
    };
  }
}

/// Model cho kết quả phân trang danh sách yêu thích
class FavoritePagedResultModel {
  final List<FavoriteItemModel> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const FavoritePagedResultModel({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory FavoritePagedResultModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<FavoriteItemModel> list = [];
    if (rawItems is List) {
      list = rawItems.map((item) => FavoriteItemModel.fromJson(item as Map<String, dynamic>)).toList();
    }

    final total = json['totalCount'] is num ? (json['totalCount'] as num).toInt() : list.length;
    final size = json['pageSize'] is num ? (json['pageSize'] as num).toInt() : 12;
    final p = json['page'] is num ? (json['page'] as num).toInt() : 1;
    final pages = json['totalPages'] is num
        ? (json['totalPages'] as num).toInt()
        : (size > 0 ? (total / size).ceil() : 1);

    return FavoritePagedResultModel(
      items: list,
      page: p,
      pageSize: size,
      totalCount: total,
      totalPages: pages,
    );
  }

  FavoritePagedResultModel copyWith({
    List<FavoriteItemModel>? items,
    int? page,
    int? pageSize,
    int? totalCount,
    int? totalPages,
  }) {
    return FavoritePagedResultModel(
      items: items ?? this.items,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

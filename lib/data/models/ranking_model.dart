class RankingOverviewData {
  final String? title;
  final String? subtitle;
  final List<RankingOverviewCategory> categories;

  const RankingOverviewData({
    this.title,
    this.subtitle,
    required this.categories,
  });

  factory RankingOverviewData.fromJson(Map<String, dynamic> json) {
    return RankingOverviewData(
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => RankingOverviewCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class RankingOverviewCategory {
  final String key;
  final String type; // 'place' | 'province' | 'place_type'
  final int? placeTypeId;
  final String? title;
  final String? vietnameseTitle;
  final String? coverImageUrl;

  const RankingOverviewCategory({
    required this.key,
    required this.type,
    this.placeTypeId,
    this.title,
    this.vietnameseTitle,
    this.coverImageUrl,
  });

  factory RankingOverviewCategory.fromJson(Map<String, dynamic> json) {
    return RankingOverviewCategory(
      key: json['key']?.toString() ?? '',
      type: json['type']?.toString() ?? 'place_type',
      placeTypeId: (json['placeTypeId'] as num?)?.toInt(),
      title: json['title']?.toString(),
      vietnameseTitle: json['vietnameseTitle']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
    );
  }

  String get displayName => vietnameseTitle?.isNotEmpty == true
      ? vietnameseTitle!
      : (title?.isNotEmpty == true ? title! : 'Bảng xếp hạng');
}

class RankingDetailHeader {
  final String? title;
  final String? subtitle;
  final String? coverImageUrl;
  final String? badge;
  final String? targetName;

  const RankingDetailHeader({
    this.title,
    this.subtitle,
    this.coverImageUrl,
    this.badge,
    this.targetName,
  });

  factory RankingDetailHeader.fromJson(Map<String, dynamic> json) {
    return RankingDetailHeader(
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      badge: json['badge']?.toString(),
      targetName: json['targetName']?.toString(),
    );
  }
}

class RankingSubCategory {
  final int id;
  final String name;
  final String? code;
  final String? slug;
  final int placeCount;

  const RankingSubCategory({
    required this.id,
    required this.name,
    this.code,
    this.slug,
    this.placeCount = 0,
  });

  factory RankingSubCategory.fromJson(Map<String, dynamic> json) {
    return RankingSubCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      slug: json['slug']?.toString(),
      placeCount: (json['placeCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class RankingProvinceOption {
  final int id;
  final String name;
  final int regionId;
  final String regionName;

  const RankingProvinceOption({
    required this.id,
    required this.name,
    required this.regionId,
    required this.regionName,
  });

  factory RankingProvinceOption.fromJson(Map<String, dynamic> json) {
    return RankingProvinceOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      regionId: (json['regionId'] as num?)?.toInt() ?? 0,
      regionName: json['regionName']?.toString() ?? '',
    );
  }
}

class RankingReviewSnippet {
  final int reviewId;
  final String authorName;
  final String? authorAvatar;
  final double rating;
  final String content;
  final int likesCount;
  final String createdAt;

  const RankingReviewSnippet({
    required this.reviewId,
    required this.authorName,
    this.authorAvatar,
    this.rating = 5.0,
    required this.content,
    this.likesCount = 0,
    required this.createdAt,
  });

  factory RankingReviewSnippet.fromJson(Map<String, dynamic> json) {
    return RankingReviewSnippet(
      reviewId: (json['reviewId'] as num?)?.toInt() ?? 0,
      authorName: json['authorName']?.toString() ?? 'Du khách',
      authorAvatar: json['authorAvatar']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      content: json['content']?.toString() ?? '',
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class RankingPlaceItem {
  final int rank;
  final String? badge;
  final int id;
  final String name;
  final String? description;
  final String? address;
  final int provinceId;
  final String provinceName;
  final int categoryId;
  final String categoryName;
  final int placeTypeId;
  final String placeTypeName;
  final String? coverImageUrl;
  final double avgRating;
  final int reviewCount;
  final int viewCount;
  final int favoritesCount;
  final double score;
  final List<String> greatThingsToDo;
  final RankingReviewSnippet? featuredReview;

  const RankingPlaceItem({
    required this.rank,
    this.badge,
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.provinceId = 0,
    this.provinceName = '',
    this.categoryId = 0,
    this.categoryName = '',
    this.placeTypeId = 0,
    this.placeTypeName = '',
    this.coverImageUrl,
    this.avgRating = 0.0,
    this.reviewCount = 0,
    this.viewCount = 0,
    this.favoritesCount = 0,
    this.score = 0.0,
    this.greatThingsToDo = const [],
    this.featuredReview,
  });

  factory RankingPlaceItem.fromJson(Map<String, dynamic> json) {
    return RankingPlaceItem(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      badge: json['badge']?.toString(),
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      address: json['address']?.toString(),
      provinceId: (json['provinceId'] as num?)?.toInt() ?? 0,
      provinceName: json['provinceName']?.toString() ?? '',
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      categoryName: json['categoryName']?.toString() ?? '',
      placeTypeId: (json['placeTypeId'] as num?)?.toInt() ?? 0,
      placeTypeName: json['placeTypeName']?.toString() ?? '',
      coverImageUrl: json['coverImageUrl']?.toString(),
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      favoritesCount: (json['favoritesCount'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      greatThingsToDo: (json['greatThingsToDo'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      featuredReview: json['featuredReview'] != null
          ? RankingReviewSnippet.fromJson(json['featuredReview'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AwardWinningPlace {
  final int rank;
  final String? badge;
  final int id;
  final String name;
  final String? address;
  final int? placeTypeId;
  final String? placeTypeName;
  final int? categoryId;
  final String? categoryName;
  final double avgRating;
  final int reviewCount;
  final int viewCount;
  final String? thumbnailUrl;
  final double score;

  const AwardWinningPlace({
    required this.rank,
    this.badge,
    required this.id,
    required this.name,
    this.address,
    this.placeTypeId,
    this.placeTypeName,
    this.categoryId,
    this.categoryName,
    this.avgRating = 0.0,
    this.reviewCount = 0,
    this.viewCount = 0,
    this.thumbnailUrl,
    this.score = 0.0,
  });

  factory AwardWinningPlace.fromJson(Map<String, dynamic> json) {
    return AwardWinningPlace(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      badge: json['badge']?.toString(),
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      placeTypeId: (json['placeTypeId'] as num?)?.toInt(),
      placeTypeName: json['placeTypeName']?.toString(),
      categoryId: (json['categoryId'] as num?)?.toInt(),
      categoryName: json['categoryName']?.toString(),
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DestinationRankingItem {
  final int rank;
  final String? badge;
  final int id;
  final String name;
  final String? slug;
  final String? tagline;
  final String? description;
  final String? imageUrl;
  final int regionId;
  final String regionName;
  final int totalPlaces;
  final int totalReviews;
  final double avgRating;
  final double score;
  final List<String> greatThingsToDo;
  final List<AwardWinningPlace> awardWinningPlaces;

  const DestinationRankingItem({
    required this.rank,
    this.badge,
    required this.id,
    required this.name,
    this.slug,
    this.tagline,
    this.description,
    this.imageUrl,
    this.regionId = 0,
    this.regionName = '',
    this.totalPlaces = 0,
    this.totalReviews = 0,
    this.avgRating = 0.0,
    this.score = 0.0,
    this.greatThingsToDo = const [],
    this.awardWinningPlaces = const [],
  });

  factory DestinationRankingItem.fromJson(Map<String, dynamic> json) {
    return DestinationRankingItem(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      badge: json['badge']?.toString(),
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      tagline: json['tagline']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      regionId: (json['regionId'] as num?)?.toInt() ?? 0,
      regionName: json['regionName']?.toString() ?? '',
      totalPlaces: (json['totalPlaces'] as num?)?.toInt() ?? 0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      greatThingsToDo: (json['greatThingsToDo'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      awardWinningPlaces: (json['awardWinningPlaces'] as List<dynamic>?)
              ?.map((e) => AwardWinningPlace.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class RankingDetailViewData {
  final RankingDetailHeader header;
  final List<RankingSubCategory> subCategories;
  final List<RankingProvinceOption> availableProvinces;
  final List<DestinationRankingItem> provinceItems;
  final List<RankingPlaceItem> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const RankingDetailViewData({
    required this.header,
    required this.subCategories,
    required this.availableProvinces,
    required this.provinceItems,
    required this.items,
    this.page = 1,
    this.pageSize = 10,
    this.totalCount = 0,
    this.totalPages = 1,
  });

  factory RankingDetailViewData.fromJson(Map<String, dynamic> json) {
    final totalCount = (json['totalCount'] as num?)?.toInt() ?? 0;
    final pageSize = (json['pageSize'] as num?)?.toInt() ?? 10;
    final computedTotalPages = pageSize > 0 ? ((totalCount + pageSize - 1) ~/ pageSize) : 1;
    final totalPages = (json['totalPages'] as num?)?.toInt() ?? (computedTotalPages > 0 ? computedTotalPages : 1);

    return RankingDetailViewData(
      header: json['header'] != null
          ? RankingDetailHeader.fromJson(json['header'] as Map<String, dynamic>)
          : const RankingDetailHeader(),
      subCategories: (json['subCategories'] as List<dynamic>?)
              ?.map((e) => RankingSubCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      availableProvinces: (json['availableProvinces'] as List<dynamic>?)
              ?.map((e) => RankingProvinceOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      provinceItems: (json['provinceItems'] as List<dynamic>?)
              ?.map((e) => DestinationRankingItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => RankingPlaceItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages,
    );
  }
}

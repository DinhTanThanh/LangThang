import 'place_filter_dto.dart';
import 'food_model.dart';

class RegionHeroImage {
  final String url;
  final String title;
  final String location;
  final String? tag;

  const RegionHeroImage({
    required this.url,
    required this.title,
    required this.location,
    this.tag,
  });

  factory RegionHeroImage.fromJson(Map<String, dynamic> json) {
    return RegionHeroImage(
      url: json['url'] as String? ?? json['imageUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      location: json['location'] as String? ?? '',
      tag: json['tag'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'location': location,
    if (tag != null) 'tag': tag,
  };
}

class RegionLandmarkModel {
  final dynamic id;
  final String name;
  final String province;
  final String location;
  final List<double>? coordinates;
  final double rating;
  final int reviewCount;
  final int savedCount;
  final String? imageUrl;
  final List<String> mediaUrls;
  final String? category;
  final String? price;

  const RegionLandmarkModel({
    required this.id,
    required this.name,
    required this.province,
    required this.location,
    this.coordinates,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.savedCount = 0,
    this.imageUrl,
    this.mediaUrls = const [],
    this.category,
    this.price,
  });

  factory RegionLandmarkModel.fromJson(Map<String, dynamic> json) {
    List<double>? coords;
    if (json['coordinates'] != null) {
      coords = (json['coordinates'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
    } else if (json['latitude'] != null && json['longitude'] != null) {
      coords = [
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ];
    }

    List<String> media = [];
    if (json['mediaUrls'] != null) {
      media = (json['mediaUrls'] as List<dynamic>).map((e) => e.toString()).toList();
    } else if (json['imageUrl'] != null) {
      media = [json['imageUrl'].toString()];
    }

    return RegionLandmarkModel(
      id: json['id'] ?? '',
      name: json['name'] as String? ?? '',
      province: json['province'] as String? ?? '',
      location: json['location'] as String? ?? json['address'] as String? ?? '',
      coordinates: coords,
      rating: (json['rating'] as num?)?.toDouble() ?? (json['avgRating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      savedCount: json['savedCount'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String?,
      mediaUrls: media,
      category: json['category'] as String? ?? json['categoryName'] as String?,
      price: json['price'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'province': province,
    'location': location,
    if (coordinates != null) 'coordinates': coordinates,
    'rating': rating,
    'reviewCount': reviewCount,
    'savedCount': savedCount,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'mediaUrls': mediaUrls,
    if (category != null) 'category': category,
    if (price != null) 'price': price,
  };
}

class RegionBlogAuthor {
  final String name;
  final String? avatar;

  const RegionBlogAuthor({
    required this.name,
    this.avatar,
  });

  factory RegionBlogAuthor.fromJson(Map<String, dynamic> json) {
    return RegionBlogAuthor(
      name: json['name'] as String? ?? 'Lang Thang Blogger',
      avatar: json['avatar'] as String? ?? json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (avatar != null) 'avatar': avatar,
  };
}

class RegionBlogPostModel {
  final dynamic id;
  final String slug;
  final String title;
  final String? excerpt;
  final String? coverUrl;
  final String publishedAt;
  final String readTime;
  final String category;
  final String? location;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final String? statusOrHours;
  final String? badgeText;
  final RegionBlogAuthor author;

  const RegionBlogPostModel({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.coverUrl,
    required this.publishedAt,
    required this.readTime,
    required this.category,
    this.location,
    this.rating = 5.0,
    this.reviewCount = 12,
    this.tags = const [],
    this.statusOrHours,
    this.badgeText,
    required this.author,
  });

  factory RegionBlogPostModel.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'];
    RegionBlogAuthor authorObj;
    if (authorJson is Map<String, dynamic>) {
      authorObj = RegionBlogAuthor.fromJson(authorJson);
    } else {
      authorObj = RegionBlogAuthor(
        name: json['authorName'] as String? ?? 'Lang Thang Blogger',
        avatar: json['authorAvatar'] as String?,
      );
    }

    return RegionBlogPostModel(
      id: json['id'] ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      coverUrl: json['coverUrl'] as String? ?? json['coverImageUrl'] as String?,
      publishedAt: json['publishedAt'] as String? ?? 'Hôm nay',
      readTime: json['readTime'] as String? ?? '5 phút đọc',
      category: json['category'] as String? ?? json['categoryName'] as String? ?? 'Cẩm nang du lịch',
      location: json['location'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: json['reviewCount'] as int? ?? 12,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      statusOrHours: json['statusOrHours'] as String? ?? 'Khám phá tự do',
      badgeText: json['badgeText'] as String?,
      author: authorObj,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title': title,
    if (excerpt != null) 'excerpt': excerpt,
    if (coverUrl != null) 'coverUrl': coverUrl,
    'publishedAt': publishedAt,
    'readTime': readTime,
    'category': category,
    if (location != null) 'location': location,
    'rating': rating,
    'reviewCount': reviewCount,
    'tags': tags,
    if (statusOrHours != null) 'statusOrHours': statusOrHours,
    if (badgeText != null) 'badgeText': badgeText,
    'author': author.toJson(),
  };
}

class RegionSpotlightModel {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String province;
  final int totalReviews;
  final double avgRating;
  final String bannerUrl;
  final List<double>? coordinates;
  final List<String> highlights;

  const RegionSpotlightModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.province,
    this.totalReviews = 0,
    this.avgRating = 5.0,
    required this.bannerUrl,
    this.coordinates,
    this.highlights = const [],
  });

  factory RegionSpotlightModel.fromJson(Map<String, dynamic> json) {
    List<double>? coords;
    if (json['coordinates'] != null) {
      coords = (json['coordinates'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    return RegionSpotlightModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      province: json['province'] as String? ?? '',
      totalReviews: json['totalReviews'] as int? ?? 0,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 5.0,
      bannerUrl: json['bannerUrl'] as String? ?? '',
      coordinates: coords,
      highlights: (json['highlights'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'province': province,
    'totalReviews': totalReviews,
    'avgRating': avgRating,
    'bannerUrl': bannerUrl,
    if (coordinates != null) 'coordinates': coordinates,
    'highlights': highlights,
  };
}

class RegionReviewModel {
  final dynamic id;
  final String reviewerName;
  final String? reviewerAvatar;
  final int rating;
  final String placeName;
  final dynamic placeId;
  final String visitDate;
  final String content;
  final List<String> images;
  final int likesCount;
  final List<double>? coordinates;

  const RegionReviewModel({
    required this.id,
    required this.reviewerName,
    this.reviewerAvatar,
    this.rating = 5,
    required this.placeName,
    this.placeId,
    required this.visitDate,
    required this.content,
    this.images = const [],
    this.likesCount = 0,
    this.coordinates,
  });

  factory RegionReviewModel.fromJson(Map<String, dynamic> json) {
    List<double>? coords;
    if (json['coordinates'] != null) {
      coords = (json['coordinates'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    return RegionReviewModel(
      id: json['id'] ?? '',
      reviewerName: json['reviewerName'] as String? ?? 'Du khách',
      reviewerAvatar: json['reviewerAvatar'] as String?,
      rating: json['rating'] as int? ?? 5,
      placeName: json['placeName'] as String? ?? '',
      placeId: json['placeId'],
      visitDate: json['visitDate'] as String? ?? 'Gần đây',
      content: json['content'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      likesCount: json['likesCount'] as int? ?? 0,
      coordinates: coords,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reviewerName': reviewerName,
    if (reviewerAvatar != null) 'reviewerAvatar': reviewerAvatar,
    'rating': rating,
    'placeName': placeName,
    if (placeId != null) 'placeId': placeId,
    'visitDate': visitDate,
    'content': content,
    'images': images,
    'likesCount': likesCount,
    if (coordinates != null) 'coordinates': coordinates,
  };
}

class RegionLandingModel {
  final String code;
  final String name;
  final String shortTitle;
  final String? badgeText;
  final String heroHeadline;
  final String heroSubheadline;
  final List<String> provinces;
  final List<RegionHeroImage> heroImages;
  final List<CollectionDto> collections;
  final List<RegionLandmarkModel> landmarks;
  final List<FoodModel> foods;
  final List<RegionBlogPostModel> blogPosts;
  final RegionSpotlightModel? spotlight;
  final List<RegionReviewModel> reviews;

  const RegionLandingModel({
    required this.code,
    required this.name,
    required this.shortTitle,
    this.badgeText,
    required this.heroHeadline,
    required this.heroSubheadline,
    this.provinces = const [],
    this.heroImages = const [],
    this.collections = const [],
    this.landmarks = const [],
    this.foods = const [],
    this.blogPosts = const [],
    this.spotlight,
    this.reviews = const [],
  });

  factory RegionLandingModel.fromJson(Map<String, dynamic> json) {
    List<RegionHeroImage> heroImgs = [];
    if (json['heroImages'] != null) {
      heroImgs = (json['heroImages'] as List<dynamic>)
          .map((e) => RegionHeroImage.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<String> provs = [];
    if (json['provinces'] != null) {
      provs = (json['provinces'] as List<dynamic>).map((e) => e.toString()).toList();
    }

    List<CollectionDto> cols = [];
    if (json['collections'] != null) {
      cols = (json['collections'] as List<dynamic>)
          .map((e) => CollectionDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<RegionLandmarkModel> lands = [];
    if (json['landmarks'] != null) {
      lands = (json['landmarks'] as List<dynamic>)
          .map((e) => RegionLandmarkModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<FoodModel> foodList = [];
    if (json['foods'] != null) {
      foodList = (json['foods'] as List<dynamic>)
          .map((e) => FoodModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<RegionBlogPostModel> blogs = [];
    if (json['blogPosts'] != null) {
      blogs = (json['blogPosts'] as List<dynamic>)
          .map((e) => RegionBlogPostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    RegionSpotlightModel? spot;
    if (json['spotlight'] != null) {
      spot = RegionSpotlightModel.fromJson(json['spotlight'] as Map<String, dynamic>);
    }

    List<RegionReviewModel> revs = [];
    if (json['reviews'] != null) {
      revs = (json['reviews'] as List<dynamic>)
          .map((e) => RegionReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return RegionLandingModel(
      code: json['code'] as String? ?? 'north',
      name: json['name'] as String? ?? 'Miền Bắc',
      shortTitle: json['shortTitle'] as String? ?? '',
      badgeText: json['badgeText'] as String?,
      heroHeadline: json['heroHeadline'] as String? ?? '',
      heroSubheadline: json['heroSubheadline'] as String? ?? '',
      provinces: provs,
      heroImages: heroImgs,
      collections: cols,
      landmarks: lands,
      foods: foodList,
      blogPosts: blogs,
      spotlight: spot,
      reviews: revs,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'shortTitle': shortTitle,
    if (badgeText != null) 'badgeText': badgeText,
    'heroHeadline': heroHeadline,
    'heroSubheadline': heroSubheadline,
    'provinces': provinces,
    'heroImages': heroImages.map((e) => e.toJson()).toList(),
    'collections': collections.map((e) => e.toJson()).toList(),
    'landmarks': landmarks.map((e) => e.toJson()).toList(),
    'foods': foods.map((e) => e.toJson()).toList(),
    'blogPosts': blogPosts.map((e) => e.toJson()).toList(),
    if (spotlight != null) 'spotlight': spotlight!.toJson(),
    'reviews': reviews.map((e) => e.toJson()).toList(),
  };
}

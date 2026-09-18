/// Mô hình dữ liệu cho Nhật ký chuyến đi (Visit Log)
class VisitLogItemModel {
  final int id;
  final int placeId;
  final String placeName;
  final String province;
  final String category;
  final String visitedDate;
  final int privacy; // 0: Riêng tư, 1: Công khai
  final String coverImg;
  final double? lat;
  final double? lng;
  final String createdAt;

  const VisitLogItemModel({
    required this.id,
    required this.placeId,
    required this.placeName,
    this.province = '',
    this.category = '',
    required this.visitedDate,
    this.privacy = 1,
    this.coverImg = '',
    this.lat,
    this.lng,
    this.createdAt = '',
  });

  factory VisitLogItemModel.fromJson(Map<String, dynamic> json) {
    return VisitLogItemModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      placeId: json['placeId'] is num ? (json['placeId'] as num).toInt() : int.tryParse(json['placeId']?.toString() ?? '0') ?? 0,
      placeName: json['placeName']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      visitedDate: json['visitedDate']?.toString() ?? '',
      privacy: json['privacy'] is num ? (json['privacy'] as num).toInt() : int.tryParse(json['privacy']?.toString() ?? '1') ?? 1,
      coverImg: json['coverImg']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  VisitLogItemModel copyWith({
    int? id,
    int? placeId,
    String? placeName,
    String? province,
    String? category,
    String? visitedDate,
    int? privacy,
    String? coverImg,
    double? lat,
    double? lng,
    String? createdAt,
  }) {
    return VisitLogItemModel(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      province: province ?? this.province,
      category: category ?? this.category,
      visitedDate: visitedDate ?? this.visitedDate,
      privacy: privacy ?? this.privacy,
      coverImg: coverImg ?? this.coverImg,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'placeId': placeId,
      'placeName': placeName,
      'province': province,
      'category': category,
      'visitedDate': visitedDate,
      'privacy': privacy,
      'coverImg': coverImg,
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt,
    };
  }
}

/// Mô hình dữ liệu cho Đánh giá của người dùng (User Review)
class UserReviewItemModel {
  final int id;
  final int placeId;
  final String placeName;
  final String placeThumb;
  final String province;
  final String category;
  final int rating;
  final String content;
  final String visitDate;
  final String coverImg;
  final List<String> images;
  final int helpfulCount;
  final String createdAt;

  const UserReviewItemModel({
    required this.id,
    required this.placeId,
    required this.placeName,
    this.placeThumb = '',
    this.province = '',
    this.category = '',
    required this.rating,
    this.content = '',
    this.visitDate = '',
    this.coverImg = '',
    this.images = const [],
    this.helpfulCount = 0,
    this.createdAt = '',
  });

  factory UserReviewItemModel.fromJson(Map<String, dynamic> json) {
    List<String> imgList = [];
    if (json['images'] is List) {
      imgList = (json['images'] as List).map((e) => e.toString()).toList();
    } else if (json['photos'] is List) {
      imgList = (json['photos'] as List).map((e) => e.toString()).toList();
    }

    return UserReviewItemModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      placeId: json['placeId'] is num ? (json['placeId'] as num).toInt() : int.tryParse(json['placeId']?.toString() ?? '0') ?? 0,
      placeName: json['placeName']?.toString() ?? '',
      placeThumb: json['placeThumb']?.toString() ?? (json['coverImg']?.toString() ?? ''),
      province: json['province']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      rating: json['rating'] is num ? (json['rating'] as num).toInt() : int.tryParse(json['rating']?.toString() ?? '5') ?? 5,
      content: json['content']?.toString() ?? '',
      visitDate: json['visitDate']?.toString() ?? '',
      coverImg: json['coverImg']?.toString() ?? '',
      images: imgList,
      helpfulCount: json['helpfulCount'] is num ? (json['helpfulCount'] as num).toInt() : int.tryParse(json['helpfulCount']?.toString() ?? '0') ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

/// Mô hình dữ liệu cho Bình luận của người dùng (User Comment)
class UserCommentItemModel {
  final int id;
  final int? reviewId;
  final int placeId;
  final String placeName;
  final String placeThumb;
  final String content;
  final String? parentAuthor;
  final String createdAt;

  const UserCommentItemModel({
    required this.id,
    this.reviewId,
    required this.placeId,
    required this.placeName,
    this.placeThumb = '',
    required this.content,
    this.parentAuthor,
    this.createdAt = '',
  });

  factory UserCommentItemModel.fromJson(Map<String, dynamic> json) {
    return UserCommentItemModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      reviewId: json['reviewId'] is num ? (json['reviewId'] as num).toInt() : null,
      placeId: json['placeId'] is num ? (json['placeId'] as num).toInt() : int.tryParse(json['placeId']?.toString() ?? '0') ?? 0,
      placeName: json['placeName']?.toString() ?? '',
      placeThumb: json['placeThumb']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      parentAuthor: json['parentAuthor']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

/// Mô hình dữ liệu cho Bài viết của người dùng (User Blog)
class UserBlogItemModel {
  final int id;
  final String title;
  final String slug;
  final String coverImg;
  final String excerpt;
  final int status; // 0: Bản nháp, 1: Đã xuất bản
  final String category;
  final int readTimeMinutes;
  final int viewsCount;
  final int likesCount;
  final String createdAt;

  const UserBlogItemModel({
    required this.id,
    required this.title,
    this.slug = '',
    this.coverImg = '',
    this.excerpt = '',
    this.status = 1,
    this.category = 'Cẩm nang du lịch',
    this.readTimeMinutes = 5,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.createdAt = '',
  });

  factory UserBlogItemModel.fromJson(Map<String, dynamic> json) {
    return UserBlogItemModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      coverImg: json['coverImageUrl']?.toString() ?? (json['coverImg']?.toString() ?? ''),
      excerpt: json['excerpt']?.toString() ?? '',
      status: json['status'] is num ? (json['status'] as num).toInt() : int.tryParse(json['status']?.toString() ?? '1') ?? 1,
      category: json['categoryName']?.toString() ?? (json['category']?.toString() ?? 'Cẩm nang du lịch'),
      readTimeMinutes: json['readTimeMinutes'] is num ? (json['readTimeMinutes'] as num).toInt() : 5,
      viewsCount: json['viewsCount'] is num ? (json['viewsCount'] as num).toInt() : ((json['viewCount'] as num?)?.toInt() ?? 0),
      likesCount: json['likesCount'] is num ? (json['likesCount'] as num).toInt() : 0,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

/// Mô hình dữ liệu cho Đề xuất địa điểm của người dùng (User Proposal)
class ProposalItemModel {
  final int id;
  final String name;
  final String category;
  final String province;
  final String address;
  final String phone;
  final String website;
  final String openingHours;
  final String priceRange;
  final String description;
  final String coverImg;
  final List<String> mediaUrls;
  final int status; // 0: Đang chờ duyệt, 1: Đã chấp thuận, 2: Bị từ chối
  final String? rejectReason;
  final String createdAt;
  final int viewsCount;
  final int favoritesCount;

  const ProposalItemModel({
    required this.id,
    required this.name,
    this.category = 'Khám phá',
    this.province = '',
    this.address = '',
    this.phone = '',
    this.website = '',
    this.openingHours = '07:30 – 18:00',
    this.priceRange = 'Miễn phí',
    this.description = '',
    this.coverImg = '',
    this.mediaUrls = const [],
    this.status = 0,
    this.rejectReason,
    this.createdAt = '',
    this.viewsCount = 0,
    this.favoritesCount = 0,
  });

  factory ProposalItemModel.fromJson(Map<String, dynamic> json) {
    List<String> mediaList = [];
    if (json['mediaUrls'] is List) {
      mediaList = (json['mediaUrls'] as List).map((e) => e.toString()).toList();
    }

    final cover = json['coverImg']?.toString() ?? (mediaList.isNotEmpty ? mediaList.first : '');

    return ProposalItemModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Khám phá',
      province: json['province']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      openingHours: json['openingHours']?.toString() ?? '07:30 – 18:00',
      priceRange: json['minPrice'] != null ? '${json['minPrice']} - ${json['maxPrice'] ?? ""}' : 'Miễn phí',
      description: json['description']?.toString() ?? '',
      coverImg: cover,
      mediaUrls: mediaList.isNotEmpty ? mediaList : (cover.isNotEmpty ? [cover] : []),
      status: json['status'] is num ? (json['status'] as num).toInt() : int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      rejectReason: json['rejectReason']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      viewsCount: (json['viewsCount'] as num?)?.toInt() ?? 0,
      favoritesCount: (json['favoritesCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'province': province,
      'address': address,
      'phone': phone,
      'website': website,
      'openingHours': openingHours,
      'priceRange': priceRange,
      'description': description,
      'coverImg': coverImg,
      'mediaUrls': mediaUrls,
      'status': status,
      'rejectReason': rejectReason,
      'createdAt': createdAt,
      'viewsCount': viewsCount,
      'favoritesCount': favoritesCount,
    };
  }
}

/// Mô hình dữ liệu cho Lịch sử xem địa điểm gần đây (Access History / Recent Visited)
class UserAccessHistoryItemModel {
  final int placeId;
  final String placeName;
  final String province;
  final String category;
  final String coverImg;
  final double avgRating;
  final String viewedAt;

  const UserAccessHistoryItemModel({
    required this.placeId,
    required this.placeName,
    this.province = '',
    this.category = '',
    this.coverImg = '',
    this.avgRating = 5.0,
    this.viewedAt = '',
  });

  factory UserAccessHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return UserAccessHistoryItemModel(
      placeId: json['placeId'] is num ? (json['placeId'] as num).toInt() : (json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['placeId']?.toString() ?? json['id']?.toString() ?? '0') ?? 0),
      placeName: json['placeName']?.toString() ?? (json['name']?.toString() ?? ''),
      province: json['province']?.toString() ?? (json['provinceName']?.toString() ?? ''),
      category: json['category']?.toString() ?? (json['categoryName']?.toString() ?? ''),
      coverImg: json['coverImg']?.toString() ?? (json['coverUrl']?.toString() ?? (json['thumbnailUrl']?.toString() ?? '')),
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? ((json['rating'] as num?)?.toDouble() ?? 5.0),
      viewedAt: json['viewedAt']?.toString() ?? (json['visitedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'placeName': placeName,
      'province': province,
      'category': category,
      'coverImg': coverImg,
      'avgRating': avgRating,
      'viewedAt': viewedAt,
    };
  }
}

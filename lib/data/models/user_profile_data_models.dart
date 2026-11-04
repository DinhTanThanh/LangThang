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
  final String? note;
  final int? rating;
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
    this.note,
    this.rating,
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
      note: json['note']?.toString(),
      rating: json['rating'] is num ? (json['rating'] as num).toInt() : int.tryParse(json['rating']?.toString() ?? ''),
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
    String? note,
    int? rating,
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
      note: note ?? this.note,
      rating: rating ?? this.rating,
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
      'note': note,
      'rating': rating,
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
  final String? targetType; // 'blog', 'review', 'place'
  final String? targetTitle;
  final String? targetImageUrl;
  final String? targetSummary;

  const UserCommentItemModel({
    required this.id,
    this.reviewId,
    required this.placeId,
    required this.placeName,
    this.placeThumb = '',
    required this.content,
    this.parentAuthor,
    this.createdAt = '',
    this.targetType,
    this.targetTitle,
    this.targetImageUrl,
    this.targetSummary,
  });

  String get displayTitle {
    if (targetTitle != null && targetTitle!.isNotEmpty) return targetTitle!;
    if (placeName.isNotEmpty) return placeName;
    return 'Bài viết / Địa điểm du lịch';
  }

  String get displayImage {
    if (targetImageUrl != null && targetImageUrl!.isNotEmpty) return targetImageUrl!;
    if (placeThumb.isNotEmpty) return placeThumb;
    return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&h=350&fit=crop';
  }

  factory UserCommentItemModel.fromJson(Map<String, dynamic> json) {
    final thumb = json['placeThumb']?.toString() ??
        json['coverImg']?.toString() ??
        json['imageUrl']?.toString() ??
        json['targetImageUrl']?.toString() ??
        '';

    return UserCommentItemModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      reviewId: json['reviewId'] is num ? (json['reviewId'] as num).toInt() : null,
      placeId: json['placeId'] is num ? (json['placeId'] as num).toInt() : int.tryParse(json['placeId']?.toString() ?? '0') ?? 0,
      placeName: json['placeName']?.toString() ?? json['title']?.toString() ?? '',
      placeThumb: thumb,
      content: json['content']?.toString() ?? '',
      parentAuthor: json['parentAuthor']?.toString() ?? json['replyTo']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      targetType: json['targetType']?.toString() ?? (json['reviewId'] != null ? 'review' : 'place'),
      targetTitle: json['targetTitle']?.toString() ?? json['placeName']?.toString(),
      targetImageUrl: thumb,
      targetSummary: json['targetSummary']?.toString() ?? json['reviewContent']?.toString(),
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
  final int? categoryId;
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
    this.categoryId,
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
      categoryId: json['categoryId'] is num ? (json['categoryId'] as num).toInt() : int.tryParse(json['categoryId']?.toString() ?? ''),
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
  final double? latitude;
  final double? longitude;
  final double minPrice;
  final double maxPrice;
  final String openingHours;
  final String priceRange;
  final String description;
  final String coverImg;
  final List<String> mediaUrls;
  final int status; // 0: Đang chờ duyệt, 1: Đã chấp thuận, 2: Bị từ chối, 3: Cần bổ sung
  final String? rejectReason;
  final String? adminNote;
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
    this.latitude,
    this.longitude,
    this.minPrice = 0,
    this.maxPrice = 0,
    this.openingHours = '07:30 – 18:00',
    this.priceRange = 'Miễn phí',
    this.description = '',
    this.coverImg = '',
    this.mediaUrls = const [],
    this.status = 0,
    this.rejectReason,
    this.adminNote,
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
    final minP = (json['minPrice'] is num) ? (json['minPrice'] as num).toDouble() : (double.tryParse(json['minPrice']?.toString() ?? '') ?? 0.0);
    final maxP = (json['maxPrice'] is num) ? (json['maxPrice'] as num).toDouble() : (double.tryParse(json['maxPrice']?.toString() ?? '') ?? 0.0);

    return ProposalItemModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Khám phá',
      province: json['province']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      latitude: json['latitude'] is num ? (json['latitude'] as num).toDouble() : double.tryParse(json['latitude']?.toString() ?? (json['lat']?.toString() ?? '')),
      longitude: json['longitude'] is num ? (json['longitude'] as num).toDouble() : double.tryParse(json['longitude']?.toString() ?? (json['lng']?.toString() ?? '')),
      minPrice: minP,
      maxPrice: maxP,
      openingHours: json['openingHours']?.toString() ?? '07:30 – 18:00',
      priceRange: (minP > 0 || maxP > 0) ? '${minP.toInt()} - ${maxP.toInt()} VNĐ' : (json['priceRange']?.toString() ?? 'Miễn phí'),
      description: json['description']?.toString() ?? '',
      coverImg: cover,
      mediaUrls: mediaList.isNotEmpty ? mediaList : (cover.isNotEmpty ? [cover] : []),
      status: json['status'] is num ? (json['status'] as num).toInt() : int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      rejectReason: json['rejectReason']?.toString(),
      adminNote: json['adminNote']?.toString() ?? json['note']?.toString(),
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
      'latitude': latitude,
      'longitude': longitude,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'openingHours': openingHours,
      'priceRange': priceRange,
      'description': description,
      'coverImg': coverImg,
      'mediaUrls': mediaUrls,
      'status': status,
      'rejectReason': rejectReason,
      'adminNote': adminNote,
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

/// Mô hình dữ liệu cho Hồ sơ người dùng công khai (Public User Profile - Matching Share_Locations)
class PublicUserProfileModel {
  final int id;
  final String fullName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final String? joinedDate;
  final String rankLevel;
  final int reputationScore;
  final bool isCurrentUser;
  final String friendStatus; // 'none', 'pending_sent', 'pending_received', 'accepted'
  final int reviewCount;
  final int visitLogCount;
  final int tripCount;
  final int blogCount;
  final int proposalCount;

  const PublicUserProfileModel({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.joinedDate,
    this.rankLevel = 'Chuyên gia khám phá',
    this.reputationScore = 1250,
    this.isCurrentUser = false,
    this.friendStatus = 'none',
    this.reviewCount = 0,
    this.visitLogCount = 0,
    this.tripCount = 0,
    this.blogCount = 0,
    this.proposalCount = 0,
  });

  factory PublicUserProfileModel.fromJson(Map<String, dynamic> json) {
    return PublicUserProfileModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '1') ?? 1,
      fullName: json['fullName']?.toString() ?? (json['name']?.toString() ?? 'Người dùng'),
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar']?.toString(),
      coverUrl: json['coverUrl']?.toString() ?? json['coverImg']?.toString(),
      bio: json['bio']?.toString() ?? 'Đam mê khám phá các cung đường và địa điểm mới trên khắp Việt Nam.',
      joinedDate: json['joinedDate']?.toString() ?? 'Tháng 4, 2024',
      rankLevel: json['rankLevel']?.toString() ?? 'Chuyên gia khám phá',
      reputationScore: (json['reputationScore'] as num?)?.toInt() ?? 1250,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
      friendStatus: json['friendStatus']?.toString() ?? 'none',
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      visitLogCount: (json['visitLogCount'] as num?)?.toInt() ?? 0,
      tripCount: (json['tripCount'] as num?)?.toInt() ?? 0,
      blogCount: (json['blogCount'] as num?)?.toInt() ?? 0,
      proposalCount: (json['proposalCount'] as num?)?.toInt() ?? 0,
    );
  }

  PublicUserProfileModel copyWith({
    int? id,
    String? fullName,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    String? joinedDate,
    String? rankLevel,
    int? reputationScore,
    bool? isCurrentUser,
    String? friendStatus,
    int? reviewCount,
    int? visitLogCount,
    int? tripCount,
    int? blogCount,
    int? proposalCount,
  }) {
    return PublicUserProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      joinedDate: joinedDate ?? this.joinedDate,
      rankLevel: rankLevel ?? this.rankLevel,
      reputationScore: reputationScore ?? this.reputationScore,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      friendStatus: friendStatus ?? this.friendStatus,
      reviewCount: reviewCount ?? this.reviewCount,
      visitLogCount: visitLogCount ?? this.visitLogCount,
      tripCount: tripCount ?? this.tripCount,
      blogCount: blogCount ?? this.blogCount,
      proposalCount: proposalCount ?? this.proposalCount,
    );
  }
}

/// Mô hình dữ liệu cho Chuyến đi của người dùng (User Trip)
class UserTripItemModel {
  final int id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final String? province;
  final String? startDate;
  final String? endDate;
  final int durationDays;
  final int nightsCount;
  final double? estimatedBudget;
  final int privacy;
  final int status;
  final int totalStopsCount;
  final String createdAt;

  const UserTripItemModel({
    required this.id,
    required this.title,
    this.description,
    this.coverImageUrl,
    this.province,
    this.startDate,
    this.endDate,
    this.durationDays = 1,
    this.nightsCount = 0,
    this.estimatedBudget,
    this.privacy = 1,
    this.status = 1,
    this.totalStopsCount = 0,
    this.createdAt = '',
  });

  factory UserTripItemModel.fromJson(Map<String, dynamic> json) {
    return UserTripItemModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? 'Chuyến đi',
      description: json['description']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString() ?? json['coverImg']?.toString() ?? json['image']?.toString(),
      province: json['province']?.toString(),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 1,
      nightsCount: (json['nightsCount'] as num?)?.toInt() ?? 0,
      estimatedBudget: (json['estimatedBudget'] as num?)?.toDouble(),
      privacy: (json['privacy'] as num?)?.toInt() ?? 1,
      status: (json['status'] as num?)?.toInt() ?? 1,
      totalStopsCount: (json['totalStopsCount'] as num?)?.toInt() ?? ((json['stopsCount'] as num?)?.toInt() ?? 0),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

/// Mô hình điểm bản đồ dấu chân du lịch (User Travel Map Place - Matching Share_Locations UserMapPlaceDto)
class UserMapPlaceModel {
  final int id;
  final int placeId;
  final String title;
  final String? coverImg;
  final String? category;
  final String? province;
  final double latitude;
  final double longitude;
  final String interactionType; // 'review', 'visit_log', 'proposal'
  final String interactionLabel;
  final double? rating;
  final String? date;

  const UserMapPlaceModel({
    required this.id,
    required this.placeId,
    required this.title,
    this.coverImg,
    this.category,
    this.province,
    required this.latitude,
    required this.longitude,
    required this.interactionType,
    required this.interactionLabel,
    this.rating,
    this.date,
  });

  factory UserMapPlaceModel.fromJson(Map<String, dynamic> json) {
    double lat = 16.0544;
    double lng = 108.2022;

    if (json['coordinates'] is List && (json['coordinates'] as List).isNotEmpty) {
      final list = json['coordinates'] as List;
      if (list.length >= 2) {
        // Backend coordinates are [Lng, Lat]
        final first = (list[0] as num?)?.toDouble() ?? 0.0;
        final second = (list[1] as num?)?.toDouble() ?? 0.0;
        if (first > second && first > 50) {
          lng = first;
          lat = second;
        } else {
          lat = first;
          lng = second;
        }
      }
    } else {
      lat = (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble() ?? 16.0544;
      lng = (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble() ?? 108.2022;
    }

    if (lat > 50 && lng < 50) {
      final temp = lat;
      lat = lng;
      lng = temp;
    }

    // Default coordinates in Vietnam range
    if (lng < 100 || lng > 115 || lat < 8 || lat > 25) {
      lng = 108.2022;
      lat = 16.0544;
    }

    return UserMapPlaceModel(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      placeId: json['placeId'] is num ? (json['placeId'] as num).toInt() : int.tryParse(json['placeId']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? (json['name']?.toString() ?? 'Địa điểm'),
      coverImg: json['coverImg']?.toString() ?? json['image']?.toString() ?? json['coverImageUrl']?.toString(),
      category: json['category']?.toString(),
      province: json['province']?.toString(),
      latitude: lat,
      longitude: lng,
      interactionType: json['interactionType']?.toString() ?? 'review',
      interactionLabel: json['interactionLabel']?.toString() ?? 'Điểm đến',
      rating: (json['rating'] as num?)?.toDouble(),
      date: json['date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'placeId': placeId,
      'title': title,
      'coverImg': coverImg,
      'category': category,
      'province': province,
      'coordinates': [longitude, latitude],
      'interactionType': interactionType,
      'interactionLabel': interactionLabel,
      'rating': rating,
      'date': date,
    };
  }
}




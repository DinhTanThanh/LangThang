class ReviewItemModel {
  final int id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final int rating;
  final String content;
  final List<String> images;
  final List<String> videos;
  final int likesCount;
  final int commentsCount;
  final DateTime? createdAt;
  final String? visitDate;

  const ReviewItemModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.content,
    this.images = const [],
    this.videos = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.createdAt,
    this.visitDate,
  });

  ReviewItemModel copyWith({
    int? id,
    String? userId,
    String? userName,
    String? userAvatar,
    int? rating,
    String? content,
    List<String>? images,
    List<String>? videos,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    String? visitDate,
  }) {
    return ReviewItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      rating: rating ?? this.rating,
      content: content ?? this.content,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      visitDate: visitDate ?? this.visitDate,
    );
  }

  factory ReviewItemModel.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'] as List<dynamic>? ?? [];
    final imagesList = rawImages
        .map((e) => e.toString())
        .where((url) => url.trim().isNotEmpty)
        .toList();

    final rawVideos = json['videos'] as List<dynamic>? ?? [];
    final videosList = rawVideos
        .map((e) => e.toString())
        .where((url) => url.trim().isNotEmpty)
        .toList();

    return ReviewItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Người dùng LangThang',
      userAvatar: json['userAvatar']?.toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      content: json['content']?.toString() ?? '',
      images: imagesList,
      videos: videosList,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      visitDate: json['visitDate']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'rating': rating,
      'content': content,
      'images': images,
      'videos': videos,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'createdAt': createdAt?.toIso8601String(),
      'visitDate': visitDate,
    };
  }

  String get userInitials {
    final name = userName.trim();
    if (name.isEmpty) return 'LT';
    final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'LT';
    if (parts.length == 1) {
      final w = parts[0];
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get timeAgo {
    if (createdAt == null) return 'Gần đây';
    final now = DateTime.now();
    final diff = now.difference(createdAt!);
    if (diff.isNegative || diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} tuần trước';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} tháng trước';
    return '${createdAt!.day.toString().padLeft(2, '0')}/${createdAt!.month.toString().padLeft(2, '0')}/${createdAt!.year}';
  }
}

class ReviewCommentModel {
  final int id;
  final int reviewId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final int? parentId;
  final DateTime? createdAt;
  final List<ReviewCommentModel> replies;

  const ReviewCommentModel({
    required this.id,
    required this.reviewId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.parentId,
    this.createdAt,
    this.replies = const [],
  });

  ReviewCommentModel copyWith({
    int? id,
    int? reviewId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? content,
    int? parentId,
    DateTime? createdAt,
    List<ReviewCommentModel>? replies,
  }) {
    return ReviewCommentModel(
      id: id ?? this.id,
      reviewId: reviewId ?? this.reviewId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      replies: replies ?? this.replies,
    );
  }

  factory ReviewCommentModel.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'] as List<dynamic>? ?? [];
    final repliesList = rawReplies
        .map((e) => ReviewCommentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ReviewCommentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reviewId: (json['reviewId'] as num?)?.toInt() ?? 0,
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Người dùng LangThang',
      userAvatar: json['userAvatar']?.toString(),
      content: json['content']?.toString() ?? '',
      parentId: (json['parentId'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      replies: repliesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reviewId': reviewId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'parentId': parentId,
      'createdAt': createdAt?.toIso8601String(),
      'replies': replies.map((r) => r.toJson()).toList(),
    };
  }

  String get userInitials {
    final name = userName.trim();
    if (name.isEmpty) return 'U';
    final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final w = parts[0];
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get timeAgo {
    if (createdAt == null) return 'Vừa xong';
    final now = DateTime.now();
    final diff = now.difference(createdAt!);
    if (diff.isNegative || diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} tuần trước';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} tháng trước';
    return '${createdAt!.day.toString().padLeft(2, '0')}/${createdAt!.month.toString().padLeft(2, '0')}/${createdAt!.year}';
  }
}

class ReviewCommentsModel {
  final int totalComments;
  final List<ReviewCommentModel> items;

  const ReviewCommentsModel({
    this.totalComments = 0,
    this.items = const [],
  });

  factory ReviewCommentsModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) => ReviewCommentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ReviewCommentsModel(
      totalComments: (json['totalComments'] as num?)?.toInt() ?? itemsList.length,
      items: itemsList,
    );
  }
}

class PlaceReviewSummaryModel {
  final double avgRating;
  final int totalReviews;
  final Map<String, int> ratingBreakdown;
  final List<ReviewItemModel> items;

  const PlaceReviewSummaryModel({
    this.avgRating = 0.0,
    this.totalReviews = 0,
    this.ratingBreakdown = const {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
    this.items = const [],
  });

  factory PlaceReviewSummaryModel.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['ratingBreakdown'] as Map<String, dynamic>? ?? {};
    final breakdown = <String, int>{
      '5': (breakdownRaw['5'] as num?)?.toInt() ?? 0,
      '4': (breakdownRaw['4'] as num?)?.toInt() ?? 0,
      '3': (breakdownRaw['3'] as num?)?.toInt() ?? 0,
      '2': (breakdownRaw['2'] as num?)?.toInt() ?? 0,
      '1': (breakdownRaw['1'] as num?)?.toInt() ?? 0,
    };

    final itemsRaw = json['items'] as List<dynamic>? ?? [];
    final items = itemsRaw
        .map((e) => ReviewItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PlaceReviewSummaryModel(
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? items.length,
      ratingBreakdown: breakdown,
      items: items,
    );
  }

  int getPercentage(int star) {
    if (totalReviews <= 0) return 0;
    final count = ratingBreakdown[star.toString()] ?? 0;
    return ((count / totalReviews) * 100).round();
  }
}

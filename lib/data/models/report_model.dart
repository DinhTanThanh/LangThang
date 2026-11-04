import 'package:flutter/material.dart';

/// Enum representing the target type of a violation report
enum ReportTargetType {
  place,
  review,
  comment,
  blog,
  food,
  photo;

  String get displayName {
    switch (this) {
      case ReportTargetType.place:
        return 'Quán ăn / Địa điểm';
      case ReportTargetType.review:
        return 'Thẻ đánh giá';
      case ReportTargetType.comment:
        return 'Bình luận';
      case ReportTargetType.blog:
        return 'Bài viết cẩm nang';
      case ReportTargetType.food:
        return 'Món ăn đặc sản';
      case ReportTargetType.photo:
        return 'Hình ảnh';
    }
  }

  String get apiTargetType {
    switch (this) {
      case ReportTargetType.place:
        return 'Place';
      case ReportTargetType.review:
        return 'Review';
      case ReportTargetType.comment:
        return 'Comment';
      case ReportTargetType.blog:
        return 'Blog';
      case ReportTargetType.food:
        return 'Food';
      case ReportTargetType.photo:
        return 'Place';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportTargetType.place:
        return Icons.location_on_rounded;
      case ReportTargetType.review:
        return Icons.rate_review_rounded;
      case ReportTargetType.comment:
        return Icons.chat_bubble_rounded;
      case ReportTargetType.blog:
        return Icons.article_rounded;
      case ReportTargetType.food:
        return Icons.restaurant_rounded;
      case ReportTargetType.photo:
        return Icons.image_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ReportTargetType.place:
        return const Color(0xFF059669);
      case ReportTargetType.review:
        return const Color(0xFFD97706);
      case ReportTargetType.comment:
        return const Color(0xFF2563EB);
      case ReportTargetType.blog:
        return const Color(0xFF7C3AED);
      case ReportTargetType.food:
        return const Color(0xFFDC2626);
      case ReportTargetType.photo:
        return const Color(0xFF0D9488);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ReportTargetType.place:
        return const Color(0xFFECFDF5);
      case ReportTargetType.review:
        return const Color(0xFFFFFBEB);
      case ReportTargetType.comment:
        return const Color(0xFFEFF6FF);
      case ReportTargetType.blog:
        return const Color(0xFFF5F3FF);
      case ReportTargetType.food:
        return const Color(0xFFFEF2F2);
      case ReportTargetType.photo:
        return const Color(0xFFF0FDFA);
    }
  }
}

/// Model describing the subject/target being reported
class ReportTargetInfo {
  final ReportTargetType targetType;
  final int targetId;
  final String targetTitle;
  final String? targetSubtitle;
  final String? targetContent;
  final double? targetRating;

  const ReportTargetInfo({
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    this.targetSubtitle,
    this.targetContent,
    this.targetRating,
  });

  factory ReportTargetInfo.forPlace({
    required int id,
    required String name,
    String? address,
    double? rating,
  }) {
    return ReportTargetInfo(
      targetType: ReportTargetType.place,
      targetId: id,
      targetTitle: name,
      targetSubtitle: address ?? 'Cơ sở ẩm thực & du lịch',
      targetRating: rating,
    );
  }

  factory ReportTargetInfo.forReview({
    required int id,
    required String userName,
    required String reviewContent,
    double? rating,
  }) {
    return ReportTargetInfo(
      targetType: ReportTargetType.review,
      targetId: id,
      targetTitle: 'Đánh giá của $userName',
      targetSubtitle: 'Thẻ đánh giá người dùng',
      targetContent: reviewContent,
      targetRating: rating,
    );
  }

  factory ReportTargetInfo.forComment({
    required int id,
    required String userName,
    required String commentContent,
  }) {
    return ReportTargetInfo(
      targetType: ReportTargetType.comment,
      targetId: id,
      targetTitle: 'Bình luận của $userName',
      targetSubtitle: 'Bình luận trao đổi',
      targetContent: commentContent,
    );
  }

  factory ReportTargetInfo.forBlog({
    required dynamic id,
    required String blogTitle,
    String? authorName,
  }) {
    final int parsedId = id is int ? id : (int.tryParse(id.toString()) ?? id.toString().hashCode.abs());
    return ReportTargetInfo(
      targetType: ReportTargetType.blog,
      targetId: parsedId,
      targetTitle: blogTitle,
      targetSubtitle: authorName != null ? 'Tác giả: $authorName' : 'Bài viết cẩm nang',
    );
  }

  factory ReportTargetInfo.forFood({
    required int id,
    required String foodName,
    String? province,
  }) {
    return ReportTargetInfo(
      targetType: ReportTargetType.food,
      targetId: id,
      targetTitle: foodName,
      targetSubtitle: province ?? 'Món ăn đặc sản địa phương',
    );
  }
}

/// Standardized Violation Reason Model (matching /api/reports/reasons)
class ReportReasonModel {
  final int? id;
  final String code;
  final String name;
  final String? description;
  final String? targetType;

  const ReportReasonModel({
    this.id,
    required this.code,
    required this.name,
    this.description,
    this.targetType,
  });

  factory ReportReasonModel.fromJson(Map<String, dynamic> json) {
    return ReportReasonModel(
      id: (json['id'] as num?)?.toInt(),
      code: json['code']?.toString() ?? json['id']?.toString() ?? '',
      name: json['title']?.toString() ?? json['name']?.toString() ?? json['label']?.toString() ?? '',
      description: json['description']?.toString(),
      targetType: json['targetType']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
    'targetType': targetType,
  };
}

/// User's Submitted Report Record (for History view)
class SubmittedUserReport {
  final int id;
  final ReportTargetType targetType;
  final String targetTitle;
  final String reasonContent;
  final String description;
  final String submittedAt;
  final String status; // 'pending' | 'resolved' | 'dismissed'
  final String? resolutionNote;
  final String? evidenceUrl;

  const SubmittedUserReport({
    required this.id,
    required this.targetType,
    required this.targetTitle,
    required this.reasonContent,
    required this.description,
    required this.submittedAt,
    this.status = 'pending',
    this.resolutionNote,
    this.evidenceUrl,
  });

  factory SubmittedUserReport.fromJson(Map<String, dynamic> json) {
    ReportTargetType type = ReportTargetType.place;
    final typeStr = (json['targetType']?.toString() ?? '').toLowerCase();
    if (typeStr.contains('review')) {
      type = ReportTargetType.review;
    } else if (typeStr.contains('comment')) {
      type = ReportTargetType.comment;
    } else if (typeStr.contains('blog')) {
      type = ReportTargetType.blog;
    } else if (typeStr.contains('food')) {
      type = ReportTargetType.food;
    }

    String statusStr = 'pending';
    final rawStatus = json['status'];
    if (rawStatus == 1 || rawStatus == 'resolved' || rawStatus == 'Approved') {
      statusStr = 'resolved';
    } else if (rawStatus == 2 || rawStatus == 'dismissed' || rawStatus == 'Rejected') {
      statusStr = 'dismissed';
    }

    return SubmittedUserReport(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch,
      targetType: type,
      targetTitle: json['targetTitle']?.toString() ?? json['targetName']?.toString() ?? 'Nội dung phản ánh',
      reasonContent: json['reasonContent']?.toString() ?? json['reason']?.toString() ?? 'Vi phạm quy định',
      description: json['description']?.toString() ?? json['notes']?.toString() ?? '',
      submittedAt: json['submittedAt']?.toString() ?? json['createdAt']?.toString() ?? 'Vừa xong',
      status: statusStr,
      resolutionNote: json['resolutionNote']?.toString() ?? json['adminNotes']?.toString(),
      evidenceUrl: json['evidenceUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'targetType': targetType.name,
    'targetTitle': targetTitle,
    'reasonContent': reasonContent,
    'description': description,
    'submittedAt': submittedAt,
    'status': status,
    'resolutionNote': resolutionNote,
    'evidenceUrl': evidenceUrl,
  };
}

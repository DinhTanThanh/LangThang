import 'package:flutter/material.dart';

class NotificationTypeMeta {
  final IconData icon;
  final Color color;
  final Color bg;
  final Color border;
  final String label;

  const NotificationTypeMeta({
    required this.icon,
    required this.color,
    required this.bg,
    required this.border,
    required this.label,
  });
}

class NotificationItem {
  final int id;
  final int userId;
  final int? actorUserId;
  final String? actorName;
  final String? actorAvatarUrl;
  final String title;
  final String content;
  final int type;
  final String? typeName;
  final int priority;
  final String? groupKey;
  final String? deduplicationKey;
  final String? entityType;
  final int? entityId;
  final int? referenceId;
  final String? targetUrl;
  final bool isRead;
  final DateTime? readAt;
  final String? dataJSON;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    this.actorUserId,
    this.actorName,
    this.actorAvatarUrl,
    required this.title,
    required this.content,
    required this.type,
    this.typeName,
    this.priority = 2,
    this.groupKey,
    this.deduplicationKey,
    this.entityType,
    this.entityId,
    this.referenceId,
    this.targetUrl,
    required this.isRead,
    this.readAt,
    this.dataJSON,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, [int fallback = 0]) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? fallback;
    }

    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    DateTime? parseNullableDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return NotificationItem(
      id: parseInt(json['id']),
      userId: parseInt(json['userId']),
      actorUserId: parseNullableInt(json['actorUserId']),
      actorName: json['actorName']?.toString(),
      actorAvatarUrl: json['actorAvatarUrl']?.toString(),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: parseInt(json['type'], 1),
      typeName: json['typeName']?.toString(),
      priority: parseInt(json['priority'], 2),
      groupKey: json['groupKey']?.toString(),
      deduplicationKey: json['deduplicationKey']?.toString(),
      entityType: json['entityType']?.toString(),
      entityId: parseNullableInt(json['entityId']),
      referenceId: parseNullableInt(json['referenceId']),
      targetUrl: json['targetUrl']?.toString(),
      isRead: json['isRead'] == true || json['isRead'] == 1 || json['isRead'] == 'true',
      readAt: parseNullableDateTime(json['readAt']),
      dataJSON: json['dataJSON']?.toString(),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  NotificationItem copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationItem(
      id: id,
      userId: userId,
      actorUserId: actorUserId,
      actorName: actorName,
      actorAvatarUrl: actorAvatarUrl,
      title: title,
      content: content,
      type: type,
      typeName: typeName,
      priority: priority,
      groupKey: groupKey,
      deduplicationKey: deduplicationKey,
      entityType: entityType,
      entityId: entityId,
      referenceId: referenceId,
      targetUrl: targetUrl,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      dataJSON: dataJSON,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  NotificationTypeMeta get typeMeta {
    switch (type) {
      case 1:
        return const NotificationTypeMeta(
          icon: Icons.info_outline_rounded,
          color: Color(0xFF2563EB),
          bg: Color(0xFFDBEAFE),
          border: Color(0xFFBFDBFE),
          label: 'Hệ thống',
        );
      case 2:
        return const NotificationTypeMeta(
          icon: Icons.people_outline_rounded,
          color: Color(0xFF4F46E5),
          bg: Color(0xFFE0E7FF),
          border: Color(0xFFC7D2FE),
          label: 'Tương tác',
        );
      case 3:
        return const NotificationTypeMeta(
          icon: Icons.chat_bubble_outline_rounded,
          color: Color(0xFFD97706),
          bg: Color(0xFFFEF3C7),
          border: Color(0xFFFDE68A),
          label: 'Đánh giá',
        );
      case 4:
        return const NotificationTypeMeta(
          icon: Icons.explore_outlined,
          color: Color(0xFF059669),
          bg: Color(0xFFD1FAE5),
          border: Color(0xFFA7F3D0),
          label: 'Chuyến đi',
        );
      case 5:
        return const NotificationTypeMeta(
          icon: Icons.check_circle_outline_rounded,
          color: Color(0xFF9333EA),
          bg: Color(0xFFF3E8FF),
          border: Color(0xFFE9D5FF),
          label: 'Đề xuất',
        );
      case 6:
        return const NotificationTypeMeta(
          icon: Icons.shield_outlined,
          color: Color(0xFFE11D48),
          bg: Color(0xFFFFE4E6),
          border: Color(0xFFFECDD3),
          label: 'Kiểm duyệt',
        );
      default:
        return const NotificationTypeMeta(
          icon: Icons.notifications_none_rounded,
          color: Color(0xFF475569),
          bg: Color(0xFFF1F5F9),
          border: Color(0xFFE2E8F0),
          label: 'Thông báo',
        );
    }
  }

  String get timeAgoFormatted {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    final diffMins = diff.inMinutes;
    final diffHours = diff.inHours;
    final diffDays = diff.inDays;

    if (diffMins < 1) return 'Vừa xong';
    if (diffMins < 60) return '$diffMins phút trước';
    if (diffHours < 24) return '$diffHours giờ trước';
    if (diffDays == 1) return 'Hôm qua';
    if (diffDays < 7) return '$diffDays ngày trước';
    final d = createdAt.day.toString().padLeft(2, '0');
    final m = createdAt.month.toString().padLeft(2, '0');
    return '$d/$m/${createdAt.year}';
  }
}

class NotificationPagedResult {
  final List<NotificationItem> items;
  final int totalCount;
  final int unreadCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNextPage;

  const NotificationPagedResult({
    required this.items,
    required this.totalCount,
    required this.unreadCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNextPage,
  });

  factory NotificationPagedResult.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, [int fallback = 0]) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? fallback;
    }

    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return NotificationPagedResult(
      items: items,
      totalCount: parseInt(json['totalCount']),
      unreadCount: parseInt(json['unreadCount']),
      page: parseInt(json['page'], 1),
      pageSize: parseInt(json['pageSize'], 20),
      totalPages: parseInt(json['totalPages'], 1),
      hasNextPage: json['hasNextPage'] == true || json['hasNextPage'] == 'true',
    );
  }

  factory NotificationPagedResult.empty() {
    return const NotificationPagedResult(
      items: [],
      totalCount: 0,
      unreadCount: 0,
      page: 1,
      pageSize: 20,
      totalPages: 0,
      hasNextPage: false,
    );
  }
}

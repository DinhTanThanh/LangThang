import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/constants/api_constants.dart';

class UserModel {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String phone;
  final String address;
  final String jobTitle;
  final String bio;
  final String avatarUrl;
  final String coverUrl;
  final String joinDate;
  final int reviewsCount;
  final int blogsCount;
  final int itinerariesCount;
  final int savedCount;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.phone = '',
    this.address = '',
    this.jobTitle = '',
    this.bio = '',
    required this.avatarUrl,
    required this.coverUrl,
    this.joinDate = 'Tháng 01, 2026',
    this.reviewsCount = 18,
    this.blogsCount = 5,
    this.itinerariesCount = 3,
    this.savedCount = 24,
  });

  UserModel copyWith({
    String? fullName,
    String? username,
    String? email,
    String? phone,
    String? address,
    String? jobTitle,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      jobTitle: jobTitle ?? this.jobTitle,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      joinDate: joinDate,
      reviewsCount: reviewsCount,
      blogsCount: blogsCount,
      itinerariesCount: itinerariesCount,
      savedCount: savedCount,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role'] ?? json['Role'];
    String roleName = 'Thành viên';
    if (rawRole != null) {
      if (rawRole == 3 || rawRole == 'SystemAdmin') {
        roleName = 'Quản trị viên';
      } else if (rawRole == 2 || rawRole == 'CategoryAdmin') {
        roleName = 'Quản trị viên danh mục';
      } else if (rawRole == 1 || rawRole == 'User') {
        roleName = 'Thành viên';
      } else {
        roleName = rawRole.toString();
      }
    }

    final emailStr = (json['email'] ?? json['Email'])?.toString() ?? '';
    final usernameStr = (json['username'] ?? json['Username'])?.toString() ?? (emailStr.isNotEmpty ? emailStr.split('@').first : 'User');
    final fullNameStr = (json['fullName'] ?? json['FullName'] ?? json['full_name'] ?? json['name'] ?? json['Name'])?.toString() ?? '';

    final rawAvatar = json['avatarUrl'] ?? json['AvatarUrl'] ?? json['avatar_url'] ?? json['avatar'] ?? json['photoUrl'] ?? json['PhotoUrl'];
    final rawCover = json['coverUrl'] ?? json['CoverUrl'] ?? json['cover_url'] ?? json['cover'] ?? json['bannerUrl'] ?? json['BannerUrl'];

    return UserModel(
      id: (json['id'] ?? json['Id']) != null ? (json['id'] ?? json['Id']).toString() : '0',
      fullName: fullNameStr,
      username: usernameStr,
      email: emailStr,
      phone: (json['phone'] ?? json['Phone'] ?? json['phoneNumber'] ?? json['PhoneNumber'])?.toString() ?? '',
      address: (json['address'] ?? json['Address'])?.toString() ?? '',
      jobTitle: (json['jobTitle'] ?? json['JobTitle'])?.toString() ?? roleName,
      bio: (json['bio'] ?? json['Bio'] ?? json['rankLevel'] ?? json['RankLevel'])?.toString() ?? '',
      avatarUrl: _formatImageUrl(
        rawAvatar,
        fallback: 'https://i.pravatar.cc/300?img=47',
      ),
      coverUrl: _formatImageUrl(
        rawCover,
        fallback: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1200&auto=format&fit=crop',
      ),
      joinDate: (json['joinDate'] ?? json['JoinDate'])?.toString() ?? 'Tháng 01, 2026',
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? ((json['ReviewsCount'] as num?)?.toInt() ?? ((json['reputationScore'] as num?)?.toInt() ?? 18)),
      blogsCount: (json['blogsCount'] as num?)?.toInt() ?? ((json['BlogsCount'] as num?)?.toInt() ?? 5),
      itinerariesCount: (json['itinerariesCount'] as num?)?.toInt() ?? ((json['ItinerariesCount'] as num?)?.toInt() ?? 3),
      savedCount: (json['savedCount'] as num?)?.toInt() ?? ((json['SavedCount'] as num?)?.toInt() ?? 24),
    );
  }

  static String _formatImageUrl(dynamic rawUrl, {required String fallback}) {
    if (rawUrl == null) return fallback;
    var trimmed = rawUrl.toString().trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
      return fallback;
    }

    if (trimmed.contains('default-avatar.webp') && trimmed.contains('blob.core.windows.net')) {
      return fallback;
    }

    if (trimmed.startsWith('data:image/') ||
        trimmed.startsWith('blob:') ||
        trimmed.startsWith('file:') ||
        trimmed.startsWith('assets/')) {
      return trimmed;
    }

    // Rewrite localhost / 127.0.0.1 to ApiConstants.baseUrl host & port
    if (!kIsWeb) {
      try {
        if (trimmed.startsWith('http://localhost:') || trimmed.startsWith('http://127.0.0.1:')) {
          final uri = Uri.parse(trimmed);
          final baseUri = Uri.parse(ApiConstants.baseUrl);
          trimmed = uri.replace(
            scheme: baseUri.scheme,
            host: baseUri.host,
            port: baseUri.port,
          ).toString();
        }
      } catch (_) {}
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${ApiConstants.baseUrl}$trimmed';
    }
    return '${ApiConstants.baseUrl}/$trimmed';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'username': username,
      'email': email,
      'phone': phone,
      'address': address,
      'jobTitle': jobTitle,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'joinDate': joinDate,
      'reviewsCount': reviewsCount,
      'blogsCount': blogsCount,
      'itinerariesCount': itinerariesCount,
      'savedCount': savedCount,
    };
  }
}

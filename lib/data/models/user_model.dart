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
    final rawRole = json['role'];
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

    final emailStr = json['email']?.toString() ?? '';
    final usernameStr = json['username']?.toString() ?? (emailStr.isNotEmpty ? emailStr.split('@').first : 'User');

    return UserModel(
      id: json['id'] != null ? json['id'].toString() : '0',
      fullName: json['fullName']?.toString() ?? '',
      username: usernameStr,
      email: emailStr,
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      jobTitle: json['jobTitle']?.toString() ?? roleName,
      bio: json['bio']?.toString() ?? (json['rankLevel']?.toString() ?? ''),
      avatarUrl: (json['avatarUrl'] != null && json['avatarUrl'].toString().isNotEmpty)
          ? json['avatarUrl'].toString()
          : 'https://i.pravatar.cc/300?img=47',
      coverUrl: (json['coverUrl'] != null && json['coverUrl'].toString().isNotEmpty)
          ? json['coverUrl'].toString()
          : 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1200&auto=format&fit=crop',
      joinDate: json['joinDate']?.toString() ?? 'Tháng 01, 2026',
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? ((json['reputationScore'] as num?)?.toInt() ?? 18),
      blogsCount: (json['blogsCount'] as num?)?.toInt() ?? 5,
      itinerariesCount: (json['itinerariesCount'] as num?)?.toInt() ?? 3,
      savedCount: (json['savedCount'] as num?)?.toInt() ?? 24,
    );
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

enum FriendshipStatus {
  accepted,
  suggestion,
  pendingIncoming,
  pendingOutgoing,
  blocked,
  self;

  String get code {
    switch (this) {
      case FriendshipStatus.accepted:
        return 'accepted';
      case FriendshipStatus.suggestion:
        return 'suggestion';
      case FriendshipStatus.pendingIncoming:
        return 'pending_incoming';
      case FriendshipStatus.pendingOutgoing:
        return 'pending_outgoing';
      case FriendshipStatus.blocked:
        return 'blocked';
      case FriendshipStatus.self:
        return 'self';
    }
  }

  static FriendshipStatus fromCode(String? code) {
    switch (code?.toLowerCase()) {
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'pending_incoming':
      case 'pending_received':
        return FriendshipStatus.pendingIncoming;
      case 'pending_outgoing':
      case 'pending_sent':
        return FriendshipStatus.pendingOutgoing;
      case 'blocked':
        return FriendshipStatus.blocked;
      case 'self':
        return FriendshipStatus.self;
      default:
        return FriendshipStatus.suggestion;
    }
  }
}

class FriendUser {
  final int id;
  final String fullName;
  final String email;
  final String avatarUrl;
  final String coverUrl;
  final String city;
  final String bio;
  final dynamic rankLevel;
  final int reputationScore;
  final int mutualFriendsCount;
  final FriendshipStatus status;
  final String? connectedDate;
  final String? blockedDate;

  const FriendUser({
    required this.id,
    required this.fullName,
    this.email = '',
    this.avatarUrl = '',
    this.coverUrl = '',
    this.city = '',
    this.bio = '',
    this.rankLevel,
    this.reputationScore = 0,
    this.mutualFriendsCount = 0,
    this.status = FriendshipStatus.suggestion,
    this.connectedDate,
    this.blockedDate,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: (json['id'] as num?)?.toInt() ?? (json['userId'] as num?)?.toInt() ?? 0,
      fullName: json['name']?.toString() ?? json['fullName']?.toString() ?? 'Người dùng',
      email: json['email']?.toString() ?? '',
      avatarUrl: json['avatar']?.toString() ?? json['avatarUrl']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      city: json['city']?.toString() ?? json['address']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      rankLevel: json['rankLevel'] ?? json['rank'] ?? 'Thành viên',
      reputationScore: (json['reputationScore'] as num?)?.toInt() ?? 0,
      mutualFriendsCount: (json['mutualFriendsCount'] as num?)?.toInt() ?? 0,
      status: FriendshipStatus.fromCode(json['status']?.toString()),
      connectedDate: json['requestedAt']?.toString() ?? json['connectedDate']?.toString(),
      blockedDate: json['blockedDate']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'city': city,
      'bio': bio,
      'rankLevel': rankLevel,
      'reputationScore': reputationScore,
      'mutualFriendsCount': mutualFriendsCount,
      'status': status.code,
      'connectedDate': connectedDate,
      'blockedDate': blockedDate,
    };
  }

  FriendUser copyWith({
    int? id,
    String? fullName,
    String? email,
    String? avatarUrl,
    String? coverUrl,
    String? city,
    String? bio,
    dynamic rankLevel,
    int? reputationScore,
    int? mutualFriendsCount,
    FriendshipStatus? status,
    String? connectedDate,
    String? blockedDate,
  }) {
    return FriendUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      rankLevel: rankLevel ?? this.rankLevel,
      reputationScore: reputationScore ?? this.reputationScore,
      mutualFriendsCount: mutualFriendsCount ?? this.mutualFriendsCount,
      status: status ?? this.status,
      connectedDate: connectedDate ?? this.connectedDate,
      blockedDate: blockedDate ?? this.blockedDate,
    );
  }
}

class FriendsResponseModel {
  final List<FriendUser> friends;
  final List<FriendUser> pendingRequestsReceived;
  final List<FriendUser> pendingRequestsSent;
  final List<FriendUser> blockedUsers;

  const FriendsResponseModel({
    this.friends = const [],
    this.pendingRequestsReceived = const [],
    this.pendingRequestsSent = const [],
    this.blockedUsers = const [],
  });

  factory FriendsResponseModel.fromJson(Map<String, dynamic> json) {
    List<FriendUser> parseList(dynamic raw, FriendshipStatus defaultStatus) {
      if (raw is List) {
        return raw.map((e) {
          final item = FriendUser.fromJson(e as Map<String, dynamic>);
          return item.status == FriendshipStatus.suggestion ? item.copyWith(status: defaultStatus) : item;
        }).toList();
      }
      return [];
    }

    return FriendsResponseModel(
      friends: parseList(json['friends'], FriendshipStatus.accepted),
      pendingRequestsReceived: parseList(json['pendingRequestsReceived'], FriendshipStatus.pendingIncoming),
      pendingRequestsSent: parseList(json['pendingRequestsSent'], FriendshipStatus.pendingOutgoing),
      blockedUsers: parseList(json['blockedUsers'], FriendshipStatus.blocked),
    );
  }
}

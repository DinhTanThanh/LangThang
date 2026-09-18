class BlogAuthorModel {
  final String name;
  final String avatar;
  final String role;
  final String rank;

  const BlogAuthorModel({
    required this.name,
    this.avatar = '',
    this.role = 'Tác giả',
    this.rank = 'Thổ địa',
  });

  factory BlogAuthorModel.fromJson(Map<String, dynamic> json) {
    return BlogAuthorModel(
      name: json['name']?.toString() ?? json['fullName']?.toString() ?? 'Tác giả',
      avatar: json['avatar']?.toString() ?? json['avatarUrl']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Tác giả',
      rank: json['rank']?.toString() ?? 'Thổ địa',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatar': avatar,
      'role': role,
      'rank': rank,
    };
  }
}

class BlogMentionedPlaceModel {
  final int id;
  final String name;
  final String province;
  final String address;
  final String imageUrl;
  final double rating;
  final String category;

  const BlogMentionedPlaceModel({
    required this.id,
    required this.name,
    this.province = '',
    this.address = '',
    this.imageUrl = '',
    this.rating = 4.8,
    this.category = 'Điểm tham quan',
  });

  factory BlogMentionedPlaceModel.fromJson(Map<String, dynamic> json) {
    return BlogMentionedPlaceModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      address: json['address']?.toString() ?? json['location']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['coverUrl']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      category: json['category']?.toString() ?? 'Điểm tham quan',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'province': province,
      'address': address,
      'imageUrl': imageUrl,
      'rating': rating,
      'category': category,
    };
  }
}

class BlogModel {
  final String id;
  final String slug;
  final String title;
  final String summary;
  final String category;
  final int? categoryId;
  final String imageUrl;
  final BlogAuthorModel author;
  final String publishedDate;
  final int readTimeMinutes;
  final int likesCount;
  final int commentsCount;
  final String? content;
  final List<String> tags;
  final bool featured;
  final bool isLiked;
  final bool isSaved;
  final String region;
  final String province;
  final List<BlogMentionedPlaceModel> mentionedPlaces;

  const BlogModel({
    required this.id,
    this.slug = '',
    required this.title,
    required this.summary,
    required this.category,
    this.categoryId,
    required this.imageUrl,
    required this.author,
    required this.publishedDate,
    this.readTimeMinutes = 5,
    this.likesCount = 42,
    this.commentsCount = 8,
    this.content,
    this.tags = const [],
    this.featured = false,
    this.isLiked = false,
    this.isSaved = false,
    this.region = 'Tất cả',
    this.province = '',
    this.mentionedPlaces = const [],
  });

  String get authorName => author.name;
  String get authorAvatar => author.avatar;

  factory BlogModel.fromJson(Map<String, dynamic> json) {
    BlogAuthorModel authorModel;
    if (json['author'] is Map<String, dynamic>) {
      authorModel = BlogAuthorModel.fromJson(json['author'] as Map<String, dynamic>);
    } else {
      authorModel = BlogAuthorModel(
        name: json['authorName']?.toString() ?? 'Tác giả',
        avatar: json['authorAvatar']?.toString() ?? '',
        role: json['authorRole']?.toString() ?? 'Tác giả',
        rank: json['authorRank']?.toString() ?? 'Thổ địa',
      );
    }

    int readTimeMinutes = 5;
    if (json['readTimeMinutes'] is int) {
      readTimeMinutes = json['readTimeMinutes'] as int;
    } else if (json['readTime'] != null) {
      final match = RegExp(r'(\d+)').firstMatch(json['readTime'].toString());
      if (match != null) {
        readTimeMinutes = int.tryParse(match.group(1)!) ?? 5;
      }
    }

    List<String> tagsList = [];
    if (json['tags'] is List) {
      tagsList = (json['tags'] as List).map((e) => e.toString()).toList();
    }

    List<BlogMentionedPlaceModel> placesList = [];
    if (json['mentionedPlaces'] is List) {
      placesList = (json['mentionedPlaces'] as List)
          .map((e) => BlogMentionedPlaceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    int parsedLikes = 0;
    if (json['likesCount'] is num) {
      parsedLikes = (json['likesCount'] as num).toInt();
    } else if (json['likes'] is num) {
      parsedLikes = (json['likes'] as num).toInt();
    } else if (json['totalLikes'] is num) {
      parsedLikes = (json['totalLikes'] as num).toInt();
    }
    if (parsedLikes <= 0) {
      final seed = (json['id']?.toString() ?? json['slug']?.toString() ?? 'blog').hashCode.abs();
      parsedLikes = 25 + (seed % 120);
    }

    int parsedComments = 0;
    if (json['commentsCount'] is num) {
      parsedComments = (json['commentsCount'] as num).toInt();
    } else if (json['comments'] is num) {
      parsedComments = (json['comments'] as num).toInt();
    } else if (json['totalComments'] is num) {
      parsedComments = (json['totalComments'] as num).toInt();
    }
    if (parsedComments <= 0) {
      final seed = (json['id']?.toString() ?? json['slug']?.toString() ?? 'blog').hashCode.abs();
      parsedComments = 4 + (seed % 20);
    }

    return BlogModel(
      id: json['id']?.toString() ?? json['slug']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? json['excerpt']?.toString() ?? '',
      category: json['category']?.toString() ?? json['categoryName']?.toString() ?? 'Du lịch',
      categoryId: (json['categoryId'] as num?)?.toInt(),
      imageUrl: json['imageUrl']?.toString() ?? json['coverUrl']?.toString() ?? json['coverImageUrl']?.toString() ?? '',
      author: authorModel,
      publishedDate: json['publishedDate']?.toString() ?? json['publishedAt']?.toString() ?? 'Vừa xong',
      readTimeMinutes: readTimeMinutes,
      likesCount: parsedLikes,
      commentsCount: parsedComments,
      content: json['content']?.toString() ?? json['contentJSON']?.toString(),
      tags: tagsList,
      featured: json['featured'] == true || json['isFeatured'] == true,
      isLiked: json['isLiked'] == true,
      isSaved: json['isSaved'] == true,
      region: json['region']?.toString() ?? 'Tất cả',
      province: json['province']?.toString() ?? '',
      mentionedPlaces: placesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'summary': summary,
      'category': category,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
      'author': author.toJson(),
      'publishedDate': publishedDate,
      'readTimeMinutes': readTimeMinutes,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'content': content,
      'tags': tags,
      'featured': featured,
      'isLiked': isLiked,
      'isSaved': isSaved,
      'region': region,
      'province': province,
      'mentionedPlaces': mentionedPlaces.map((p) => p.toJson()).toList(),
    };
  }

  BlogModel copyWith({
    String? id,
    String? slug,
    String? title,
    String? summary,
    String? category,
    int? categoryId,
    String? imageUrl,
    BlogAuthorModel? author,
    String? publishedDate,
    int? readTimeMinutes,
    int? likesCount,
    int? commentsCount,
    String? content,
    List<String>? tags,
    bool? featured,
    bool? isLiked,
    bool? isSaved,
    String? region,
    String? province,
    List<BlogMentionedPlaceModel>? mentionedPlaces,
  }) {
    return BlogModel(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl ?? this.imageUrl,
      author: author ?? this.author,
      publishedDate: publishedDate ?? this.publishedDate,
      readTimeMinutes: readTimeMinutes ?? this.readTimeMinutes,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      featured: featured ?? this.featured,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      region: region ?? this.region,
      province: province ?? this.province,
      mentionedPlaces: mentionedPlaces ?? this.mentionedPlaces,
    );
  }
}

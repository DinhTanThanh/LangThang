class BlogModel {
  final String id;
  final String title;
  final String summary;
  final String category;
  final String imageUrl;
  final String authorName;
  final String authorAvatar;
  final String publishedDate;
  final int readTimeMinutes;
  final int likesCount;
  final int commentsCount;
  final String? content;

  const BlogModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.imageUrl,
    required this.authorName,
    required this.authorAvatar,
    required this.publishedDate,
    this.readTimeMinutes = 5,
    this.likesCount = 42,
    this.commentsCount = 8,
    this.content,
  });

  factory BlogModel.fromJson(Map<String, dynamic> json) {
    String authorName = 'Tác giả';
    String authorAvatar = '';
    if (json['author'] is Map<String, dynamic>) {
      final authorObj = json['author'] as Map<String, dynamic>;
      authorName = authorObj['name']?.toString() ?? 'Tác giả';
      authorAvatar = authorObj['avatar']?.toString() ?? '';
    } else if (json['authorName'] != null) {
      authorName = json['authorName'].toString();
      authorAvatar = json['authorAvatar']?.toString() ?? '';
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

    return BlogModel(
      id: json['id']?.toString() ?? json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? json['excerpt']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Du lịch',
      imageUrl: json['imageUrl']?.toString() ?? json['coverUrl']?.toString() ?? '',
      authorName: authorName,
      authorAvatar: authorAvatar,
      publishedDate: json['publishedDate']?.toString() ?? json['publishedAt']?.toString() ?? '',
      readTimeMinutes: readTimeMinutes,
      likesCount: json['likesCount'] is int ? json['likesCount'] as int : 0,
      commentsCount: json['commentsCount'] is int ? json['commentsCount'] as int : 0,
      content: json['content']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'category': category,
      'imageUrl': imageUrl,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'publishedDate': publishedDate,
      'readTimeMinutes': readTimeMinutes,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'content': content,
    };
  }
}

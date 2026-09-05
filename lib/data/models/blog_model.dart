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
    return BlogModel(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      category: json['category'] as String? ?? 'Du lịch',
      imageUrl: json['imageUrl'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Tác giả',
      authorAvatar: json['authorAvatar'] as String? ?? '',
      publishedDate: json['publishedDate'] as String? ?? '',
      readTimeMinutes: json['readTimeMinutes'] as int? ?? 5,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      content: json['content'] as String?,
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

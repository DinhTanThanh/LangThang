class ItineraryModel {
  final String id;
  final String title;
  final String duration;
  final String category;
  final String description;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final String authorName;
  final String authorAvatar;
  final List<String> highlights;
  final int stopCount;

  const ItineraryModel({
    required this.id,
    required this.title,
    required this.duration,
    required this.category,
    required this.description,
    required this.imageUrl,
    this.rating = 4.9,
    this.reviewCount = 120,
    required this.authorName,
    required this.authorAvatar,
    this.highlights = const [],
    this.stopCount = 8,
  });

  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    return ItineraryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      duration: json['duration'] as String? ?? '3N2Đ',
      category: json['category'] as String? ?? 'Khám phá',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: json['reviewCount'] as int? ?? 0,
      authorName: json['authorName'] as String? ?? 'Lang Thang Member',
      authorAvatar: json['authorAvatar'] as String? ?? '',
      highlights: (json['highlights'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      stopCount: json['stopCount'] as int? ?? 6,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'highlights': highlights,
      'stopCount': stopCount,
    };
  }
}

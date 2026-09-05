class FoodModel {
  final String id;
  final String title;
  final String subtitle;
  final String location;
  final String imageUrl;
  final String priceRange;
  final double rating;
  final int reviewCount;
  final String description;
  final String address;

  const FoodModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.imageUrl,
    this.priceRange = '35.000đ - 75.000đ',
    this.rating = 4.9,
    this.reviewCount = 85,
    this.description = '',
    this.address = '',
  });

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    return FoodModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      location: json['location'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      priceRange: json['priceRange'] as String? ?? '35.000đ - 75.000đ',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      reviewCount: json['reviewCount'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'location': location,
      'imageUrl': imageUrl,
      'priceRange': priceRange,
      'rating': rating,
      'reviewCount': reviewCount,
      'description': description,
      'address': address,
    };
  }
}

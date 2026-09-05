class TourModel {
  final String id;
  final String title;
  final String price;
  final int priceValue;
  final double rating;
  final int reviews;
  final String imageUrl;
  final String badge;
  final String? location;
  final String? description;

  const TourModel({
    required this.id,
    required this.title,
    required this.price,
    required this.priceValue,
    required this.rating,
    required this.reviews,
    required this.imageUrl,
    required this.badge,
    this.location,
    this.description,
  });

  factory TourModel.fromJson(Map<String, dynamic> json) {
    return TourModel(
      id: json['id'] as String,
      title: json['title'] as String,
      price: json['price'] as String,
      priceValue: json['priceValue'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviews: json['reviews'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String,
      badge: json['badge'] as String,
      location: json['location'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'priceValue': priceValue,
      'rating': rating,
      'reviews': reviews,
      'imageUrl': imageUrl,
      'badge': badge,
      'location': location,
      'description': description,
    };
  }
}

class CollectionModel {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String badge;
  final List<TourModel> tours;

  const CollectionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badge,
    required this.tours,
  });
}

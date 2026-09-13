class FoodSuggestedPlace {
  final int? id;
  final String name;
  final String address;
  final double rating;
  final List<double>? coordinates;

  const FoodSuggestedPlace({
    this.id,
    required this.name,
    required this.address,
    this.rating = 5.0,
    this.coordinates,
  });

  factory FoodSuggestedPlace.fromJson(Map<String, dynamic> json) {
    List<double>? parsedCoords;
    if (json['coordinates'] is List) {
      parsedCoords = (json['coordinates'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }
    return FoodSuggestedPlace(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (json['placeId'] is num
              ? (json['placeId'] as num).toInt()
              : int.tryParse(json['id']?.toString() ?? '')),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      coordinates: parsedCoords,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'rating': rating,
      'coordinates': coordinates,
    };
  }
}

class FoodModel {
  final String id;
  final String name;
  final String province;
  final String region; // 'north', 'central', 'south'
  final String description;
  final String imageUrl;
  final List<String> mediaUrls;
  final String type; // 'dine-in', 'street-food', 'gift'
  final String priceRange;
  final double rating;
  final int reviewCount;
  final int suggestedPlacesCount;
  final List<FoodSuggestedPlace> suggestedPlaces;
  final List<double>? coordinates;

  const FoodModel({
    required this.id,
    required this.name,
    this.province = '',
    this.region = 'north',
    this.description = '',
    required this.imageUrl,
    this.mediaUrls = const [],
    this.type = 'dine-in',
    this.priceRange = '40.000đ - 100.000đ',
    this.rating = 5.0,
    this.reviewCount = 85,
    this.suggestedPlacesCount = 0,
    this.suggestedPlaces = const [],
    this.coordinates,
  });

  // Backward compatibility getters
  String get title => name;
  String get subtitle => province.isNotEmpty ? '$province · Đặc sản truyền thống' : 'Đặc sản ẩm thực';
  String get location => province;
  String get address => suggestedPlaces.isNotEmpty ? suggestedPlaces.first.address : '';

  List<String> get allMediaUrls {
    if (mediaUrls.isNotEmpty) return mediaUrls;
    if (imageUrl.isNotEmpty) return [imageUrl];
    return [];
  }

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['mediaUrls'];
    List<String> mediaList = [];
    if (rawMedia is List) {
      mediaList = rawMedia.map((e) => e.toString()).toList();
    } else if (json['imageUrl'] != null && json['imageUrl'].toString().isNotEmpty) {
      mediaList = [json['imageUrl'].toString()];
    }

    final rawPlaces = json['suggestedPlaces'];
    List<FoodSuggestedPlace> placesList = [];
    if (rawPlaces is List) {
      placesList = rawPlaces
          .map((e) => FoodSuggestedPlace.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<double>? parsedCoords;
    if (json['coordinates'] is List) {
      parsedCoords = (json['coordinates'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    return FoodModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? '',
      province: json['province'] as String? ?? json['location'] as String? ?? '',
      region: json['region'] as String? ?? 'north',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? (mediaList.isNotEmpty ? mediaList.first : ''),
      mediaUrls: mediaList,
      type: json['type'] as String? ?? 'dine-in',
      priceRange: json['priceRange'] as String? ?? '40.000đ - 100.000đ',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: json['reviewCount'] as int? ?? (placesList.length * 35),
      suggestedPlacesCount: json['suggestedPlacesCount'] as int? ?? placesList.length,
      suggestedPlaces: placesList,
      coordinates: parsedCoords,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': name,
      'province': province,
      'region': region,
      'description': description,
      'imageUrl': imageUrl,
      'mediaUrls': mediaUrls,
      'type': type,
      'priceRange': priceRange,
      'rating': rating,
      'reviewCount': reviewCount,
      'suggestedPlacesCount': suggestedPlacesCount,
      'suggestedPlaces': suggestedPlaces.map((e) => e.toJson()).toList(),
      'coordinates': coordinates,
    };
  }
}

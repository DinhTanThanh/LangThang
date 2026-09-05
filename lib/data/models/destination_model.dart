enum Region {
  north,
  central,
  south,
}

extension RegionExtension on Region {
  String get displayName {
    switch (this) {
      case Region.north:
        return 'Miền Bắc';
      case Region.central:
        return 'Miền Trung';
      case Region.south:
        return 'Miền Nam';
    }
  }

  String get subTitle {
    switch (this) {
      case Region.north:
        return 'Vùng núi & Đồng bằng';
      case Region.central:
        return 'Di sản & Biển ngọc';
      case Region.south:
        return 'Đô thị & Sông nước';
    }
  }
}

class DestinationModel {
  final String id;
  final String title;
  final String location;
  final String description;
  final String imageUrl;
  final String? badgeText;
  final Region region;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final String? detailedContent;

  const DestinationModel({
    required this.id,
    required this.title,
    required this.location,
    required this.description,
    required this.imageUrl,
    this.badgeText,
    required this.region,
    this.rating = 4.8,
    this.reviewCount = 120,
    this.tags = const [],
    this.detailedContent,
  });

  factory DestinationModel.fromJson(Map<String, dynamic> json) {
    return DestinationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      badgeText: json['badgeText'] as String?,
      region: _parseRegion(json['region'] as String?),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: json['reviewCount'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      detailedContent: json['detailedContent'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'description': description,
      'imageUrl': imageUrl,
      'badgeText': badgeText,
      'region': region.name,
      'rating': rating,
      'reviewCount': reviewCount,
      'tags': tags,
      'detailedContent': detailedContent,
    };
  }

  static Region _parseRegion(String? regionStr) {
    switch (regionStr?.toLowerCase()) {
      case 'north':
      case 'mien_bac':
        return Region.north;
      case 'central':
      case 'mien_trung':
        return Region.central;
      case 'south':
      case 'mien_nam':
      default:
        return Region.south;
    }
  }
}

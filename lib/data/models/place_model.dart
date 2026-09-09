class PlaceAmenityModel {
  final String id;
  final String name;
  final String icon;

  const PlaceAmenityModel({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory PlaceAmenityModel.fromJson(Map<String, dynamic> json) {
    return PlaceAmenityModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
  };
}

class PlaceModel {
  final int id;
  final String name;
  final String category;
  final String location;
  final String region;
  final String province;
  final String type;
  final double rating;
  final int reviews;
  final String price;
  final int priceMax;
  final String priceRange;
  final String hours;
  final String status;
  final String desc;
  final String detailedDescription;
  final String phoneNumber;
  final String website;
  final List<String> highlights;
  final List<PlaceAmenityModel> amenities;
  final List<String> tags;
  final String img;
  final List<String> mediaUrls;
  final bool isSaved;
  final double latitude;
  final double longitude;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.region,
    required this.province,
    required this.type,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.priceMax,
    required this.priceRange,
    required this.hours,
    required this.status,
    required this.desc,
    this.detailedDescription = '',
    this.phoneNumber = '',
    this.website = '',
    this.highlights = const [],
    this.amenities = const [],
    required this.tags,
    required this.img,
    this.mediaUrls = const [],
    this.isSaved = false,
    this.latitude = 21.0285,
    this.longitude = 105.8542,
  });

  PlaceModel copyWith({
    int? id,
    String? name,
    String? category,
    String? location,
    String? region,
    String? province,
    String? type,
    double? rating,
    int? reviews,
    String? price,
    int? priceMax,
    String? priceRange,
    String? hours,
    String? status,
    String? desc,
    String? detailedDescription,
    String? phoneNumber,
    String? website,
    List<String>? highlights,
    List<PlaceAmenityModel>? amenities,
    List<String>? tags,
    String? img,
    List<String>? mediaUrls,
    bool? isSaved,
    double? latitude,
    double? longitude,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      location: location ?? this.location,
      region: region ?? this.region,
      province: province ?? this.province,
      type: type ?? this.type,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      price: price ?? this.price,
      priceMax: priceMax ?? this.priceMax,
      priceRange: priceRange ?? this.priceRange,
      hours: hours ?? this.hours,
      status: status ?? this.status,
      desc: desc ?? this.desc,
      detailedDescription: detailedDescription ?? this.detailedDescription,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      highlights: highlights ?? this.highlights,
      amenities: amenities ?? this.amenities,
      tags: tags ?? this.tags,
      img: img ?? this.img,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      isSaved: isSaved ?? this.isSaved,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    // Determine category
    final category = json['categoryName']?.toString() ??
        json['category']?.toString() ??
        '';

    // Determine location / address
    final location = json['address']?.toString() ??
        json['location']?.toString() ??
        '';

    // Determine region
    final region = json['regionName']?.toString() ??
        json['region']?.toString() ??
        '';

    // Determine province
    final province = json['provinceName']?.toString() ??
        json['province']?.toString() ??
        '';

    // Determine place type
    final type = json['placeTypeName']?.toString() ??
        json['type']?.toString() ??
        '';

    // Ratings & Reviews
    double rating = 0.0;
    if (json['avgRating'] != null) {
      rating = (json['avgRating'] as num).toDouble();
    } else if (json['rating'] != null) {
      rating = (json['rating'] as num).toDouble();
    }

    // Detailed description & contacts
    final detailedDescription = json['detailedDescription']?.toString() ??
        json['detailed_description']?.toString() ??
        '';
    final phoneNumber = json['phoneNumber']?.toString() ??
        json['phone_number']?.toString() ??
        json['phone']?.toString() ??
        '';
    final website = json['website']?.toString() ?? '';

    // Highlights
    List<String> highlights = [];
    if (json['highlights'] != null && json['highlights'] is List) {
      highlights = (json['highlights'] as List).map((e) => e.toString()).toList();
    }

    // Amenities
    List<PlaceAmenityModel> amenities = [];
    if (json['amenities'] != null && json['amenities'] is List) {
      amenities = (json['amenities'] as List)
          .map((e) => e is Map<String, dynamic> ? PlaceAmenityModel.fromJson(e) : PlaceAmenityModel(id: '', name: e.toString(), icon: ''))
          .toList();
    }

    int reviews = 0;
    if (json['reviewCount'] != null) {
      reviews = (json['reviewCount'] as num).toInt();
    } else if (json['reviews'] != null) {
      reviews = (json['reviews'] as num).toInt();
    }

    // Opening hours
    final hours = json['openingHours']?.toString() ??
        json['hours']?.toString() ??
        '08:00 – 17:00';

    // Price calculation
    final minPriceNum = json['minPrice'] as num?;
    final maxPriceNum = json['maxPrice'] as num?;
    String price = json['price']?.toString() ?? '';
    int priceMax = (json['priceMax'] as num?)?.toInt() ?? 0;

    if (price.isEmpty) {
      if (minPriceNum != null && maxPriceNum != null && minPriceNum > 0 && maxPriceNum > 0) {
        price = '${_formatCurrency(minPriceNum.toInt())} – ${_formatCurrency(maxPriceNum.toInt())}';
        priceMax = maxPriceNum.toInt();
      } else if (minPriceNum != null && minPriceNum > 0) {
        price = 'Từ ${_formatCurrency(minPriceNum.toInt())}';
        priceMax = minPriceNum.toInt();
      } else if (maxPriceNum != null && maxPriceNum > 0) {
        price = 'Đến ${_formatCurrency(maxPriceNum.toInt())}';
        priceMax = maxPriceNum.toInt();
      } else {
        price = 'Miễn phí';
        priceMax = 0;
      }
    }

    // Status: backend PlaceStatus (0=Pending, 1=Approved, 2=Rejected, 3=Hidden)
    String status = 'Đang hoạt động';
    if (json['status'] != null) {
      final s = json['status'];
      if (s == 1 || s == '1' || s == 'Approved' || s == 'Đang hoạt động' || s == 'Đang mở') {
        status = 'Đang hoạt động';
      } else {
        status = 'Tạm đóng';
      }
    }

    // Description
    final desc = json['description']?.toString() ?? json['desc']?.toString() ?? '';

    // Tags
    List<String> tags = [];
    if (json['tags'] != null && json['tags'] is List) {
      tags = (json['tags'] as List).map((e) => e.toString()).toList();
    } else {
      tags = [category, type, province, region].where((s) => s.isNotEmpty).toSet().toList();
    }

    // Media URLs / Gallery Images
    List<String> mediaUrls = [];
    if (json['mediaUrls'] != null && json['mediaUrls'] is List) {
      mediaUrls = (json['mediaUrls'] as List).map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    } else if (json['media_urls'] != null && json['media_urls'] is List) {
      mediaUrls = (json['media_urls'] as List).map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    } else if (json['images'] != null && json['images'] is List) {
      mediaUrls = (json['images'] as List).map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    }

    // Thumbnail Image
    String img = json['thumbnailUrl']?.toString() ??
        json['coverImageUrl']?.toString() ??
        json['img']?.toString() ??
        '';

    if (img.isEmpty && mediaUrls.isNotEmpty) {
      img = mediaUrls.first;
    } else if (img.isEmpty) {
      img = 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800&h=500&fit=crop&auto=format';
    }

    if (mediaUrls.isEmpty) {
      mediaUrls = [img];
    } else if (!mediaUrls.contains(img)) {
      mediaUrls = [img, ...mediaUrls];
    }

    return PlaceModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      category: category,
      location: location,
      region: region,
      province: province,
      type: type,
      rating: rating,
      reviews: reviews,
      price: price,
      priceMax: priceMax,
      priceRange: json['priceRange']?.toString() ?? (priceMax > 500000 ? 'Cao cấp' : priceMax > 100000 ? 'Trung bình' : 'Bình dân'),
      hours: hours,
      status: status,
      desc: desc,
      detailedDescription: detailedDescription,
      phoneNumber: phoneNumber,
      website: website,
      highlights: highlights,
      amenities: amenities,
      tags: tags,
      img: img,
      mediaUrls: mediaUrls,
      isSaved: json['isSaved'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 21.0285,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 105.8542,
    );
  }

  static String _formatCurrency(int value) {
    final str = value.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return '$formattedđ';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'location': location,
      'region': region,
      'province': province,
      'type': type,
      'rating': rating,
      'reviews': reviews,
      'price': price,
      'priceMax': priceMax,
      'priceRange': priceRange,
      'hours': hours,
      'status': status,
      'desc': desc,
      'detailedDescription': detailedDescription,
      'phoneNumber': phoneNumber,
      'website': website,
      'highlights': highlights,
      'amenities': amenities.map((e) => e.toJson()).toList(),
      'tags': tags,
      'img': img,
      'mediaUrls': mediaUrls,
      'isSaved': isSaved,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

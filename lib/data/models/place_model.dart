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
  final bool isVisited;
  final double latitude;
  final double longitude;
  final String? explainReason;
  final double? distanceKm;
  final double? matchPercentage;
  final String? matchReason;
  final int? categoryId;
  final int? provinceId;

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
    this.isVisited = false,
    this.latitude = 21.0285,
    this.longitude = 105.8542,
    this.explainReason,
    this.distanceKm,
    this.matchPercentage,
    this.matchReason,
    this.categoryId,
    this.provinceId,
  });

  String get imageUrl => img;
  int get reviewCount => reviews;
  String get address => location;

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
    bool? isVisited,
    double? latitude,
    double? longitude,
    String? explainReason,
    double? distanceKm,
    double? matchPercentage,
    String? matchReason,
    int? categoryId,
    int? provinceId,
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
      isVisited: isVisited ?? this.isVisited,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      explainReason: explainReason ?? this.explainReason,
      distanceKm: distanceKm ?? this.distanceKm,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      matchReason: matchReason ?? this.matchReason,
      categoryId: categoryId ?? this.categoryId,
      provinceId: provinceId ?? this.provinceId,
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

    // Description & ExplainReason
    final explainReason = json['explainReason']?.toString();
    final desc = json['description']?.toString() ??
        json['desc']?.toString() ??
        explainReason ??
        '';

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

    double lat = (json['latitude'] as num?)?.toDouble() ?? 0.0;
    double lng = (json['longitude'] as num?)?.toDouble() ?? 0.0;

    if ((lat == 0.0 || lng == 0.0) && json['coordinates'] is List) {
      final coords = json['coordinates'] as List;
      if (coords.length >= 2) {
        final c0 = (coords[0] as num).toDouble();
        final c1 = (coords[1] as num).toDouble();
        // In GeoJSON standard: [longitude, latitude]
        if (c0 > 50) {
          lng = c0;
          lat = c1;
        } else {
          lat = c0;
          lng = c1;
        }
      }
    }

    // If coordinates are still missing or 0, determine coordinates by province/location
    if (lat == 0.0 || lng == 0.0) {
      final resolved = _resolveProvinceCoordinates(province, location, region);
      lat = resolved[0];
      lng = resolved[1];
    }

    return PlaceModel(
      id: (json['id'] as num?)?.toInt() ?? (json['placeId'] as num?)?.toInt() ?? 0,
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
      isVisited: json['isVisited'] as bool? ?? json['isCheckedIn'] as bool? ?? false,
      latitude: lat,
      longitude: lng,
      explainReason: explainReason,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      matchPercentage: (json['matchPercentage'] as num?)?.toDouble() ??
          ((json['cosineSimilarity'] as num?) != null
              ? ((json['cosineSimilarity'] as num).toDouble() * 100.0)
              : null),
      matchReason: json['matchReason']?.toString(),
      categoryId: (json['categoryId'] as num?)?.toInt(),
      provinceId: (json['provinceId'] as num?)?.toInt(),
    );
  }

  static List<double> _resolveProvinceCoordinates(String province, String location, String region) {
    final text = '${province.toLowerCase()} ${location.toLowerCase()} ${region.toLowerCase()}';

    if (text.contains('hà nội') || text.contains('ha noi')) return [21.0285, 105.8542];
    if (text.contains('hồ chí minh') || text.contains('sài gòn') || text.contains('tp.hcm') || text.contains('tphcm')) return [10.7769, 106.7009];
    if (text.contains('đà nẵng') || text.contains('da nang')) return [16.0544, 108.2022];
    if (text.contains('huế') || text.contains('thừa thiên')) return [16.4637, 107.5909];
    if (text.contains('quảng nam') || text.contains('hội an')) return [15.8801, 108.3380];
    if (text.contains('lâm đồng') || text.contains('đà lạt')) return [11.9404, 108.4380];
    if (text.contains('khánh hòa') || text.contains('nha trang')) return [12.2388, 109.1967];
    if (text.contains('lào cai') || text.contains('sa pa') || text.contains('sapa')) return [22.3364, 103.8438];
    if (text.contains('hà giang')) return [22.8233, 104.9836];
    if (text.contains('quảng ninh') || text.contains('hạ long')) return [20.9515, 107.0736];
    if (text.contains('ninh bình')) return [20.2506, 105.9744];
    if (text.contains('hải phòng')) return [20.8449, 106.6881];
    if (text.contains('cần thơ')) return [10.0452, 105.7469];
    if (text.contains('kiên giang') || text.contains('phú quốc')) return [10.2899, 103.9840];
    if (text.contains('vũng tàu') || text.contains('bà rịa')) return [10.3460, 107.0843];
    if (text.contains('bình định') || text.contains('quy nhơn')) return [13.7830, 109.2197];
    if (text.contains('quảng bình') || text.contains('đồng hới')) return [17.4760, 106.6000];
    if (text.contains('tây ninh')) return [11.3100, 106.0988];
    if (text.contains('an giang') || text.contains('châu đốc')) return [10.5216, 105.1259];
    if (text.contains('cao bằng')) return [22.6657, 106.2625];
    if (text.contains('phú yên') || text.contains('tuy hòa')) return [13.0882, 109.3142];
    if (text.contains('bình thuận') || text.contains('phan thiết') || text.contains('mũi né')) return [10.9333, 108.1000];
    if (text.contains('đắk lắk') || text.contains('buôn ma thuột')) return [12.6667, 108.0500];
    if (text.contains('đồng nai') || text.contains('biên hòa')) return [10.9574, 106.8427];
    if (text.contains('bình dương')) return [11.3254, 106.6826];
    if (text.contains('tiền giang') || text.contains('mỹ tho')) return [10.3600, 106.3600];
    if (text.contains('bến tre')) return [10.2433, 106.3756];
    if (text.contains('cà mau')) return [9.1769, 105.1524];

    if (text.contains('miền bắc') || text.contains('north')) return [21.0285, 105.8542];
    if (text.contains('miền trung') || text.contains('central')) return [16.0544, 108.2022];
    if (text.contains('miền nam') || text.contains('south')) return [10.7769, 106.7009];

    return [21.0285, 105.8542];
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
      'isVisited': isVisited,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

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
  final List<String> tags;
  final String img;
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
    required this.tags,
    required this.img,
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
    List<String>? tags,
    String? img,
    bool? isSaved,
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
      tags: tags ?? this.tags,
      img: img ?? this.img,
      isSaved: isSaved ?? this.isSaved,
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

    // Image
    final img = json['thumbnailUrl']?.toString() ??
        json['img']?.toString() ??
        'https://images.unsplash.com/photo-1528127269322-539801943592?w=800&h=500&fit=crop&auto=format';

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
      tags: tags,
      img: img,
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
      'tags': tags,
      'img': img,
      'isSaved': isSaved,
    };
  }
}

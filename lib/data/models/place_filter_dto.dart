import 'place_model.dart';

class LookupItemDto {
  final int id;
  final String name;

  const LookupItemDto({
    required this.id,
    required this.name,
  });

  factory LookupItemDto.fromJson(Map<String, dynamic> json) {
    return LookupItemDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class RegionLookupDto {
  final int id;
  final String name;
  final List<LookupItemDto> provinces;

  const RegionLookupDto({
    required this.id,
    required this.name,
    required this.provinces,
  });

  factory RegionLookupDto.fromJson(Map<String, dynamic> json) {
    final provList = (json['provinces'] as List<dynamic>?)
            ?.map((p) => LookupItemDto.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];
    return RegionLookupDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      provinces: provList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provinces': provinces.map((p) => p.toJson()).toList(),
    };
  }
}

class PlaceFilterOptionsDto {
  final List<LookupItemDto> categories;
  final List<RegionLookupDto> regions;

  const PlaceFilterOptionsDto({
    required this.categories,
    required this.regions,
  });

  factory PlaceFilterOptionsDto.fromJson(Map<String, dynamic> json) {
    final catList = (json['categories'] as List<dynamic>?)
            ?.map((c) => LookupItemDto.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    final regList = (json['regions'] as List<dynamic>?)
            ?.map((r) => RegionLookupDto.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];

    return PlaceFilterOptionsDto(
      categories: catList,
      regions: regList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories.map((c) => c.toJson()).toList(),
      'regions': regions.map((r) => r.toJson()).toList(),
    };
  }
}

class PlaceFilterParams {
  final String? keyword;
  final int? regionId;
  final int? provinceId;
  final int? categoryId;
  final int? placeTypeId;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final String? sortBy;
  final int page;
  final int pageSize;

  const PlaceFilterParams({
    this.keyword,
    this.regionId,
    this.provinceId,
    this.categoryId,
    this.placeTypeId,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.sortBy,
    this.page = 1,
    this.pageSize = 12,
  });

  Map<String, String> toQueryParameters() {
    final Map<String, String> params = {};

    if (keyword != null && keyword!.trim().isNotEmpty) {
      params['Keyword'] = keyword!.trim();
    }
    if (regionId != null && regionId! > 0) {
      params['RegionId'] = regionId.toString();
    }
    if (provinceId != null && provinceId! > 0) {
      params['ProvinceId'] = provinceId.toString();
    }
    if (categoryId != null && categoryId! > 0) {
      params['CategoryId'] = categoryId.toString();
    }
    if (placeTypeId != null && placeTypeId! > 0) {
      params['PlaceTypeId'] = placeTypeId.toString();
    }
    if (minPrice != null && minPrice! > 0) {
      params['MinPrice'] = minPrice!.toStringAsFixed(0);
    }
    if (maxPrice != null && maxPrice! > 0) {
      params['MaxPrice'] = maxPrice!.toStringAsFixed(0);
    }
    if (minRating != null && minRating! > 0) {
      params['MinRating'] = minRating!.toString();
    }
    if (sortBy != null && sortBy!.isNotEmpty && sortBy != 'popular_desc') {
      params['SortBy'] = sortBy!;
    }
    params['Page'] = page.toString();
    params['PageSize'] = pageSize.toString();

    return params;
  }
}

class CategoryDto {
  final int id;
  final int placeTypeId;
  final String placeTypeName;
  final String name;
  final String? iconClass;
  final int placeCount;

  const CategoryDto({
    required this.id,
    this.placeTypeId = 0,
    this.placeTypeName = '',
    required this.name,
    this.iconClass,
    this.placeCount = 0,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      placeTypeId: (json['placeTypeId'] as num?)?.toInt() ?? 0,
      placeTypeName: json['placeTypeName']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      iconClass: json['iconClass']?.toString(),
      placeCount: (json['placeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'placeTypeId': placeTypeId,
      'placeTypeName': placeTypeName,
      'name': name,
      'iconClass': iconClass,
      'placeCount': placeCount,
    };
  }
}

class CollectionDto {
  final int id;
  final String title;
  final String? description;
  final bool isFeatured;
  final int displayOrder;
  final String? coverUrl;
  final int placeCount;
  final List<PlaceModel> places;

  const CollectionDto({
    required this.id,
    required this.title,
    this.description,
    this.isFeatured = true,
    this.displayOrder = 0,
    this.coverUrl,
    this.placeCount = 0,
    this.places = const [],
  });

  factory CollectionDto.fromJson(Map<String, dynamic> json) {
    List<PlaceModel> placesList = [];
    if (json['places'] is List) {
      placesList = (json['places'] as List)
          .map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return CollectionDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      isFeatured: json['isFeatured'] as bool? ?? true,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      coverUrl: json['coverUrl']?.toString() ?? json['imageUrl']?.toString(),
      placeCount: (json['placeCount'] as num?)?.toInt() ?? (placesList.isNotEmpty ? placesList.length : 0),
      places: placesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isFeatured': isFeatured,
      'displayOrder': displayOrder,
      'coverUrl': coverUrl,
      'placeCount': placeCount,
      'places': places.map((e) => e.toJson()).toList(),
    };
  }
}

class RegionDto {
  final int id;
  final String name;
  final String? tagline;
  final String? description;
  final String? imageUrl;
  final int orderIndex;
  final int provinceCount;
  final List<ProvinceDto> provinces;

  const RegionDto({
    required this.id,
    required this.name,
    this.tagline,
    this.description,
    this.imageUrl,
    this.orderIndex = 0,
    this.provinceCount = 0,
    this.provinces = const [],
  });

  factory RegionDto.fromJson(Map<String, dynamic> json) {
    List<ProvinceDto> provList = [];
    if (json['provinces'] is List) {
      provList = (json['provinces'] as List)
          .map((e) => ProvinceDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return RegionDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      tagline: json['tagline']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
      provinceCount: (json['provinceCount'] as num?)?.toInt() ?? provList.length,
      provinces: provList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tagline': tagline,
      'description': description,
      'imageUrl': imageUrl,
      'orderIndex': orderIndex,
      'provinceCount': provinceCount,
      'provinces': provinces.map((e) => e.toJson()).toList(),
    };
  }
}

class ProvinceDto {
  final int id;
  final int regionId;
  final String regionName;
  final String name;
  final String? tagline;
  final String? description;
  final String? imageUrl;
  final bool featured;
  final int displayOrder;
  final int placeCount;

  const ProvinceDto({
    required this.id,
    required this.regionId,
    required this.regionName,
    required this.name,
    this.tagline,
    this.description,
    this.imageUrl,
    this.featured = false,
    this.displayOrder = 0,
    this.placeCount = 0,
  });

  factory ProvinceDto.fromJson(Map<String, dynamic> json) {
    return ProvinceDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      regionId: (json['regionId'] as num?)?.toInt() ?? 0,
      regionName: json['regionName']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      tagline: json['tagline']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      featured: json['featured'] as bool? ?? false,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      placeCount: (json['placeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'regionId': regionId,
      'regionName': regionName,
      'name': name,
      'tagline': tagline,
      'description': description,
      'imageUrl': imageUrl,
      'featured': featured,
      'displayOrder': displayOrder,
      'placeCount': placeCount,
    };
  }
}

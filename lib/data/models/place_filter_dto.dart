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

import 'food_model.dart';
import 'place_filter_dto.dart';
import 'region_landing_model.dart';

class ProvinceInfoDto {
  final int id;
  final String name;
  final String? code;
  final int? regionId;
  final String? regionName;
  final String? imageUrl;
  final String? description;

  const ProvinceInfoDto({
    required this.id,
    required this.name,
    this.code,
    this.regionId,
    this.regionName,
    this.imageUrl,
    this.description,
  });

  factory ProvinceInfoDto.fromJson(Map<String, dynamic> json) {
    return ProvinceInfoDto(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      regionId: json['regionId'] is int ? json['regionId'] : int.tryParse(json['regionId']?.toString() ?? ''),
      regionName: json['regionName'] as String? ?? json['region'] as String?,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (code != null) 'code': code,
    if (regionId != null) 'regionId': regionId,
    if (regionName != null) 'regionName': regionName,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (description != null) 'description': description,
  };
}

class ProvinceItineraryModel {
  final int id;
  final String title;
  final String destination;
  final String region;
  final String duration;
  final int daysCount;
  final String style;
  final String estimatedCost;
  final String coverUrl;
  final String? overview;
  final String authorName;
  final String? authorAvatar;
  final List<dynamic>? days;

  const ProvinceItineraryModel({
    required this.id,
    required this.title,
    required this.destination,
    this.region = '',
    this.duration = '1 ngày',
    this.daysCount = 1,
    this.style = 'Khám phá',
    this.estimatedCost = 'Linh hoạt',
    this.coverUrl = '',
    this.overview,
    this.authorName = 'Cộng đồng',
    this.authorAvatar,
    this.days,
  });

  factory ProvinceItineraryModel.fromJson(Map<String, dynamic> json) {
    String authorName = 'Cộng đồng';
    String? authorAvatar;
    if (json['author'] is Map<String, dynamic>) {
      final authMap = json['author'] as Map<String, dynamic>;
      authorName = authMap['name'] as String? ?? 'Cộng đồng';
      authorAvatar = authMap['avatar'] as String?;
    } else if (json['authorName'] != null) {
      authorName = json['authorName'] as String;
      authorAvatar = json['authorAvatar'] as String?;
    }

    return ProvinceItineraryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      region: json['region'] as String? ?? '',
      duration: json['duration'] as String? ?? '${json['daysCount'] ?? 1} ngày',
      daysCount: json['daysCount'] is int ? json['daysCount'] : int.tryParse(json['daysCount']?.toString() ?? '1') ?? 1,
      style: json['style'] as String? ?? 'Khám phá',
      estimatedCost: json['estimatedCost'] as String? ?? 'Linh hoạt',
      coverUrl: json['coverUrl'] as String? ?? json['coverImg'] as String? ?? '',
      overview: json['overview'] as String? ?? json['description'] as String?,
      authorName: authorName,
      authorAvatar: authorAvatar,
      days: json['days'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'destination': destination,
    'region': region,
    'duration': duration,
    'daysCount': daysCount,
    'style': style,
    'estimatedCost': estimatedCost,
    'coverUrl': coverUrl,
    if (overview != null) 'overview': overview,
    'author': {
      'name': authorName,
      if (authorAvatar != null) 'avatar': authorAvatar,
    },
  };
}

class ProvinceLandingModel {
  final ProvinceInfoDto province;
  final String heroHeadline;
  final String heroSubheadline;
  final List<RegionHeroImage> heroImages;
  final List<CollectionDto> collections;
  final List<RegionLandmarkModel> landmarks;
  final List<FoodModel> foods;
  final List<RegionBlogPostModel> blogPosts;
  final List<ProvinceItineraryModel> itineraries;
  final RegionSpotlightModel? spotlight;
  final List<RegionReviewModel> reviews;

  const ProvinceLandingModel({
    required this.province,
    required this.heroHeadline,
    required this.heroSubheadline,
    this.heroImages = const [],
    this.collections = const [],
    this.landmarks = const [],
    this.foods = const [],
    this.blogPosts = const [],
    this.itineraries = const [],
    this.spotlight,
    this.reviews = const [],
  });

  factory ProvinceLandingModel.fromJson(Map<String, dynamic> json) {
    ProvinceInfoDto prov;
    if (json['province'] is Map<String, dynamic>) {
      prov = ProvinceInfoDto.fromJson(json['province'] as Map<String, dynamic>);
    } else {
      prov = ProvinceInfoDto(
        id: json['provinceId'] is int ? json['provinceId'] : 1,
        name: json['provinceName'] as String? ?? json['name'] as String? ?? 'Tỉnh thành',
      );
    }

    final heroImagesList = (json['heroImages'] as List<dynamic>?)
            ?.map((e) => RegionHeroImage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final collectionsList = (json['collections'] as List<dynamic>?)
            ?.map((e) => CollectionDto.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final landmarksList = (json['landmarks'] as List<dynamic>?)
            ?.map((e) => RegionLandmarkModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final foodsList = (json['foods'] as List<dynamic>?)
            ?.map((e) => FoodModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final blogPostsList = (json['blogPosts'] as List<dynamic>?)
            ?.map((e) => RegionBlogPostModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final itinerariesList = (json['itineraries'] as List<dynamic>?)
            ?.map((e) => ProvinceItineraryModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final spotlightObj = json['spotlight'] != null
        ? RegionSpotlightModel.fromJson(json['spotlight'] as Map<String, dynamic>)
        : null;

    final reviewsList = (json['reviews'] as List<dynamic>?)
            ?.map((e) => RegionReviewModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ProvinceLandingModel(
      province: prov,
      heroHeadline: json['heroHeadline'] as String? ?? 'Khám phá vẻ đẹp trọn vẹn',
      heroSubheadline: json['heroSubheadline'] as String? ?? '',
      heroImages: heroImagesList,
      collections: collectionsList,
      landmarks: landmarksList,
      foods: foodsList,
      blogPosts: blogPostsList,
      itineraries: itinerariesList,
      spotlight: spotlightObj,
      reviews: reviewsList,
    );
  }
}

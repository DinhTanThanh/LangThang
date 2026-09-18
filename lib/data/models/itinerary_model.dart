class ItineraryAuthorModel {
  final String name;
  final String? avatar;
  final String rank;

  const ItineraryAuthorModel({
    required this.name,
    this.avatar,
    this.rank = 'Thổ địa',
  });

  factory ItineraryAuthorModel.fromJson(Map<String, dynamic> json) {
    return ItineraryAuthorModel(
      name: json['name'] as String? ?? 'Lang Thang Editor',
      avatar: json['avatar'] as String?,
      rank: json['rank'] as String? ?? 'Thổ địa',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'avatar': avatar,
        'rank': rank,
      };
}

class TripMemberModel {
  final int id;
  final String name;
  final String? avatar;
  final String email;
  final String role; // 'Owner' | 'Editor' | 'Viewer'

  const TripMemberModel({
    required this.id,
    required this.name,
    this.avatar,
    this.email = '',
    this.role = 'Member',
  });

  factory TripMemberModel.fromJson(Map<String, dynamic> json) {
    return TripMemberModel(
      id: (json['id'] as num?)?.toInt() ?? (json['userId'] as num?)?.toInt() ?? 1,
      name: json['fullName'] as String? ?? json['name'] as String? ?? 'Thành viên',
      avatar: json['avatarUrl'] as String? ?? json['avatar'] as String?,
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'Member',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'email': email,
        'role': role,
      };
}

class ItineraryStopModel {
  final String id;
  final int? placeId;
  final String time;
  final String startTime;
  final String endTime;
  final String activity;
  final String location;
  final String category;
  final String? description;
  final String? costEstimate;
  final double costEstimateNum;
  final String? tips;
  final String transportMode; // 'Xe máy' | 'Ô tô' | 'Đi bộ' | 'Taxi' | 'Xe buýt' | 'Tàu hỏa' | 'Máy bay'
  final String duration;
  final int visitOrder;
  final String? img;
  final double? lat;
  final double? lng;
  final double? rating;

  const ItineraryStopModel({
    required this.id,
    this.placeId,
    required this.time,
    this.startTime = '08:00',
    this.endTime = '09:30',
    required this.activity,
    required this.location,
    this.category = 'Điểm tham quan',
    this.description,
    this.costEstimate,
    this.costEstimateNum = 0,
    this.tips,
    this.transportMode = 'Xe máy',
    this.duration = '1.5 giờ',
    this.visitOrder = 1,
    this.img,
    this.lat,
    this.lng,
    this.rating = 4.8,
  });

  factory ItineraryStopModel.fromJson(Map<String, dynamic> json) {
    final rawCost = json['costEstimate'] as String? ?? '';
    double parsedCostNum = (json['costEstimateNum'] as num?)?.toDouble() ?? 0;
    if (parsedCostNum == 0 && rawCost.isNotEmpty) {
      parsedCostNum = double.tryParse(rawCost.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final rawTime = json['time'] as String? ?? '08:00';
    return ItineraryStopModel(
      id: json['id']?.toString() ?? 'stop-${DateTime.now().microsecondsSinceEpoch}',
      placeId: (json['placeId'] as num?)?.toInt(),
      time: rawTime,
      startTime: json['startTime'] as String? ?? rawTime,
      endTime: json['endTime'] as String? ?? '09:30',
      activity: json['activity'] as String? ?? json['name'] as String? ?? 'Điểm dừng chân',
      location: json['location'] as String? ?? json['address'] as String? ?? '',
      category: json['category'] as String? ?? 'Điểm tham quan',
      description: json['description'] as String? ?? json['note'] as String?,
      costEstimate: rawCost.isNotEmpty ? rawCost : (parsedCostNum > 0 ? '${parsedCostNum.toInt()}đ' : 'Miễn phí'),
      costEstimateNum: parsedCostNum,
      tips: json['tips'] as String?,
      transportMode: json['transportMode'] as String? ?? 'Xe máy',
      duration: json['duration'] as String? ?? '1.5 giờ',
      visitOrder: (json['visitOrder'] as num?)?.toInt() ?? 1,
      img: json['img'] as String? ?? json['imageUrl'] as String?,
      lat: (json['lat'] as num?)?.toDouble() ?? (json['latitude'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble() ?? (json['longitude'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
    );
  }

  ItineraryStopModel copyWith({
    String? id,
    int? placeId,
    String? time,
    String? startTime,
    String? endTime,
    String? activity,
    String? location,
    String? category,
    String? description,
    String? costEstimate,
    double? costEstimateNum,
    String? tips,
    String? transportMode,
    String? duration,
    int? visitOrder,
    String? img,
    double? lat,
    double? lng,
    double? rating,
  }) {
    return ItineraryStopModel(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      time: time ?? this.time,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      activity: activity ?? this.activity,
      location: location ?? this.location,
      category: category ?? this.category,
      description: description ?? this.description,
      costEstimate: costEstimate ?? this.costEstimate,
      costEstimateNum: costEstimateNum ?? this.costEstimateNum,
      tips: tips ?? this.tips,
      transportMode: transportMode ?? this.transportMode,
      duration: duration ?? this.duration,
      visitOrder: visitOrder ?? this.visitOrder,
      img: img ?? this.img,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'placeId': placeId,
        'time': time,
        'startTime': startTime,
        'endTime': endTime,
        'activity': activity,
        'location': location,
        'category': category,
        'description': description,
        'costEstimate': costEstimate,
        'costEstimateNum': costEstimateNum,
        'tips': tips,
        'transportMode': transportMode,
        'duration': duration,
        'visitOrder': visitOrder,
        'img': img,
        'lat': lat,
        'lng': lng,
        'rating': rating,
      };
}

class ItineraryDayModel {
  final int dayNumber;
  final String title;
  final String? date;
  final String? description;
  final List<ItineraryStopModel> stops;

  const ItineraryDayModel({
    required this.dayNumber,
    required this.title,
    this.date,
    this.description,
    this.stops = const [],
  });

  factory ItineraryDayModel.fromJson(Map<String, dynamic> json) {
    return ItineraryDayModel(
      dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? json['dayTitle'] as String? ?? 'Lộ trình khám phá',
      date: json['date'] as String?,
      description: json['description'] as String?,
      stops: (json['stops'] as List<dynamic>?)
              ?.map((e) => ItineraryStopModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  ItineraryDayModel copyWith({
    int? dayNumber,
    String? title,
    String? date,
    String? description,
    List<ItineraryStopModel>? stops,
  }) {
    return ItineraryDayModel(
      dayNumber: dayNumber ?? this.dayNumber,
      title: title ?? this.title,
      date: date ?? this.date,
      description: description ?? this.description,
      stops: stops ?? this.stops,
    );
  }

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'title': title,
        'date': date,
        'description': description,
        'stops': stops.map((e) => e.toJson()).toList(),
      };
}

class ItineraryModel {
  final int id;
  final String title;
  final String destination;
  final String region;
  final String duration;
  final int daysCount;
  final int nightsCount;
  final String style;
  final String estimatedCost;
  final double estimatedBudgetNum;
  final double? budgetTarget;
  final String? coverUrl;
  final ItineraryAuthorModel author;
  final String? overview;
  final List<ItineraryDayModel> days;
  final List<ItineraryStopModel> backlogStops;
  final List<TripMemberModel> members;
  final List<String> tags;
  final double rating;
  final int reviewCount;
  final bool isSaved;
  final String? startDate;
  final String? endDate;

  const ItineraryModel({
    required this.id,
    required this.title,
    this.destination = '',
    this.region = 'all',
    required this.duration,
    this.daysCount = 1,
    this.nightsCount = 0,
    this.style = 'Văn hóa & Trải nghiệm',
    this.estimatedCost = 'Tự túc',
    this.estimatedBudgetNum = 0,
    this.budgetTarget,
    this.coverUrl,
    required this.author,
    this.overview,
    this.days = const [],
    this.backlogStops = const [],
    this.members = const [],
    this.tags = const [],
    this.rating = 4.9,
    this.reviewCount = 120,
    this.isSaved = false,
    this.startDate,
    this.endDate,
  });

  // Helpers
  String get imageUrl =>
      coverUrl ??
      'https://images.unsplash.com/photo-1528127269322-539801943592?w=800&h=500&fit=crop';
  String get category => style;
  String get description => overview ?? '';
  String get authorName => author.name;
  String get authorAvatar => author.avatar ?? '';
  int get stopCount => days.fold(0, (acc, d) => acc + d.stops.length);
  List<String> get highlights =>
      days.expand((d) => d.stops.map((s) => s.activity)).take(4).toList();

  double get calculatedTotalCost {
    double total = 0;
    for (var d in days) {
      for (var s in d.stops) {
        total += s.costEstimateNum;
      }
    }
    return total > 0 ? total : estimatedBudgetNum;
  }

  ItineraryModel copyWith({
    int? id,
    String? title,
    String? destination,
    String? region,
    String? duration,
    int? daysCount,
    int? nightsCount,
    String? style,
    String? estimatedCost,
    double? estimatedBudgetNum,
    double? budgetTarget,
    String? coverUrl,
    ItineraryAuthorModel? author,
    String? overview,
    List<ItineraryDayModel>? days,
    List<ItineraryStopModel>? backlogStops,
    List<TripMemberModel>? members,
    List<String>? tags,
    double? rating,
    int? reviewCount,
    bool? isSaved,
    String? startDate,
    String? endDate,
  }) {
    return ItineraryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      region: region ?? this.region,
      duration: duration ?? this.duration,
      daysCount: daysCount ?? this.daysCount,
      nightsCount: nightsCount ?? this.nightsCount,
      style: style ?? this.style,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      estimatedBudgetNum: estimatedBudgetNum ?? this.estimatedBudgetNum,
      budgetTarget: budgetTarget ?? this.budgetTarget,
      coverUrl: coverUrl ?? this.coverUrl,
      author: author ?? this.author,
      overview: overview ?? this.overview,
      days: days ?? this.days,
      backlogStops: backlogStops ?? this.backlogStops,
      members: members ?? this.members,
      tags: tags ?? this.tags,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isSaved: isSaved ?? this.isSaved,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    int parsedId = 1;
    if (json['id'] is num) {
      parsedId = (json['id'] as num).toInt();
    } else if (json['id'] is String) {
      parsedId = int.tryParse(json['id'] as String) ??
          (json['id'] as String).hashCode.abs() % 10000;
    }

    final authorJson = json['author'];
    ItineraryAuthorModel authorObj;
    if (authorJson is Map<String, dynamic>) {
      authorObj = ItineraryAuthorModel.fromJson(authorJson);
    } else {
      authorObj = ItineraryAuthorModel(
        name: json['authorName'] as String? ?? 'Lang Thang Editor',
        avatar: json['authorAvatar'] as String?,
        rank: json['authorRank'] as String? ?? 'Thổ địa',
      );
    }

    final daysJson = json['days'] as List<dynamic>?;
    final List<ItineraryDayModel> daysList = daysJson != null
        ? daysJson
            .map((e) => ItineraryDayModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : [];

    final backlogJson = json['backlogStops'] as List<dynamic>?;
    final List<ItineraryStopModel> backlogList = backlogJson != null
        ? backlogJson
            .map((e) => ItineraryStopModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : [];

    final membersJson = json['members'] as List<dynamic>?;
    final List<TripMemberModel> membersList = membersJson != null
        ? membersJson
            .map((e) => TripMemberModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : [];

    final tagsJson = json['tags'] as List<dynamic>?;
    final List<String> tagsList =
        tagsJson != null ? tagsJson.map((e) => e.toString()).toList() : [];

    final rawCost = json['estimatedCost'] as String? ?? '1.500.000đ – 3.000.000đ';
    double parsedCostNum = (json['estimatedBudget'] as num?)?.toDouble() ??
        (json['estimatedBudgetNum'] as num?)?.toDouble() ??
        0;
    if (parsedCostNum == 0 && rawCost.isNotEmpty) {
      parsedCostNum = double.tryParse(rawCost.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final parsedDaysCount = (json['daysCount'] as num?)?.toInt() ??
        (daysList.isNotEmpty ? daysList.length : 1);

    return ItineraryModel(
      id: parsedId,
      title: json['title'] as String? ?? 'Lịch trình du lịch',
      destination: json['destination'] as String? ??
          json['province'] as String? ??
          json['title'] as String? ??
          '',
      region: json['region'] as String? ?? 'all',
      duration: json['duration'] as String? ??
          '$parsedDaysCount Ngày ${parsedDaysCount > 1 ? '${parsedDaysCount - 1} Đêm' : ''}',
      daysCount: parsedDaysCount,
      nightsCount: (json['nightsCount'] as num?)?.toInt() ??
          (parsedDaysCount > 1 ? parsedDaysCount - 1 : 0),
      style: json['style'] as String? ??
          json['category'] as String? ??
          'Khám phá & Trải nghiệm',
      estimatedCost: rawCost,
      estimatedBudgetNum: parsedCostNum,
      budgetTarget: (json['budgetTarget'] as num?)?.toDouble(),
      coverUrl: json['coverUrl'] as String? ??
          json['coverImg'] as String? ??
          json['imageUrl'] as String?,
      author: authorObj,
      overview: json['overview'] as String? ??
          json['description'] as String?,
      days: daysList,
      backlogStops: backlogList,
      members: membersList,
      tags: tagsList,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 120,
      isSaved: json['isSaved'] as bool? ?? false,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'destination': destination,
      'region': region,
      'duration': duration,
      'daysCount': daysCount,
      'nightsCount': nightsCount,
      'style': style,
      'estimatedCost': estimatedCost,
      'estimatedBudgetNum': estimatedBudgetNum,
      'budgetTarget': budgetTarget,
      'coverUrl': coverUrl,
      'author': author.toJson(),
      'overview': overview,
      'days': days.map((e) => e.toJson()).toList(),
      'backlogStops': backlogStops.map((e) => e.toJson()).toList(),
      'members': members.map((e) => e.toJson()).toList(),
      'tags': tags,
      'rating': rating,
      'reviewCount': reviewCount,
      'isSaved': isSaved,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}

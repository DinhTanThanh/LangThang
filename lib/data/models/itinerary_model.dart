class ItineraryAuthorModel {
  final String name;
  final String? avatar;

  const ItineraryAuthorModel({
    required this.name,
    this.avatar,
  });

  factory ItineraryAuthorModel.fromJson(Map<String, dynamic> json) {
    return ItineraryAuthorModel(
      name: json['name'] as String? ?? 'Lang Thang Editor',
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'avatar': avatar,
      };
}

class ItineraryStopModel {
  final String time;
  final String activity;
  final String location;
  final String? description;
  final String? costEstimate;
  final String? tips;

  const ItineraryStopModel({
    required this.time,
    required this.activity,
    required this.location,
    this.description,
    this.costEstimate,
    this.tips,
  });

  factory ItineraryStopModel.fromJson(Map<String, dynamic> json) {
    return ItineraryStopModel(
      time: json['time'] as String? ?? '08:00',
      activity: json['activity'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String?,
      costEstimate: json['costEstimate'] as String?,
      tips: json['tips'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'activity': activity,
        'location': location,
        'description': description,
        'costEstimate': costEstimate,
        'tips': tips,
      };
}

class ItineraryDayModel {
  final int dayNumber;
  final String title;
  final List<ItineraryStopModel> stops;

  const ItineraryDayModel({
    required this.dayNumber,
    required this.title,
    this.stops = const [],
  });

  factory ItineraryDayModel.fromJson(Map<String, dynamic> json) {
    return ItineraryDayModel(
      dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? 'Lộ trình khám phá',
      stops: (json['stops'] as List<dynamic>?)
              ?.map((e) => ItineraryStopModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'title': title,
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
  final String style;
  final String estimatedCost;
  final String? coverUrl;
  final ItineraryAuthorModel author;
  final String? overview;
  final List<ItineraryDayModel> days;
  final double rating;
  final int reviewCount;
  final bool isSaved;

  const ItineraryModel({
    required this.id,
    required this.title,
    this.destination = '',
    this.region = 'all',
    required this.duration,
    this.daysCount = 1,
    this.style = 'Văn hóa & Trải nghiệm',
    this.estimatedCost = 'Tự túc',
    this.coverUrl,
    required this.author,
    this.overview,
    this.days = const [],
    this.rating = 4.9,
    this.reviewCount = 120,
    this.isSaved = false,
  });

  // Helpers
  String get imageUrl => coverUrl ?? 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800&h=500&fit=crop';
  String get category => style;
  String get description => overview ?? '';
  String get authorName => author.name;
  String get authorAvatar => author.avatar ?? '';
  int get stopCount => days.fold(0, (acc, d) => acc + d.stops.length);
  List<String> get highlights => days.expand((d) => d.stops.map((s) => s.activity)).take(4).toList();

  ItineraryModel copyWith({
    int? id,
    String? title,
    String? destination,
    String? region,
    String? duration,
    int? daysCount,
    String? style,
    String? estimatedCost,
    String? coverUrl,
    ItineraryAuthorModel? author,
    String? overview,
    List<ItineraryDayModel>? days,
    double? rating,
    int? reviewCount,
    bool? isSaved,
  }) {
    return ItineraryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      region: region ?? this.region,
      duration: duration ?? this.duration,
      daysCount: daysCount ?? this.daysCount,
      style: style ?? this.style,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      coverUrl: coverUrl ?? this.coverUrl,
      author: author ?? this.author,
      overview: overview ?? this.overview,
      days: days ?? this.days,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    int parsedId = 1;
    if (json['id'] is num) {
      parsedId = (json['id'] as num).toInt();
    } else if (json['id'] is String) {
      parsedId = int.tryParse(json['id'] as String) ?? (json['id'] as String).hashCode.abs() % 10000;
    }

    final authorJson = json['author'];
    ItineraryAuthorModel authorObj;
    if (authorJson is Map<String, dynamic>) {
      authorObj = ItineraryAuthorModel.fromJson(authorJson);
    } else {
      authorObj = ItineraryAuthorModel(
        name: json['authorName'] as String? ?? 'Lang Thang Editor',
        avatar: json['authorAvatar'] as String?,
      );
    }

    final daysJson = json['days'] as List<dynamic>?;
    final List<ItineraryDayModel> daysList = daysJson != null
        ? daysJson.map((e) => ItineraryDayModel.fromJson(e as Map<String, dynamic>)).toList()
        : [];

    return ItineraryModel(
      id: parsedId,
      title: json['title'] as String? ?? 'Lịch trình du lịch',
      destination: json['destination'] as String? ?? json['title'] as String? ?? '',
      region: json['region'] as String? ?? 'all',
      duration: json['duration'] as String? ?? '3 Ngày 2 Đêm',
      daysCount: (json['daysCount'] as num?)?.toInt() ?? (daysList.isNotEmpty ? daysList.length : 1),
      style: json['style'] as String? ?? json['category'] as String? ?? 'Khám phá & Trải nghiệm',
      estimatedCost: json['estimatedCost'] as String? ?? '1.500.000đ – 3.000.000đ',
      coverUrl: json['coverUrl'] as String? ?? json['imageUrl'] as String?,
      author: authorObj,
      overview: json['overview'] as String? ?? json['description'] as String?,
      days: daysList,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 120,
      isSaved: json['isSaved'] as bool? ?? false,
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
      'style': style,
      'estimatedCost': estimatedCost,
      'coverUrl': coverUrl,
      'author': author.toJson(),
      'overview': overview,
      'days': days.map((e) => e.toJson()).toList(),
      'rating': rating,
      'reviewCount': reviewCount,
      'isSaved': isSaved,
    };
  }
}

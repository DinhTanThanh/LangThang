import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_model.dart';

class GpsGridResult {
  final String gridKey;
  final double roundedLat;
  final double roundedLng;

  const GpsGridResult({
    required this.gridKey,
    required this.roundedLat,
    required this.roundedLng,
  });
}

class RecentIntentProvinceItem {
  final int provinceId;
  final String provinceName;
  final String label;
  final int score;
  final int updatedAt;

  const RecentIntentProvinceItem({
    required this.provinceId,
    required this.provinceName,
    required this.label,
    required this.score,
    required this.updatedAt,
  });

  factory RecentIntentProvinceItem.fromJson(Map<String, dynamic> json) {
    return RecentIntentProvinceItem(
      provinceId: (json['provinceId'] as num?)?.toInt() ?? 0,
      provinceName: json['provinceName']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 1,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'provinceId': provinceId,
    'provinceName': provinceName,
    'label': label,
    'score': score,
    'updatedAt': updatedAt,
  };
}

class DeviceContextService {
  static final DeviceContextService _instance = DeviceContextService._internal();
  factory DeviceContextService() => _instance;
  DeviceContextService._internal();

  static const String _keyDeviceId = 'langthang_device_id';
  static const String _keyIntentProvinces = 'langthang_intent_provinces_v2';
  static const String _keyCategoryScores = 'langthang_category_scores_v2';
  static const int _validTtlMs = 48 * 60 * 60 * 1000; // 48 giờ

  static const double defaultLat = 10.762622;
  static const double defaultLng = 106.660172;

  final ValueNotifier<int> intentChangedNotifier = ValueNotifier<int>(0);

  String? _cachedDeviceId;

  /// 1. Device ID định danh duy nhất không cần đăng nhập
  Future<String> getOrCreateDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_keyDeviceId);
      if (existing != null && existing.trim().isNotEmpty) {
        _cachedDeviceId = existing.trim();
        return _cachedDeviceId!;
      }

      final newId = _generateUuidV4();
      await prefs.setString(_keyDeviceId, newId);
      _cachedDeviceId = newId;
      return newId;
    } catch (_) {
      final fallback = _generateUuidV4();
      _cachedDeviceId = fallback;
      return fallback;
    }
  }

  static String _generateUuidV4() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// 2. Làm tròn tọa độ vào ô lưới ~1.1km (Lego Grid Snap)
  GpsGridResult snapGpsToGrid(double lat, double lng) {
    final roundedLat = double.parse(lat.toStringAsFixed(2));
    final roundedLng = double.parse(lng.toStringAsFixed(2));
    final gridKey = 'lat_${lat.toStringAsFixed(2)}_lng_${lng.toStringAsFixed(2)}';
    return GpsGridResult(
      gridKey: gridKey,
      roundedLat: roundedLat,
      roundedLng: roundedLng,
    );
  }

  /// 3. Lấy vị trí GPS thực tế (fallback an toàn)
  Future<({double lat, double lng})> getCurrentGps({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (lat: defaultLat, lng: defaultLng);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return (lat: defaultLat, lng: defaultLng);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );

      return (lat: position.latitude, lng: position.longitude);
    } catch (e) {
      debugPrint('[DeviceContextService] getCurrentGps error/timeout, using fallback: $e');
      return (lat: defaultLat, lng: defaultLng);
    }
  }

  /// 4. Hàng đợi điểm đến ý định (Multi-Destination Queue tối đa 3 tỉnh gần nhất)
  Future<List<RecentIntentProvinceItem>> getRecentIntentProvinces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyIntentProvinces);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final items = decoded
              .whereType<Map<String, dynamic>>()
              .map((j) => RecentIntentProvinceItem.fromJson(j))
              .filter((p) => p.provinceId > 0 && now - p.updatedAt < _validTtlMs)
              .toList();

          items.sort((a, b) {
            final cmp = b.updatedAt.compareTo(a.updatedAt);
            return cmp != 0 ? cmp : b.score.compareTo(a.score);
          });

          return items.take(3).toList();
        }
      }
    } catch (e) {
      debugPrint('[DeviceContextService] getRecentIntentProvinces error: $e');
    }
    return [];
  }

  /// Ghi nhận tín hiệu ý định tìm kiếm/chọn filter tỉnh thành (+3 điểm)
  Future<void> recordSearchIntent({
    required int provinceId,
    required String provinceName,
    String? label,
    int scoreToAdd = 3,
  }) async {
    if (provinceId <= 0) return;
    try {
      final currentList = await getRecentIntentProvinces();
      final now = DateTime.now().millisecondsSinceEpoch;

      final existingIndex = currentList.indexWhere((p) => p.provinceId == provinceId);
      final list = List<RecentIntentProvinceItem>.from(currentList);

      if (existingIndex != -1) {
        final old = list[existingIndex];
        list[existingIndex] = RecentIntentProvinceItem(
          provinceId: provinceId,
          provinceName: provinceName.isNotEmpty ? provinceName : old.provinceName,
          label: (label != null && label.isNotEmpty) ? label : old.label,
          score: old.score + scoreToAdd,
          updatedAt: now,
        );
      } else {
        list.insert(
          0,
          RecentIntentProvinceItem(
            provinceId: provinceId,
            provinceName: provinceName,
            label: (label != null && label.isNotEmpty) ? label : provinceName,
            score: scoreToAdd,
            updatedAt: now,
          ),
        );
      }

      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final trimmed = list.take(3).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyIntentProvinces, jsonEncode(trimmed.map((e) => e.toJson()).toList()));

      intentChangedNotifier.value++;
    } catch (e) {
      debugPrint('[DeviceContextService] recordSearchIntent error: $e');
    }
  }

  /// 5. Bảng điểm sở thích danh mục (Category Affinity Scores)
  Future<List<int>> getTopCategoryIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCategoryScores);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final entries = <({int catId, int score, int updatedAt})>[];

          decoded.forEach((key, val) {
            final catId = int.tryParse(key);
            if (catId != null && catId > 0 && val is Map<String, dynamic>) {
              final score = (val['score'] as num?)?.toInt() ?? 0;
              final updatedAt = (val['updatedAt'] as num?)?.toInt() ?? 0;
              if (now - updatedAt < _validTtlMs) {
                entries.add((catId: catId, score: score, updatedAt: updatedAt));
              }
            }
          });

          entries.sort((a, b) {
            final cmp = b.updatedAt.compareTo(a.updatedAt);
            return cmp != 0 ? cmp : b.score.compareTo(a.score);
          });

          if (entries.isNotEmpty) {
            return entries.take(3).map((e) => e.catId).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('[DeviceContextService] getTopCategoryIds error: $e');
    }
    return [];
  }

  /// Ghi nhận sở thích danh mục (+3 cho filter, +1 cho view detail)
  Future<void> recordCategoryInterest(int categoryId, {int scoreToAdd = 3}) async {
    if (categoryId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCategoryScores);
      final map = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          map.addAll(decoded);
        }
      }

      final key = categoryId.toString();
      final now = DateTime.now().millisecondsSinceEpoch;
      final existingScore = (map[key] is Map) ? ((map[key]['score'] as num?)?.toInt() ?? 0) : 0;

      map[key] = {
        'score': existingScore + scoreToAdd,
        'updatedAt': now,
      };

      await prefs.setString(_keyCategoryScores, jsonEncode(map));
      intentChangedNotifier.value++;
    } catch (e) {
      debugPrint('[DeviceContextService] recordCategoryInterest error: $e');
    }
  }

  /// 6. Ghi nhận khi người dùng xem chi tiết địa điểm
  Future<void> recordVisitedPlace(PlaceModel place) async {
    try {
      if (place.categoryId != null && place.categoryId! > 0) {
        await recordCategoryInterest(place.categoryId!, scoreToAdd: 1);
      }
      if (place.provinceId != null && place.provinceId! > 0) {
        await recordSearchIntent(
          provinceId: place.provinceId!,
          provinceName: place.province.isNotEmpty ? place.province : 'Điểm đến',
          scoreToAdd: 1,
        );
      }
    } catch (_) {}
  }
}

extension _IterableFilter<E> on Iterable<E> {
  Iterable<E> filter(bool Function(E element) test) => where(test);
}


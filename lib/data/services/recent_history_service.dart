import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/place_model.dart';
import '../models/user_profile_data_models.dart';
import 'auth_service.dart';

class RecentHistoryService {
  static final RecentHistoryService _instance = RecentHistoryService._internal();
  factory RecentHistoryService() => _instance;
  RecentHistoryService._internal();

  static const String _storageBaseKey = 'langthang_recent_visited';

  Future<String> _getStorageKey() async => await AuthService().getScopedKey(_storageBaseKey);

  // ValueNotifier to notify floating dock / UI in real time
  final ValueNotifier<List<UserAccessHistoryItemModel>> recentNotifier =
      ValueNotifier<List<UserAccessHistoryItemModel>>([]);

  /// Record a place as viewed
  Future<void> recordAccessHistory(PlaceModel place) async {
    final item = UserAccessHistoryItemModel(
      placeId: place.id,
      placeName: place.name,
      province: place.province.isNotEmpty ? place.province : place.location,
      category: place.category,
      coverImg: place.imageUrl.isNotEmpty ? place.imageUrl : place.img,
      avgRating: place.rating > 0 ? place.rating : 5.0,
      viewedAt: 'Vừa xong',
    );

    // 1. Save to local SharedPreferences
    await _saveItemToLocal(item);

    // 2. Call Backend API if logged in
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };

        final uri = Uri.parse('${ApiConstants.baseUrl}/api/places/${place.id}/access-history');
        await http.post(uri, headers: headers, body: jsonEncode({})).timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('[RecentHistoryService] recordAccessHistory error: $e');
    }
  }

  /// Get recent visited places
  Future<List<UserAccessHistoryItemModel>> getRecentVisitedPlaces({int limit = 10}) async {
    final localItems = await _getLocalItems();

    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final headers = {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };

        final uri = Uri.parse('${ApiConstants.baseUrl}/api/users/me/access-histories?limit=$limit');
        final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 3));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final raw = utf8.decode(res.bodyBytes).trim();
          if (raw.isNotEmpty) {
            final decoded = jsonDecode(raw);
            final dataList = decoded is Map && decoded['data'] != null
                ? decoded['data']
                : (decoded is List ? decoded : null);

            if (dataList is List) {
              final remoteItems = dataList
                  .map((e) => UserAccessHistoryItemModel.fromJson(e as Map<String, dynamic>))
                  .toList();
              if (remoteItems.isNotEmpty) {
                await _mergeRemoteItems(remoteItems);
                final merged = await _getLocalItems();
                recentNotifier.value = merged;
                return merged;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[RecentHistoryService] getRecentVisitedPlaces remote error: $e');
    }

    recentNotifier.value = localItems;
    return localItems;
  }

  /// Remove one place from history
  Future<void> removeRecentPlace(int placeId) async {
    final list = await _getLocalItems();
    list.removeWhere((item) => item.placeId == placeId);
    await _saveList(list);
    recentNotifier.value = list;
  }

  /// Clear all recent places
  Future<void> clearAll() async {
    try {
      final key = await _getStorageKey();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      recentNotifier.value = [];
    } catch (_) {}
  }

  // ==================== INTERNAL HELPERS ====================

  Future<List<UserAccessHistoryItemModel>> _getLocalItems() async {
    try {
      final key = await _getStorageKey();
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List;
        return list.map((e) => UserAccessHistoryItemModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveList(List<UserAccessHistoryItemModel> list) async {
    try {
      final key = await _getStorageKey();
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(list.take(15).map((e) => e.toJson()).toList());
      await prefs.setString(key, jsonStr);
    } catch (_) {}
  }

  Future<void> _saveItemToLocal(UserAccessHistoryItemModel item) async {
    final list = await _getLocalItems();
    list.removeWhere((i) => i.placeId == item.placeId);
    list.insert(0, item);
    await _saveList(list);
    recentNotifier.value = list;
  }

  Future<void> _mergeRemoteItems(List<UserAccessHistoryItemModel> remote) async {
    final local = await _getLocalItems();
    final map = <int, UserAccessHistoryItemModel>{};
    for (final item in local) {
      map[item.placeId] = item;
    }
    for (final item in remote) {
      map[item.placeId] = item;
    }
    final sorted = map.values.toList();
    await _saveList(sorted);
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/itinerary_model.dart';
import '../mock/mock_data.dart';
import 'auth_service.dart';
import 'favorite_api_service.dart';

class ItineraryApiService {
  static final ItineraryApiService _instance = ItineraryApiService._internal();
  factory ItineraryApiService() => _instance;
  ItineraryApiService._internal();

  /// Lấy danh sách lịch trình từ database qua API backend (/api/itineraries)
  Future<List<ItineraryModel>> getItineraries({
    String? duration,
    String? keyword,
    String? region,
    String? budget,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'Page': page.toString(),
        'PageSize': pageSize.toString(),
      };

      if (duration != null && duration.isNotEmpty && duration != 'all') {
        queryParams['Duration'] = duration;
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        queryParams['Keyword'] = keyword.trim();
      }
      if (region != null && region.isNotEmpty && region != 'all') {
        queryParams['Region'] = region;
      }

      // 1. Thử gọi endpoint chuẩn FastEndpoints /api/itineraries
      final baseUri = Uri.parse('${ApiConstants.baseUrl}/api/itineraries');
      final uri = queryParams.isEmpty ? baseUri : baseUri.replace(queryParameters: queryParams);

      final token = await AuthService().getAccessToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        dynamic items;
        if (decoded is Map<String, dynamic>) {
          items = decoded['data'] ?? decoded['items'] ?? decoded['result'];
        } else if (decoded is List) {
          items = decoded;
        }

        if (items is List && items.isNotEmpty) {
          final list = items.map((e) => ItineraryModel.fromJson(e as Map<String, dynamic>)).toList();
          return _filterByBudget(list, budget);
        }
      }
    } catch (_) {}

    // Fallback: Sử dụng dữ liệu MockData nếu database chưa có hoặc offline
    List<ItineraryModel> list = List.from(MockData.itineraries);

    if (duration != null && duration != 'all') {
      if (duration == '1_day' || duration == '1') {
        list = list.where((i) => i.daysCount == 1 || i.duration.contains('1 Ngày')).toList();
      } else if (duration == '2d1n' || duration == '2') {
        list = list.where((i) => i.daysCount == 2 || i.duration.contains('2 Ngày')).toList();
      } else if (duration == '3d2n' || duration == '3') {
        list = list.where((i) => i.daysCount == 3 || i.duration.contains('3 Ngày')).toList();
      } else if (duration == '4d3n' || duration == '4') {
        list = list.where((i) => i.daysCount == 4 || i.duration.contains('4 Ngày')).toList();
      } else if (duration == '5d+' || duration == '5') {
        list = list.where((i) => i.daysCount >= 5 || i.duration.contains('5 Ngày')).toList();
      }
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = keyword.trim().toLowerCase();
      list = list.where((i) {
        return i.title.toLowerCase().contains(q) ||
            i.destination.toLowerCase().contains(q) ||
            (i.overview?.toLowerCase().contains(q) ?? false) ||
            i.days.any((d) => d.stops.any((s) => s.location.toLowerCase().contains(q) || s.activity.toLowerCase().contains(q)));
      }).toList();
    }

    if (region != null && region != 'all') {
      final r = region.toLowerCase();
      list = list.where((i) {
        if (r.contains('bắc') || r == 'north') return i.region == 'north' || i.destination.contains('Hà Nội') || i.destination.contains('Sa Pa') || i.destination.contains('Ninh Bình') || i.destination.contains('Hà Giang');
        if (r.contains('trung') || r == 'central') return i.region == 'central' || i.destination.contains('Đà Nẵng') || i.destination.contains('Hội An') || i.destination.contains('Huế') || i.destination.contains('Đà Lạt');
        if (r.contains('nam') || r == 'south') return i.region == 'south' || i.destination.contains('Hồ Chí Minh') || i.destination.contains('Phú Quốc') || i.destination.contains('Cần Thơ');
        return i.region.toLowerCase() == r;
      }).toList();
    }

    return _filterByBudget(list, budget);
  }

  /// Lấy chi tiết lịch trình chuyến đi theo ID (/api/trips/{id})
  Future<ItineraryModel?> getItineraryDetail(int id) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/trips/$id');
      final token = await AuthService().getAccessToken();
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final dynamic data = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded) : decoded;
        if (data is Map<String, dynamic>) {
          return ItineraryModel.fromJson(data);
        }
      }
    } catch (_) {}

    // Fallback: Tìm trong MockData
    try {
      return MockData.itineraries.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Lưu hoặc bỏ lưu lịch trình yêu thích (/api/itineraries/{id}/save)
  Future<bool> saveItinerary(int id, {ItineraryModel? itinerary, bool isSaving = true}) async {
    if (isSaving) {
      await FavoriteApiService().addFavorite(
        targetType: 3, // Itinerary
        targetId: id,
        title: itinerary?.title ?? 'Lịch trình #$id',
        subtitle: itinerary?.region ?? '',
        coverImg: itinerary?.coverUrl ?? '',
        categoryTag: itinerary?.duration ?? 'Lịch trình',
        rating: 5.0,
      );
    } else {
      await FavoriteApiService().removeFavorite(
        targetType: 3,
        targetId: id,
      );
    }

    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) return true;

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/itineraries/$id/save');
      final response = await (isSaving
          ? http.post(uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'})
          : http.delete(uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}))
          .timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return true; // Optimistic
    }
  }

  List<ItineraryModel> _filterByBudget(List<ItineraryModel> list, String? budget) {
    if (budget == null || budget.isEmpty || budget == 'all') return list;

    if (budget == 'under1m') {
      return list.where((i) => (i.estimatedBudgetNum > 0 && i.estimatedBudgetNum < 1000000) || i.estimatedCost.contains('650')).toList();
    } else if (budget == '1m-3m') {
      return list.where((i) => (i.estimatedBudgetNum >= 1000000 && i.estimatedBudgetNum <= 3000000) || i.estimatedCost.contains('1.800') || i.estimatedCost.contains('1.600') || i.estimatedCost.contains('1.900')).toList();
    } else if (budget == '3m-5m') {
      return list.where((i) => (i.estimatedBudgetNum > 3000000 && i.estimatedBudgetNum <= 5000000) || i.estimatedCost.contains('3.600') || i.estimatedCost.contains('3.200') || i.estimatedCost.contains('3.800')).toList();
    } else if (budget == 'above5m') {
      return list.where((i) => i.estimatedBudgetNum > 5000000 || i.estimatedCost.contains('5.500')).toList();
    }
    return list;
  }
}

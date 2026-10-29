import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/itinerary_model.dart';
import '../models/api_response.dart';
import '../mock/mock_data.dart';
import 'auth_service.dart';
import 'favorite_api_service.dart';

class ItineraryApiService {
  static final ItineraryApiService _instance = ItineraryApiService._internal();
  factory ItineraryApiService() => _instance;
  ItineraryApiService._internal();

  static const String _appliedItinerariesBaseKey = 'user_applied_itinerary_ids';
  static const String _customItinerariesBaseKey = 'user_custom_applied_itineraries_v2';

  Future<String> _getAppliedItinerariesKey() async => await AuthService().getScopedKey(_appliedItinerariesBaseKey);
  Future<String> _getCustomItinerariesKey() async => await AuthService().getScopedKey(_customItinerariesBaseKey);

  /// Lấy danh sách ID các lịch trình đã áp dụng từ bộ nhớ SharedPreferences và backend
  Future<Set<int>> getAppliedItineraryIds() async {
    try {
      final key = await _getAppliedItinerariesKey();
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key) ?? [];
      return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Lấy danh sách lịch trình tự tạo / đã áp dụng tùy chỉnh từ bộ nhớ local
  Future<List<ItineraryModel>> getCustomItineraries() async {
    try {
      final key = await _getCustomItinerariesKey();
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getStringList(key) ?? [];
      return listStr.map((str) {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return ItineraryModel.fromJson(decoded);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Lưu lịch trình vào danh sách custom
  Future<void> saveCustomItinerary(ItineraryModel item) async {
    try {
      final key = await _getCustomItinerariesKey();
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getStringList(key) ?? [];
      final existing = listStr.map((str) {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return ItineraryModel.fromJson(decoded);
      }).toList();

      existing.removeWhere((i) => i.id == item.id);
      existing.insert(0, item);

      final encodedList = existing.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(key, encodedList);
    } catch (_) {}
  }

  /// Thêm địa điểm vào chuyến đi cụ thể của người dùng (cập nhật local & gọi backend API)
  Future<bool> addPlaceToTrip({
    required int tripId,
    required int dayNumber,
    required String placeName,
    int? placeId,
    String? location,
    String? category,
    String? coverUrl,
    String startTime = '08:00',
    String endTime = '10:00',
    String? note,
    double estimatedCost = 0,
    String transportMode = 'Xe máy',
  }) async {
    try {
      final customList = await getCustomItineraries();
      final index = customList.indexWhere((t) => t.id == tripId);
      if (index == -1) return false;

      final trip = customList[index];
      final days = List<ItineraryDayModel>.from(trip.days);
      int dayIndex = days.indexWhere((d) => d.dayNumber == dayNumber);

      final newStop = ItineraryStopModel(
        id: 'stop-${DateTime.now().millisecondsSinceEpoch}',
        placeId: placeId,
        time: startTime,
        startTime: startTime,
        endTime: endTime,
        activity: placeName,
        location: location ?? '',
        category: category ?? 'Điểm tham quan',
        description: note,
        costEstimate: estimatedCost > 0
            ? '${estimatedCost.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ'
            : 'Miễn phí',
        costEstimateNum: estimatedCost,
        transportMode: transportMode,
        duration: '1.5 giờ',
      );

      if (dayIndex >= 0) {
        final existingDay = days[dayIndex];
        final updatedStops = List<ItineraryStopModel>.from(existingDay.stops)..add(newStop);
        days[dayIndex] = existingDay.copyWith(stops: updatedStops);
      } else {
        days.add(
          ItineraryDayModel(
            dayNumber: dayNumber,
            title: 'Ngày $dayNumber: Khám phá $placeName',
            stops: [newStop],
          ),
        );
      }

      final updatedTrip = trip.copyWith(
        days: days,
        daysCount: days.length,
        duration: '${days.length} Ngày',
      );

      await saveCustomItinerary(updatedTrip);

      // Gọi backend API nếu có token
      try {
        final token = await AuthService().getAccessToken();
        if (token != null && token.isNotEmpty && placeId != null && placeId > 0) {
          final uri = Uri.parse('${ApiConstants.baseUrl}/api/trips/$tripId/days/$dayNumber/places');
          await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'placeId': placeId,
              'visitOrder': (dayIndex >= 0 ? days[dayIndex].stops.length : 1),
              'startTime': startTime,
              'endTime': endTime,
              'estimatedCost': estimatedCost,
              'transportMode': transportMode,
              'note': note ?? placeName,
            }),
          ).timeout(const Duration(seconds: 6));
        }
      } catch (_) {}

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Tạo trực tiếp chuyến đi mới trên Database Backend (/api/trips) và trả về ItineraryModel kèm ID thực tế từ SQL Server
  Future<ItineraryModel?> createNewTrip({
    String title = 'Chuyến đi của tôi',
    String? description,
    String? destination = 'Việt Nam',
    String? region = 'Miền Bắc',
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) return null;

      final payload = {
        'title': title.trim().isNotEmpty ? title.trim() : 'Chuyến đi của tôi',
        'description': description ?? 'Lên kế hoạch và lưu lại các địa điểm yêu thích.',
        'coverImageUrl': '',
        'privacy': 1,
        'days': [
          {
            'dayNumber': 1,
            'dayTitle': 'Ngày 1: Bắt đầu hành trình',
            'stops': [],
          }
        ],
      };

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/trips');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final data = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded) : null;
        final newId = data != null && data['id'] != null ? (data['id'] as num).toInt() : null;

        if (newId != null && newId > 0) {
          final newTrip = ItineraryModel(
            id: newId,
            title: title.trim().isNotEmpty ? title.trim() : 'Chuyến đi của tôi',
            destination: destination ?? 'Việt Nam',
            region: region ?? 'Miền Bắc',
            duration: '1 Ngày',
            daysCount: 1,
            nightsCount: 0,
            style: 'Riêng tư',
            estimatedCost: '0đ',
            estimatedBudgetNum: 0,
            author: const ItineraryAuthorModel(
              name: 'Bạn',
              rank: 'Chủ chuyến đi',
            ),
            overview: description ?? 'Lên kế hoạch và lưu lại các địa điểm yêu thích.',
            days: const [
              ItineraryDayModel(
                dayNumber: 1,
                title: 'Ngày 1: Bắt đầu hành trình',
                stops: [],
              ),
            ],
            backlogStops: const [],
            members: const [],
            tags: const [],
          );

          await saveCustomItinerary(newTrip);
          final appliedKey = await _getAppliedItinerariesKey();
          final prefs = await SharedPreferences.getInstance();
          final current = prefs.getStringList(appliedKey) ?? [];
          final set = current.toSet();
          set.add(newTrip.id.toString());
          await prefs.setStringList(appliedKey, set.toList());

          return newTrip;
        }
      } else if (response.statusCode == 401) {
        await AuthService().logout();
      }
    } catch (_) {}
    return null;
  }

  /// Áp dụng hoặc bỏ áp dụng lịch trình chuyến đi (Tạo bản ghi trong bảng Trips của database)
  Future<bool> applyItinerary(int id, {ItineraryModel? itinerary, bool isApplying = true}) async {
    try {
      final appliedKey = await _getAppliedItinerariesKey();
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(appliedKey) ?? [];
      final set = current.toSet();
      if (isApplying) {
        set.add(id.toString());
      } else {
        set.remove(id.toString());
      }
      await prefs.setStringList(appliedKey, set.toList());
    } catch (_) {}

    if (itinerary != null && isApplying) {
      await saveCustomItinerary(itinerary);
    }

    // Đồng bộ vào FavoriteApiService (TargetType 3: Lịch trình chuyến đi)
    if (isApplying) {
      await FavoriteApiService().addFavorite(
        targetType: 3, // Itinerary
        targetId: id,
        title: itinerary?.title ?? 'Lịch trình #$id',
        subtitle: itinerary?.destination ?? '',
        coverImg: itinerary?.coverUrl ?? '',
        categoryTag: itinerary?.duration ?? 'Lịch trình',
        rating: 5.0,
      );
    }

    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        // Mất token / Chưa đăng nhập: không thể lưu vào database
        return false;
      }

      if (isApplying) {
        final payload = {
          'title': (itinerary != null && itinerary.title.trim().isNotEmpty)
              ? itinerary.title.trim()
              : 'Chuyến đi của tôi',
          'description': itinerary?.overview ?? itinerary?.description ?? 'Lên kế hoạch và lưu lại các địa điểm yêu thích.',
          'coverImageUrl': itinerary?.coverUrl ?? '',
          'privacy': 1,
          if (itinerary != null && itinerary.days.isNotEmpty)
            'days': itinerary.days.map((d) {
              return {
                'dayNumber': d.dayNumber,
                'dayTitle': d.title,
                if (d.date != null && d.date!.isNotEmpty) 'date': d.date,
                'stops': d.stops.asMap().entries.map((e) {
                  final idx = e.key;
                  final s = e.value;
                  final parsedId = int.tryParse(s.id);
                  final stopPlaceId = (s.placeId != null && s.placeId! > 0)
                      ? s.placeId!
                      : (parsedId != null && parsedId > 0 && parsedId <= 100 ? parsedId : ((idx % 10) + 1));
                  return {
                    'placeId': stopPlaceId,
                    'visitOrder': s.visitOrder > 0 ? s.visitOrder : (idx + 1),
                    'startTime': s.startTime.isNotEmpty ? s.startTime : (s.time.isNotEmpty ? s.time : '08:00'),
                    'endTime': s.endTime.isNotEmpty ? s.endTime : '10:00',
                    'estimatedCost': s.costEstimateNum > 0 ? s.costEstimateNum : 50000,
                    'transportMode': s.transportMode.isNotEmpty ? s.transportMode : 'Xe máy',
                    'note': (s.description != null && s.description!.isNotEmpty) ? s.description : s.activity,
                  };
                }).toList(),
              };
            }).toList(),
        };

        final uri = Uri.parse('${ApiConstants.baseUrl}/api/trips');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          final data = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded) : null;
          if (data != null && data['id'] != null) {
            final int newId = (data['id'] as num).toInt();
            if (itinerary != null) {
              final updated = itinerary.copyWith(id: newId);
              await saveCustomItinerary(updated);
            }
          }
          return true;
        } else if (response.statusCode == 401) {
          // Token hết hạn / không hợp lệ: đăng xuất để yêu cầu đăng nhập lại
          await AuthService().logout();
          return false;
        }
      } else {
        // Hủy áp dụng: xóa chuyến đi hoặc xóa khỏi favorites
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/trips/$id');
        final response = await http.delete(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 401) {
          await AuthService().logout();
          return false;
        }
      }
    } catch (_) {}

    return true;
  }

  /// Lấy danh sách lịch trình từ database qua API backend (/api/itineraries)
  Future<List<ItineraryModel>> getItineraries({
    String? duration,
    String? keyword,
    String? region,
    String? budget,
    int page = 1,
    int pageSize = 50,
  }) async {
    List<ItineraryModel> rawBackendList = [];
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
          rawBackendList = items.map((e) => ItineraryModel.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    // Fallback: nếu backend trống hoặc không kết nối được, sử dụng trọn bộ 10 lịch trình chuẩn từ MockData
    if (rawBackendList.isEmpty) {
      rawBackendList = List.from(MockData.itineraries);
    }

    // 2. Hợp nhất với các lịch trình người dùng đã áp dụng từ các tỉnh thành / tùy chỉnh
    final customList = await getCustomItineraries();
    final combinedMap = <int, ItineraryModel>{};
    for (final item in rawBackendList) {
      combinedMap[item.id] = item;
    }
    for (final c in customList) {
      combinedMap[c.id] = c;
    }

    List<ItineraryModel> list = combinedMap.values.toList();

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

    // Fallback: Tìm trong danh sách lịch trình tự tạo / đã áp dụng của user
    try {
      final customList = await getCustomItineraries();
      return customList.firstWhere((item) => item.id == id);
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

  /// Mời thành viên vào chuyến đi qua email (gọi API backend /api/trips/{tripId}/members)
  Future<Map<String, dynamic>> inviteMember(int tripId, {required String email, String role = 'Editor'}) async {
    try {
      final token = await AuthService().getAccessToken();
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/trips/$tripId/members');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = jsonEncode({
        'email': email.trim(),
        'role': role,
      });

      final response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 8));
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': (decoded is Map<String, dynamic> ? decoded['message'] : null) ?? 'Đã thêm thành viên vào chuyến đi thành công.',
          'data': decoded is Map<String, dynamic> ? decoded['data'] : null,
        };
      } else {
        String errorMsg = 'Không thể mời thành viên.';
        if (decoded is Map<String, dynamic>) {
          errorMsg = decoded['message'] ?? decoded['error'] ?? (decoded['errors'] != null ? decoded['errors'].toString() : errorMsg);
        }
        return {
          'success': false,
          'message': errorMsg,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ: $e',
      };
    }
  }

  /// Xóa thành viên khỏi chuyến đi (/api/trips/{tripId}/members/{userId})
  Future<bool> removeMember(int tripId, int memberUserId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) return false;

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/trips/$tripId/members/$memberUserId');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return true; // Optimistic fallback
    }
  }

  /// Xuất bản chuyến đi công khai (POST /api/trips/{id}/publish)
  Future<ApiResponse<bool>> publishTrip(
    int tripId, {
    required String description,
    String? title,
    String? coverUrl,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/trips/$tripId/publish');

      var request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      request.fields['description'] = description.trim();
      if (title != null && title.trim().isNotEmpty) {
        request.fields['title'] = title.trim();
      }
      if (coverUrl != null && coverUrl.trim().isNotEmpty) {
        request.fields['coverImageUrl'] = coverUrl.trim();
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Map<String, dynamic>? decoded;
        try {
          decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
        } catch (_) {}

        return ApiResponse<bool>(
          success: true,
          message: decoded?['message']?.toString() ?? 'Xuất bản chuyến đi công khai thành công.',
          data: true,
        );
      } else {
        Map<String, dynamic>? decoded;
        try {
          decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
        } catch (_) {}

        return ApiResponse<bool>(
          success: false,
          message: decoded?['message']?.toString() ?? 'Lỗi khi xuất bản chuyến đi (${response.statusCode})',
          data: false,
        );
      }
    } catch (e) {
      return ApiResponse<bool>(
        success: false,
        message: 'Không thể kết nối đến máy chủ: $e',
        data: false,
      );
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

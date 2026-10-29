import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/report_model.dart';
import 'auth_service.dart';

class ReportApiService {
  static final ReportApiService _instance = ReportApiService._internal();
  factory ReportApiService() => _instance;
  ReportApiService._internal();

  static const String _localReportsBaseKey = 'local_submitted_reports_v1';

  Future<String> _getLocalReportsKey() async => await AuthService().getScopedKey(_localReportsBaseKey);

  // ==================== DEFAULT FALLBACK REASONS ====================
  static final Map<ReportTargetType, List<ReportReasonModel>> _defaultReasons = {
    ReportTargetType.place: [
      const ReportReasonModel(
        id: 1,
        code: 'PLACE_CLOSED',
        name: 'Địa điểm đã đóng cửa vĩnh viễn / Tạm dừng hoạt động',
        description: 'Cơ sở đã ngừng kinh doanh hoặc di dời sang địa chỉ khác.',
        targetType: 'place',
      ),
      const ReportReasonModel(
        id: 2,
        code: 'PLACE_WRONG_INFO',
        name: 'Thông tin không chính xác (Địa chỉ, giá vé, giờ mở cửa, SĐT)',
        description: 'Vị trí bản đồ sai lệch hoặc thông tin dịch vụ không đúng thực tế.',
        targetType: 'place',
      ),
      const ReportReasonModel(
        id: 3,
        code: 'PLACE_WRONG_PRICE',
        name: 'Sai khung giờ mở cửa hoặc mức giá ước tính',
        description: 'Giá cả thực tế khác biệt quá lớn so với thông tin niêm yết.',
        targetType: 'place',
      ),
      const ReportReasonModel(
        id: 4,
        code: 'PLACE_DUPLICATE',
        name: 'Địa điểm bị trùng lặp',
        description: 'Địa điểm này đã có sẵn trên hệ thống LangThang.',
        targetType: 'place',
      ),
      const ReportReasonModel(
        id: 5,
        code: 'CONTENT_SPAM',
        name: 'Spam / Quảng cáo lừa đảo / Chèo kéo khách',
        description: 'Địa điểm ảo lập ra để trục lợi hoặc quảng bá sai sự thật.',
        targetType: 'place',
      ),
      const ReportReasonModel(
        id: 10,
        code: 'OTHER',
        name: 'Lý do khác',
        description: 'Các vi phạm khác cần quản trị viên kiểm tra và xử lý.',
        targetType: 'place',
      ),
    ],
    ReportTargetType.review: [
      const ReportReasonModel(
        id: 6,
        code: 'CONTENT_OFFENSIVE',
        name: 'Ngôn từ xúc phạm, thô tục hoặc công kích cá nhân',
        description: 'Đánh giá mang tính bôi nhọ, đe dọa hoặc dùng từ ngữ không văn minh.',
        targetType: 'review',
      ),
      const ReportReasonModel(
        id: 5,
        code: 'CONTENT_SPAM',
        name: 'Spam, quảng cáo dịch vụ khác hoặc nội dung vô nghĩa',
        description: 'Đánh giá chèn link quảng cáo hoặc không liên quan đến trải nghiệm.',
        targetType: 'review',
      ),
      const ReportReasonModel(
        id: 7,
        code: 'CONTENT_FAKE',
        name: 'Đánh giá ảo / Trải nghiệm giả mạo dìm hàng hoặc seeding',
        description: 'Tài khoản bot hoặc đánh giá không trung thực.',
        targetType: 'review',
      ),
      const ReportReasonModel(
        id: 9,
        code: 'CONTENT_COPYRIGHT',
        name: 'Hình ảnh vi phạm bản quyền hoặc giả mạo ảnh người khác',
        description: 'Sử dụng hình ảnh không có sự đồng ý của tác giả.',
        targetType: 'review',
      ),
      const ReportReasonModel(
        id: 10,
        code: 'OTHER',
        name: 'Lý do khác',
        description: 'Vi phạm các tiêu chuẩn cộng đồng khác.',
        targetType: 'review',
      ),
    ],
    ReportTargetType.comment: [
      const ReportReasonModel(
        id: 6,
        code: 'CONTENT_OFFENSIVE',
        name: 'Quấy rối, đe dọa, xúc phạm danh dự hoặc kích động thù hằn',
        description: 'Bình luận mang tính chất tấn công người dùng khác.',
        targetType: 'comment',
      ),
      const ReportReasonModel(
        id: 5,
        code: 'CONTENT_SPAM',
        name: 'Spam link rác, lừa đảo hoặc bán hàng rong',
        description: 'Chèn đường dẫn độc hại hoặc quảng cáo không liên quan.',
        targetType: 'comment',
      ),
      const ReportReasonModel(
        id: 10,
        code: 'OTHER',
        name: 'Lý do khác',
        description: 'Các hành vi vi phạm chuẩn mực trao đổi.',
        targetType: 'comment',
      ),
    ],
    ReportTargetType.blog: [
      const ReportReasonModel(
        id: 9,
        code: 'CONTENT_COPYRIGHT',
        name: 'Vi phạm bản quyền hình ảnh hoặc đạo nhái bài viết',
        description: 'Bài viết sao chép từ nguồn khác mà không ghi nguồn hoặc xin phép.',
        targetType: 'blog',
      ),
      const ReportReasonModel(
        id: 7,
        code: 'CONTENT_FAKE',
        name: 'Thông tin du lịch sai sự thật, gây hiểu lầm nghiêm trọng',
        description: 'Chia sẻ chỉ dẫn sai gây nguy hiểm hoặc tốn kém cho du khách.',
        targetType: 'blog',
      ),
      const ReportReasonModel(
        id: 5,
        code: 'CONTENT_SPAM',
        name: 'Spam quảng cáo, chèo kéo hoặc nội dung vô nghĩa',
        description: 'Bài viết nhằm mục đích lừa đảo hoặc tiếp thị dịch vụ bất hợp pháp.',
        targetType: 'blog',
      ),
      const ReportReasonModel(
        id: 6,
        code: 'CONTENT_OFFENSIVE',
        name: 'Ngôn từ thô tục, xúc phạm hoặc kích động',
        description: 'Bài viết chứa ngôn từ không phù hợp thuần phong mỹ tục.',
        targetType: 'blog',
      ),
      const ReportReasonModel(
        id: 8,
        code: 'CONTENT_NSFW_MEDIA',
        name: 'Hình ảnh nhạy cảm, bạo lực hoặc vi phạm thuần phong mỹ tục',
        description: 'Hình ảnh chứa nội dung nhạy cảm hoặc không lành mạnh.',
        targetType: 'blog',
      ),
      const ReportReasonModel(
        id: 10,
        code: 'OTHER',
        name: 'Lý do khác / Đề xuất cập nhật khác',
        description: 'Các vi phạm khác đối với cẩm nang du lịch.',
        targetType: 'blog',
      ),
    ],
    ReportTargetType.food: [
      const ReportReasonModel(
        id: 7,
        code: 'CONTENT_FAKE',
        name: 'Thông tin món ăn sai lệch / Không phải đặc sản địa phương',
        description: 'Món ăn bị gán sai vùng miền hoặc công thức không chuẩn xác.',
        targetType: 'food',
      ),
      const ReportReasonModel(
        id: 8,
        code: 'CONTENT_NSFW_MEDIA',
        name: 'Hình ảnh món ăn phản cảm hoặc vi phạm bản quyền',
        description: 'Hình ảnh chất lượng kém, sai món hoặc ảnh đánh cắp.',
        targetType: 'food',
      ),
      const ReportReasonModel(
        id: 10,
        code: 'OTHER',
        name: 'Lý do khác',
        description: 'Các vấn đề vi phạm khác liên quan đến món ăn.',
        targetType: 'food',
      ),
    ],
    ReportTargetType.photo: [
      const ReportReasonModel(
        id: 8,
        code: 'CONTENT_NSFW_MEDIA',
        name: 'Ảnh phản cảm / Vi phạm thuần phong mỹ tục',
        description: 'Hình ảnh chứa nội dung nhạy cảm hoặc không lành mạnh.',
        targetType: 'photo',
      ),
      const ReportReasonModel(
        id: 2,
        code: 'PLACE_WRONG_INFO',
        name: 'Ảnh không đúng địa điểm',
        description: 'Ảnh chụp nơi khác bị tải lên nhầm địa điểm này.',
        targetType: 'photo',
      ),
      const ReportReasonModel(
        id: 9,
        code: 'CONTENT_COPYRIGHT',
        name: 'Vi phạm quyền sở hữu trí tuệ',
        description: 'Sử dụng ảnh tác quyền không xin phép.',
        targetType: 'photo',
      ),
    ],
  };

  // ==================== 1. GET REASONS ====================
  Future<ApiResponse<List<ReportReasonModel>>> getReportReasons({ReportTargetType? targetType}) async {
    final type = targetType ?? ReportTargetType.place;
    final fallbackList = _defaultReasons[type] ?? _defaultReasons[ReportTargetType.place]!;

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/reports/reasons').replace(
        queryParameters: targetType != null ? {'targetType': type.apiTargetType} : null,
      );

      final token = await AuthService().getAccessToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final dynamic raw = json is Map ? (json['data'] ?? json['items']) : json;
        if (raw is List && raw.isNotEmpty) {
          final list = raw.map((e) => ReportReasonModel.fromJson(e as Map<String, dynamic>)).toList();
          return ApiResponse<List<ReportReasonModel>>(success: true, message: 'OK', data: list);
        }
      }
    } catch (e) {
      debugPrint('[ReportApiService] getReportReasons error (using fallback): $e');
    }

    return ApiResponse<List<ReportReasonModel>>(
      success: true,
      message: 'OK (Cached)',
      data: fallbackList,
    );
  }

  // ==================== 2. SUBMIT REPORT ====================
  Future<ApiResponse<SubmittedUserReport>> submitReport({
    required ReportTargetInfo targetInfo,
    required String reasonCode,
    required String reasonName,
    int? reasonId,
    required String description,
    String? evidenceUrl,
    String? contactEmail,
  }) async {
    final reportId = DateTime.now().millisecondsSinceEpoch % 1000000;
    final formattedTime = 'Vừa xong';

    final newReport = SubmittedUserReport(
      id: reportId,
      targetType: targetInfo.targetType,
      targetTitle: targetInfo.targetTitle,
      reasonContent: reasonName,
      description: description.trim().isNotEmpty ? description.trim() : 'Người dùng gửi báo cáo vi phạm.',
      submittedAt: formattedTime,
      status: 'pending',
      evidenceUrl: evidenceUrl,
    );

    // 1. Check Authentication Token
    final token = await AuthService().getAccessToken();
    if (token == null || token.isEmpty || token.startsWith('google_session_token_')) {
      return ApiResponse<SubmittedUserReport>(
        success: false,
        message: 'Bạn cần đăng nhập để gửi báo cáo vi phạm và lưu vào cơ sở dữ liệu hệ thống.',
        code: '401',
      );
    }

    // Resolve valid numeric reasonId matching database dbo.ReportTypes
    int resolvedReasonId = reasonId ?? 0;
    if (resolvedReasonId <= 0) {
      switch (reasonCode) {
        case 'PLACE_CLOSED':
        case 'CLOSED':
          resolvedReasonId = 1;
          break;
        case 'PLACE_WRONG_INFO':
        case 'WRONG_INFO':
          resolvedReasonId = 2;
          break;
        case 'PLACE_WRONG_PRICE':
          resolvedReasonId = 3;
          break;
        case 'PLACE_DUPLICATE':
        case 'DUPLICATE_PLACE':
          resolvedReasonId = 4;
          break;
        case 'CONTENT_SPAM':
        case 'SPAM_SCAM':
        case 'SPAM_ADVERTISING':
        case 'SPAM_LINKS':
        case 'COMMERCIAL_SCAM':
          resolvedReasonId = 5;
          break;
        case 'CONTENT_OFFENSIVE':
        case 'OFFENSIVE_LANGUAGE':
        case 'HARASSMENT':
          resolvedReasonId = 6;
          break;
        case 'CONTENT_FAKE':
        case 'FAKE_REVIEW':
        case 'MISLEADING_INFO':
        case 'WRONG_FOOD_INFO':
          resolvedReasonId = 7;
          break;
        case 'CONTENT_NSFW_MEDIA':
        case 'INAPPROPRIATE_CONTENT':
        case 'INAPPROPRIATE_PHOTO':
        case 'INAPPROPRIATE_IMAGE':
          resolvedReasonId = 8;
          break;
        case 'CONTENT_COPYRIGHT':
        case 'COPYRIGHT_PHOTO':
        case 'COPYRIGHT_INFRINGEMENT':
          resolvedReasonId = 9;
          break;
        default:
          resolvedReasonId = 10;
          break;
      }
    }

    // 2. Send to Backend Universal Report API: POST /api/reports
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final payload = {
        'targetType': targetInfo.targetType.apiTargetType.toLowerCase(),
        'targetId': targetInfo.targetId,
        'reasonId': resolvedReasonId,
        'reason': reasonName,
        'description': description.trim(),
        'notes': description.trim(),
        'evidenceUrl': evidenceUrl,
        'contactEmail': contactEmail,
      };

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/reports');
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      debugPrint('[ReportApiService] POST $uri -> HTTP ${res.statusCode}: ${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Saved to SQL database successfully!
        await _saveLocalReport(newReport);
        return ApiResponse<SubmittedUserReport>(
          success: true,
          message: 'Báo cáo của bạn đã được gửi thành công và lưu vào hệ thống.',
          data: newReport,
        );
      } else if (res.statusCode == 401) {
        return ApiResponse<SubmittedUserReport>(
          success: false,
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          code: '401',
        );
      } else {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final msg = decoded is Map ? (decoded['message'] ?? decoded['title'] ?? 'Lỗi từ máy chủ') : 'Lỗi từ máy chủ (${res.statusCode})';
        return ApiResponse<SubmittedUserReport>(
          success: false,
          message: msg.toString(),
          code: res.statusCode.toString(),
        );
      }
    } catch (e) {
      debugPrint('[ReportApiService] submitReport error: $e');
      return ApiResponse<SubmittedUserReport>(
        success: false,
        message: 'Không thể kết nối đến máy chủ Backend để lưu báo cáo: $e',
      );
    }
  }

  // ==================== 3. GET MY REPORTS ====================
  Future<ApiResponse<List<SubmittedUserReport>>> getMyReports() async {
    final List<SubmittedUserReport> result = [];
    final Set<int> seenIds = {};

    // 1. Fetch from backend: GET /api/reports/my-reports
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/reports/my-reports');
        final res = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final json = jsonDecode(utf8.decode(res.bodyBytes));
          final dynamic raw = json is Map ? (json['data'] ?? json['items']) : json;
          if (raw is List) {
            for (final item in raw) {
              final rep = SubmittedUserReport.fromJson(item as Map<String, dynamic>);
              if (seenIds.add(rep.id)) {
                result.add(rep);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ReportApiService] getMyReports API error: $e');
    }

    // 2. Merge local stored reports
    final localList = await _getLocalReports();
    for (final item in localList) {
      if (seenIds.add(item.id)) {
        result.insert(0, item);
      }
    }

    return ApiResponse<List<SubmittedUserReport>>(
      success: true,
      message: 'OK',
      data: result,
    );
  }

  // ==================== LOCAL STORAGE HELPERS ====================
  Future<List<SubmittedUserReport>> _getLocalReports() async {
    try {
      final key = await _getLocalReportsKey();
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key) ?? [];
      return list.map((str) => SubmittedUserReport.fromJson(jsonDecode(str) as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalReport(SubmittedUserReport report) async {
    try {
      final key = await _getLocalReportsKey();
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key) ?? [];
      list.insert(0, jsonEncode(report.toJson()));
      // Keep at most 50 local reports
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }
      await prefs.setStringList(key, list);
    } catch (_) {}
  }
}

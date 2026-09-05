import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _tokenKey = 'auth_access_token';
  static const String _userKey = 'auth_user_data';

  static MediaType _getImageMediaType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  Future<ApiResponse<UserModel>> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300 && json['success'] == true) {
        final data = json['data'] as Map<String, dynamic>;
        final token = data['accessToken']?.toString();
        final userJson = data['user'] as Map<String, dynamic>? ?? {};

        final user = UserModel.fromJson(userJson);

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, token);
          await prefs.setString(_userKey, jsonEncode(user.toJson()));
        }

        return ApiResponse<UserModel>(
          success: true,
          message: json['message'] as String? ?? 'Đăng nhập thành công',
          data: user,
        );
      } else {
        return ApiResponse<UserModel>.fromJson(
          json,
          (d) => UserModel.fromJson(d as Map<String, dynamic>),
        );
      }
    } catch (e) {
      return ApiResponse<UserModel>(
        success: false,
        message: 'Không thể kết nối đến máy chủ: $e',
      );
    }
  }

  Future<ApiResponse<dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': fullName.trim(),
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300 && json['success'] == true) {
        return ApiResponse<dynamic>(
          success: true,
          message: json['message'] as String? ?? 'Đăng ký tài khoản thành công',
          data: json['data'],
        );
      } else {
        return ApiResponse<dynamic>.fromJson(json, (d) => d);
      }
    } catch (e) {
      return ApiResponse<dynamic>(
        success: false,
        message: 'Không thể kết nối đến máy chủ: $e',
      );
    }
  }

  Future<ApiResponse<UserModel>> getProfile() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<UserModel>(
          success: false,
          message: 'Chưa đăng nhập',
        );
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode == 200 && json['success'] == true) {
        final user = UserModel.fromJson(json['data'] as Map<String, dynamic>);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(user.toJson()));

        return ApiResponse<UserModel>(
          success: true,
          message: json['message'] as String? ?? 'Thành công',
          data: user,
        );
      } else {
        return ApiResponse<UserModel>.fromJson(
          json,
          (d) => UserModel.fromJson(d as Map<String, dynamic>),
        );
      }
    } catch (e) {
      return ApiResponse<UserModel>(
        success: false,
        message: 'Lỗi khi tải thông tin tài khoản: $e',
      );
    }
  }

  Future<ApiResponse<UserModel>> updateProfile({
    required String fullName,
    String? phone,
    String? bio,
    String? avatarFilePath,
    String? coverFilePath,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<UserModel>(
          success: false,
          message: 'Chưa đăng nhập',
        );
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
      
      final request = http.MultipartRequest('PUT', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['FullName'] = fullName.trim();
      if (phone != null) {
        request.fields['Phone'] = phone.trim();
      }
      if (bio != null) {
        request.fields['Bio'] = bio.trim();
      }

      if (avatarFilePath != null && avatarFilePath.isNotEmpty) {
        final mediaType = _getImageMediaType(avatarFilePath);
        final file = File(avatarFilePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final ext = avatarFilePath.split('.').last.toLowerCase();
          request.files.add(http.MultipartFile.fromBytes(
            'AvatarFile',
            bytes,
            filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext',
            contentType: mediaType,
          ));
        }
      }
      if (coverFilePath != null && coverFilePath.isNotEmpty) {
        final mediaType = _getImageMediaType(coverFilePath);
        final file = File(coverFilePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final ext = coverFilePath.split('.').last.toLowerCase();
          request.files.add(http.MultipartFile.fromBytes(
            'CoverFile',
            bytes,
            filename: 'cover_${DateTime.now().millisecondsSinceEpoch}.$ext',
            contentType: mediaType,
          ));
        }
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      final responseBody = utf8.decode(response.bodyBytes).trim();
      if (responseBody.isEmpty) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return const ApiResponse<UserModel>(
            success: true,
            message: 'Cập nhật thông tin thành công',
          );
        }
        return ApiResponse<UserModel>(
          success: false,
          message: 'Máy chủ phản hồi rỗng (Mã lỗi HTTP: ${response.statusCode})',
        );
      }

      final dynamic decodedJson = jsonDecode(responseBody);
      if (decodedJson is Map<String, dynamic>) {
        if (response.statusCode >= 200 && response.statusCode < 300 && decodedJson['success'] == true) {
          final user = UserModel.fromJson(decodedJson['data'] as Map<String, dynamic>);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userKey, jsonEncode(user.toJson()));

          return ApiResponse<UserModel>(
            success: true,
            message: decodedJson['message'] as String? ?? 'Cập nhật thông tin thành công',
            data: user,
          );
        } else {
          return ApiResponse<UserModel>.fromJson(
            decodedJson,
            (d) => UserModel.fromJson(d as Map<String, dynamic>),
          );
        }
      }

      return ApiResponse<UserModel>(
        success: false,
        message: 'Dữ liệu phản hồi từ máy chủ không hợp lệ',
      );
    } catch (e) {
      return ApiResponse<UserModel>(
        success: false,
        message: 'Lỗi khi cập nhật thông tin: $e',
      );
    }
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      try {
        final json = jsonDecode(userStr) as Map<String, dynamic>;
        return UserModel.fromJson(json);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Kiểm tra trạng thái đã đăng nhập
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Đăng xuất
  Future<void> logout() async {
    try {
      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) {
        final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}

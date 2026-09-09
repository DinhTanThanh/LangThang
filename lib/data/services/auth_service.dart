import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  Future<ApiResponse<UserModel>> loginWithGoogle({
    required String idToken,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.googleLogin}');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idToken': idToken,
              'email': email?.trim().toLowerCase(),
              'fullName': displayName?.trim(),
              'photoUrl': photoUrl,
              'googleId': idToken,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (json['success'] == true && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          final token = data['accessToken']?.toString();
          final userJson = data['user'] as Map<String, dynamic>? ?? {};

          final user = UserModel.fromJson(userJson);

          if (token != null && token.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_tokenKey, token);
            await prefs.setString(_userKey, jsonEncode(user.toJson()));
          }

          return ApiResponse<UserModel>(
            success: true,
            message: json['message'] as String? ?? 'Đăng nhập Google thành công',
            data: user,
          );
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Google endpoint login error: $e');
    }

    if (email != null && email.isNotEmpty) {
      final sanitizedEmail = email.trim().toLowerCase();
      final userFullName = displayName?.isNotEmpty == true ? displayName!.trim() : sanitizedEmail.split('@').first;
      final fallbackPassword = 'GAuth#${sanitizedEmail.hashCode.abs()}@2026!';

      // 1. Try logging in with backend fallback password
      var loginRes = await login(email: sanitizedEmail, password: fallbackPassword);
      if (loginRes.success && loginRes.data != null) {
        return loginRes;
      }

      // 2. If user does not exist on backend, auto-register them
      final regRes = await register(
        fullName: userFullName,
        email: sanitizedEmail,
        password: fallbackPassword,
      );

      if (regRes.success) {
        loginRes = await login(email: sanitizedEmail, password: fallbackPassword);
        if (loginRes.success && loginRes.data != null) {
          return loginRes;
        }
      }

      // 3. If email is already registered on backend with another password,
      // return a clear actionable message to the user
      return ApiResponse<UserModel>(
        success: false,
        message: 'Tài khoản $sanitizedEmail đã được đăng ký bằng Mật khẩu trên hệ thống. Vui lòng nhập Email & Mật khẩu để đăng nhập.',
      );
    }

    return const ApiResponse<UserModel>(
      success: false,
      message: 'Không thể xác thực tài khoản Google với máy chủ. Vui lòng thử lại.',
    );
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

      final cachedUser = await getCachedUser();

      // If this is a local Google session or backend is not required for cached session
      if (token.startsWith('google_session_token_')) {
        if (cachedUser != null) {
          return ApiResponse<UserModel>(
            success: true,
            message: 'Thành công',
            data: cachedUser,
          );
        }
      }

      try {
        final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 8));

        final bodyStr = utf8.decode(response.bodyBytes).trim();
        if (bodyStr.isNotEmpty && response.statusCode == 200) {
          final json = jsonDecode(bodyStr) as Map<String, dynamic>;
          if (json['success'] == true) {
            final user = UserModel.fromJson(json['data'] as Map<String, dynamic>);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_userKey, jsonEncode(user.toJson()));

            return ApiResponse<UserModel>(
              success: true,
              message: json['message'] as String? ?? 'Thành công',
              data: user,
            );
          }
        }
      } catch (_) {}

      // If backend request failed or returned empty, fallback to cached user if available
      if (cachedUser != null) {
        return ApiResponse<UserModel>(
          success: true,
          message: 'Thành công',
          data: cachedUser,
        );
      }

      return const ApiResponse<UserModel>(
        success: false,
        message: 'Không thể tải thông tin tài khoản từ máy chủ',
      );
    } catch (e) {
      final cachedUser = await getCachedUser();
      if (cachedUser != null) {
        return ApiResponse<UserModel>(
          success: true,
          message: 'Thành công',
          data: cachedUser,
        );
      }
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

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    // Call backend logout endpoint if valid token
    try {
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}

    // Sign out from Google session
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}

    // Clear local storage
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}

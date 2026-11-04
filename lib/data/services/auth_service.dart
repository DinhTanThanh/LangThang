import 'dart:async';
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
import 'favorite_api_service.dart';
import 'place_api_service.dart';
import 'chat_api_service.dart';
import 'notification_api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _tokenKey = 'auth_access_token';
  static const String _userKey = 'auth_user_data';

  final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier<UserModel?>(null);
  final StreamController<UserModel?> _userStreamController = StreamController<UserModel?>.broadcast();
  Stream<UserModel?> get onUserUpdated => _userStreamController.stream;
  UserModel? get currentUser => currentUserNotifier.value;

  /// Tạo khóa SharedPreferences cô lập riêng biệt theo ID người dùng
  Future<String> getScopedKey(String baseKey) async {
    final user = await getCachedUser();
    final uid = (user != null && user.id.isNotEmpty)
        ? user.id
        : (currentUser != null && currentUser!.id.isNotEmpty ? currentUser!.id : 'guest');
    return 'u_${uid}_$baseKey';
  }

  /// Xóa sạch in-memory cache khi đổi tài khoản hoặc đăng xuất
  void resetSessionCache() {
    try {
      PlaceApiService.clearSessionCache();
      FavoriteApiService.notifyFavoritesChanged();
      ChatApiService().clearCache();
      NotificationApiService().clearCache();
    } catch (_) {}
  }

  void notifyUserChanged(UserModel? user) {
    currentUserNotifier.value = user;
    if (user == null) {
      try {
        ChatApiService().clearCache();
      } catch (_) {}
    }
    if (!_userStreamController.isClosed) {
      _userStreamController.add(user);
    }
  }

  static MediaType _getImageMediaType(String filenameOrExt) {
    final ext = filenameOrExt.contains('.') ? filenameOrExt.split('.').last.toLowerCase() : filenameOrExt.toLowerCase();
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
          resetSessionCache();
          notifyUserChanged(user);
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
    String? googleId,
  }) async {
    final List<String> candidateBaseUrls = [ApiConstants.baseUrl];
    if (ApiConstants.baseUrl.contains('localhost:') || ApiConstants.baseUrl.contains('10.0.2.2:') || ApiConstants.baseUrl.contains('127.0.0.1:')) {
      for (final port in [5021, 5000, 7027, 7001]) {
        final alt = ApiConstants.baseUrl.replaceAll(RegExp(r':\d+'), ':$port');
        if (!candidateBaseUrls.contains(alt)) {
          candidateBaseUrls.add(alt);
        }
      }
    }

    String? lastErrorMsg;
    for (final base in candidateBaseUrls) {
      try {
        final url = Uri.parse('$base${ApiConstants.googleLogin}');
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'idToken': idToken,
                'email': email?.trim().toLowerCase(),
                'fullName': displayName?.trim(),
                'photoUrl': photoUrl,
                'googleId': googleId ?? idToken,
              }),
            )
            .timeout(const Duration(seconds: 8));

        final json = (response.bodyBytes.isNotEmpty)
            ? jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>? ?? {}
            : <String, dynamic>{};

        if (response.statusCode >= 200 && response.statusCode < 300 && json['success'] == true && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          final token = data['accessToken']?.toString();
          final userJson = data['user'] as Map<String, dynamic>? ?? {};

          final user = UserModel.fromJson(userJson);

          if (token != null && token.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_tokenKey, token);
            await prefs.setString(_userKey, jsonEncode(user.toJson()));
            resetSessionCache();
            notifyUserChanged(user);
          }

          return ApiResponse<UserModel>(
            success: true,
            message: json['message'] as String? ?? 'Đăng nhập Google thành công',
            data: user,
          );
        } else {
          final errorMsg = json['message'] as String? ?? 'Đăng nhập Google thất bại (${response.statusCode})';
          lastErrorMsg = errorMsg;
          debugPrint('[AuthService] Google login failed on $base: $errorMsg');
        }
      } catch (e) {
        debugPrint('[AuthService] Google login attempt on $base failed: $e');
        lastErrorMsg = 'Không thể kết nối đến máy chủ: $e';
      }
    }

    return ApiResponse<UserModel>(
      success: false,
      message: lastErrorMsg ?? 'Không thể xác thực tài khoản Google với máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.',
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
        notifyUserChanged(null);
        return const ApiResponse<UserModel>(
          success: false,
          message: 'Chưa đăng nhập',
        );
      }

      final cachedUser = await getCachedUser();

      if (token.startsWith('google_session_token_')) {
        if (cachedUser != null) {
          notifyUserChanged(cachedUser);
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

        if (response.statusCode == 401 || response.statusCode == 403) {
          // Token expired or invalid -> Clear local session immediately
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_tokenKey);
          await prefs.remove(_userKey);
          resetSessionCache();
          notifyUserChanged(null);

          return const ApiResponse<UserModel>(
            success: false,
            message: 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.',
          );
        }

        if (bodyStr.isNotEmpty && response.statusCode == 200) {
          final json = jsonDecode(bodyStr) as Map<String, dynamic>;
          if (json['success'] == true && json['data'] != null) {
            final user = UserModel.fromJson(json['data'] as Map<String, dynamic>);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_userKey, jsonEncode(user.toJson()));
            notifyUserChanged(user);

            return ApiResponse<UserModel>(
              success: true,
              message: json['message'] as String? ?? 'Thành công',
              data: user,
            );
          }
        }
      } catch (_) {}

      return const ApiResponse<UserModel>(
        success: false,
        message: 'Không thể tải thông tin tài khoản từ máy chủ',
      );
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
    Uint8List? avatarBytes,
    String? avatarFileName,
    Uint8List? coverBytes,
    String? coverFileName,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<UserModel>(
          success: false,
          message: 'Chưa đăng nhập',
        );
      }

      final cachedUser = await getCachedUser();

      // Read avatar bytes if not already provided
      Uint8List? finalAvatarBytes = avatarBytes;
      String finalAvatarName = avatarFileName ?? 'avatar.jpg';
      if (finalAvatarBytes == null && avatarFilePath != null && avatarFilePath.isNotEmpty) {
        try {
          final file = File(avatarFilePath);
          if (await file.exists()) {
            finalAvatarBytes = await file.readAsBytes();
            finalAvatarName = avatarFilePath.split(Platform.pathSeparator).last;
          }
        } catch (_) {}
      }

      // Read cover bytes if not already provided
      Uint8List? finalCoverBytes = coverBytes;
      String finalCoverName = coverFileName ?? 'cover.jpg';
      if (finalCoverBytes == null && coverFilePath != null && coverFilePath.isNotEmpty) {
        try {
          final file = File(coverFilePath);
          if (await file.exists()) {
            finalCoverBytes = await file.readAsBytes();
            finalCoverName = coverFilePath.split(Platform.pathSeparator).last;
          }
        } catch (_) {}
      }

      // List candidate base URLs to try if local dev
      final List<String> candidateBaseUrls = [ApiConstants.baseUrl];
      if (ApiConstants.baseUrl.contains('localhost:') || ApiConstants.baseUrl.contains('10.0.2.2:') || ApiConstants.baseUrl.contains('127.0.0.1:')) {
        for (final port in [5000, 5021, 7027, 7001]) {
          final alt = ApiConstants.baseUrl.replaceAll(RegExp(r':\d+'), ':$port');
          if (!candidateBaseUrls.contains(alt)) {
            candidateBaseUrls.add(alt);
          }
        }
      }

      bool networkSucceeded = false;
      UserModel? serverUser;
      String? serverMessage;

      for (final base in candidateBaseUrls) {
        try {
          final url = Uri.parse('$base${ApiConstants.profile}');
          final request = http.MultipartRequest('PUT', url);
          request.headers['Authorization'] = 'Bearer $token';
          request.fields['FullName'] = fullName.trim();
          if (phone != null) {
            request.fields['Phone'] = phone.trim();
          }
          if (bio != null) {
            request.fields['Bio'] = bio.trim();
          }

          if (finalAvatarBytes != null && finalAvatarBytes.isNotEmpty) {
            final mediaType = _getImageMediaType(finalAvatarName);
            final rawExt = finalAvatarName.contains('.') ? finalAvatarName.split('.').last.toLowerCase() : 'jpg';
            final safeExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(rawExt) ? rawExt : 'jpg';
            request.files.add(http.MultipartFile.fromBytes(
              'AvatarFile',
              finalAvatarBytes,
              filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExt',
              contentType: mediaType,
            ));
          }

          if (finalCoverBytes != null && finalCoverBytes.isNotEmpty) {
            final mediaType = _getImageMediaType(finalCoverName);
            final rawExt = finalCoverName.contains('.') ? finalCoverName.split('.').last.toLowerCase() : 'jpg';
            final safeExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(rawExt) ? rawExt : 'jpg';
            request.files.add(http.MultipartFile.fromBytes(
              'CoverFile',
              finalCoverBytes,
              filename: 'cover_${DateTime.now().millisecondsSinceEpoch}.$safeExt',
              contentType: mediaType,
            ));
          }

          final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
          final response = await http.Response.fromStream(streamedResponse);

          final responseBody = utf8.decode(response.bodyBytes).trim();
          if (responseBody.isNotEmpty) {
            final dynamic decodedJson = jsonDecode(responseBody);
            if (decodedJson is Map<String, dynamic>) {
              if (response.statusCode >= 200 && response.statusCode < 300 && decodedJson['success'] == true) {
                serverUser = UserModel.fromJson(decodedJson['data'] as Map<String, dynamic>);
                serverMessage = decodedJson['message'] as String? ?? 'Cập nhật thông tin thành công';
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_userKey, jsonEncode(serverUser.toJson()));
                networkSucceeded = true;
                break;
              } else if (response.statusCode == 400) {
                // Validation error from server
                String msg = decodedJson['message']?.toString() ?? 'Dữ liệu không hợp lệ (${response.statusCode})';
                if (decodedJson['errors'] != null && decodedJson['errors'] is List) {
                  final errList = decodedJson['errors'] as List;
                  if (errList.isNotEmpty) {
                    final firstErr = errList.first;
                    if (firstErr is Map && firstErr['message'] != null) {
                      msg = firstErr['message'].toString();
                    }
                  }
                }
                return ApiResponse<UserModel>(
                  success: false,
                  message: msg,
                );
              }
            }
          }
        } catch (reqError) {
          debugPrint('[AuthService] Update profile attempt on $base failed: $reqError');
        }
      }

      if (networkSucceeded && serverUser != null) {
        notifyUserChanged(serverUser);
        return ApiResponse<UserModel>(
          success: true,
          message: serverMessage ?? 'Cập nhật thông tin thành công',
          data: serverUser,
        );
      }

      // Offline / Local Persistence fallback
      if (cachedUser != null) {
        String updatedAvatarUrl = cachedUser.avatarUrl;
        if (finalAvatarBytes != null && finalAvatarBytes.isNotEmpty) {
          final mime = _getImageMediaType(finalAvatarName).mimeType;
          final base64Image = base64Encode(finalAvatarBytes);
          updatedAvatarUrl = 'data:$mime;base64,$base64Image';
        }

        String updatedCoverUrl = cachedUser.coverUrl;
        if (finalCoverBytes != null && finalCoverBytes.isNotEmpty) {
          final mime = _getImageMediaType(finalCoverName).mimeType;
          final base64Image = base64Encode(finalCoverBytes);
          updatedCoverUrl = 'data:$mime;base64,$base64Image';
        }

        final updatedUser = cachedUser.copyWith(
          fullName: fullName.trim().isNotEmpty ? fullName.trim() : cachedUser.fullName,
          phone: phone?.trim(),
          bio: bio?.trim(),
          avatarUrl: updatedAvatarUrl,
          coverUrl: updatedCoverUrl,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(updatedUser.toJson()));
        notifyUserChanged(updatedUser);

        return ApiResponse<UserModel>(
          success: true,
          message: finalAvatarBytes != null || finalCoverBytes != null
              ? 'Đã cập nhật ảnh hồ sơ thành công!'
              : 'Đã lưu thay đổi thông tin cá nhân!',
          data: updatedUser,
        );
      }

      return const ApiResponse<UserModel>(
        success: false,
        message: 'Không thể kết nối đến máy chủ để tải ảnh lên. Vui lòng kiểm tra lại kết nối.',
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

  Future<String?> getToken() => getAccessToken();

  bool isTokenExpired(String token) {
    try {
      if (token.startsWith('google_session_token_')) return false;
      final parts = token.split('.');
      if (parts.length != 3) return false;
      var payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decodedBytes = base64Url.decode(payload);
      final decodedString = utf8.decode(decodedBytes);
      final map = jsonDecode(decodedString) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp != null) {
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return nowSeconds >= exp;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    // If token is missing or expired, the user is NOT logged in!
    if (token == null || token.isEmpty || isTokenExpired(token)) {
      if (token != null && isTokenExpired(token)) {
        await prefs.remove(_tokenKey);
        await prefs.remove(_userKey);
        resetSessionCache();
      }
      if (currentUserNotifier.value != null) {
        notifyUserChanged(null);
      }
      return null;
    }

    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      try {
        final json = jsonDecode(userStr) as Map<String, dynamic>;
        final user = UserModel.fromJson(json);
        if (currentUserNotifier.value == null) {
          currentUserNotifier.value = user;
        }
        return user;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    final hasToken = token != null && token.isNotEmpty;
    if (!hasToken) {
      if (currentUserNotifier.value != null) {
        notifyUserChanged(null);
      }
      return false;
    }

    if (isTokenExpired(token)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      resetSessionCache();
      notifyUserChanged(null);
      return false;
    }

    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    // 1. Luôn xóa sạch token & thông tin người dùng khỏi local storage trước
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    resetSessionCache();
    notifyUserChanged(null);

    // 2. Gửi yêu cầu đăng xuất lên backend nếu có token
    try {
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}

    // 3. Đăng xuất Google an toàn với timeout và kiểm tra nền tảng (tránh treo trên Windows Desktop)
    try {
      if (kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut().timeout(const Duration(seconds: 2));
      }
    } catch (_) {}
  }

  // ==================== FORGOT PASSWORD & OTP ====================

  /// 1. Gửi mã xác nhận 6 số đến email
  Future<ApiResponse<bool>> sendForgotPasswordOtp(String email) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/auth/forgot-password');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      ).timeout(const Duration(seconds: 12));

      final bodyStr = utf8.decode(res.bodyBytes).trim();
      final json = bodyStr.isNotEmpty ? jsonDecode(bodyStr) as Map<String, dynamic> : <String, dynamic>{};

      if (res.statusCode >= 200 && res.statusCode < 300 && json['success'] == true) {
        return ApiResponse<bool>(
          success: true,
          message: json['message']?.toString() ?? 'Mã xác thực đã được gửi đến email của bạn.',
          data: true,
        );
      } else {
        final errorMsg = json['message']?.toString() ?? 'Không thể gửi mã xác thực. Vui lòng kiểm tra lại email.';
        return ApiResponse<bool>(
          success: false,
          message: errorMsg,
          data: false,
        );
      }
    } catch (e) {
      return ApiResponse<bool>(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        data: false,
      );
    }
  }

  /// 2. Xác thực mã OTP 6 số
  Future<ApiResponse<bool>> verifyForgotPasswordOtp(String email, String otp) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/auth/verify-otp');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final bodyStr = utf8.decode(res.bodyBytes).trim();
      final json = bodyStr.isNotEmpty ? jsonDecode(bodyStr) as Map<String, dynamic> : <String, dynamic>{};

      if (res.statusCode >= 200 && res.statusCode < 300 && json['success'] == true) {
        return ApiResponse<bool>(
          success: true,
          message: json['message']?.toString() ?? 'Xác thực OTP thành công.',
          data: true,
        );
      } else {
        return ApiResponse<bool>(
          success: false,
          message: json['message']?.toString() ?? 'Mã xác thực không chính xác hoặc đã hết hạn.',
          data: false,
        );
      }
    } catch (e) {
      return ApiResponse<bool>(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        data: false,
      );
    }
  }

  /// 3. Đặt lại mật khẩu mới
  Future<ApiResponse<bool>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/auth/reset-password');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 12));

      final bodyStr = utf8.decode(res.bodyBytes).trim();
      final json = bodyStr.isNotEmpty ? jsonDecode(bodyStr) as Map<String, dynamic> : <String, dynamic>{};

      if (res.statusCode >= 200 && res.statusCode < 300 && json['success'] == true) {
        return ApiResponse<bool>(
          success: true,
          message: json['message']?.toString() ?? 'Đổi mật khẩu thành công!',
          data: true,
        );
      } else {
        return ApiResponse<bool>(
          success: false,
          message: json['message']?.toString() ?? 'Không thể cập nhật mật khẩu. Vui lòng thử lại.',
          data: false,
        );
      }
    } catch (e) {
      return ApiResponse<bool>(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        data: false,
      );
    }
  }

  /// 4. Đổi mật khẩu cho người dùng đang đăng nhập
  Future<ApiResponse<bool>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: false,
          message: 'Chưa đăng nhập. Vui lòng đăng nhập lại.',
          data: false,
        );
      }

      final List<String> candidateBaseUrls = [ApiConstants.baseUrl];
      if (ApiConstants.baseUrl.contains('localhost:') || ApiConstants.baseUrl.contains('10.0.2.2:') || ApiConstants.baseUrl.contains('127.0.0.1:')) {
        for (final port in [5000, 5021, 7027, 7001]) {
          final alt = ApiConstants.baseUrl.replaceAll(RegExp(r':\d+'), ':$port');
          if (!candidateBaseUrls.contains(alt)) {
            candidateBaseUrls.add(alt);
          }
        }
      }

      for (final base in candidateBaseUrls) {
        try {
          final url = Uri.parse('$base${ApiConstants.changePassword}');
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
              'confirmPassword': confirmPassword,
            }),
          ).timeout(const Duration(seconds: 10));

          final bodyStr = utf8.decode(response.bodyBytes).trim();
          final json = bodyStr.isNotEmpty ? jsonDecode(bodyStr) as Map<String, dynamic> : <String, dynamic>{};

          if (response.statusCode >= 200 && response.statusCode < 300 && json['success'] == true) {
            return ApiResponse<bool>(
              success: true,
              message: json['message']?.toString() ?? 'Đổi mật khẩu thành công!',
              data: true,
            );
          } else {
            final errorMsg = json['message']?.toString() ?? 'Đổi mật khẩu thất bại. Vui lòng kiểm tra lại mật khẩu hiện tại.';
            return ApiResponse<bool>(
              success: false,
              message: errorMsg,
              data: false,
            );
          }
        } catch (err) {
          debugPrint('[AuthService] changePassword attempt on $base failed: $err');
        }
      }

      return const ApiResponse<bool>(
        success: false,
        message: 'Không thể kết nối đến máy chủ để đổi mật khẩu.',
        data: false,
      );
    } catch (e) {
      return ApiResponse<bool>(
        success: false,
        message: 'Lỗi khi đổi mật khẩu: $e',
        data: false,
      );
    }
  }
}

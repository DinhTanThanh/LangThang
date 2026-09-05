import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  ApiConstants._();

  /// Cho phép tùy chỉnh baseUrl (ví dụ: 'http://192.168.1.10:5000' khi test máy thật)
  static String? customBaseUrl;

  /// Cổng backend phát triển (5000 / 5021 / 7027 / 7001)
  static int devPort = 5000;

  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }
    if (kIsWeb) {
      return 'http://localhost:$devPort';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$devPort';
    }
    return 'http://localhost:$devPort';
  }
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String googleLogin = '/api/auth/google';
  static const String profile = '/api/auth/profile';
  static const String refreshToken = '/api/auth/refresh-token';
  static const String logout = '/api/auth/logout';

  static const String places = '/api/places';
  static const String placeFilterOptions = '/api/places/filter-options';
  static const String categories = '/api/categories';
  static const String regions = '/api/regions';
  static const String provinces = '/api/provinces';
  static const String placeTypes = '/api/place-types';
  static const String featuredCollections = '/api/collections/featured';
}

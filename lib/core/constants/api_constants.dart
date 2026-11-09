import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  ApiConstants._();

  static String? customBaseUrl;

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
  static const String googleClientId = '166166336209-2qs73rtuhd9uvkt2lkuiaq1c472n1l7r.apps.googleusercontent.com';
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String googleLogin = '/api/auth/google';
  static const String profile = '/api/auth/profile';
  static const String changePassword = '/api/auth/change-password';
  static const String refreshToken = '/api/auth/refresh-token';
  static const String logout = '/api/auth/logout';

  static const String places = '/api/places';
  static const String placeFilterOptions = '/api/places/filter-options';
  static const String categories = '/api/categories';
  static const String regions = '/api/regions';
  static const String provinces = '/api/provinces';
  static const String placeTypes = '/api/place-types';
  static const String featuredCollections = '/api/collections/featured';
  static const String favorites = '/api/users/me/favorites';
  static const String systemSettings = '/api/admin/settings/system-settings';
  static String similarPlaces(int placeId) => '/api/recommendations/places/$placeId/similar';
  static String relatedPlaces(int placeId) => '/api/places/$placeId/related';
  static const String personalizedPlaces = '/api/recommendations/places/for-you';
  static const String homeFeed = '/api/recommendations/home-feed';
  static const String recommendedFoods = '/api/recommendations/foods/for-you';
  static String tripSuggestions(int tripId) => '/api/recommendations/trips/$tripId/suggested-places';

  // Notifications
  static const String notifications = '/api/notifications';
  static const String unreadNotificationCount = '/api/notifications/unread-count';
  static String markNotificationAsRead(int id) => '/api/notifications/$id/read';
  static const String markAllNotificationsAsRead = '/api/notifications/read-all';
  static String deleteNotification(int id) => '/api/notifications/$id';

  // Leaderboard / Rankings
  static const String rankingOverview = '/api/rankings/overview';
  static const String rankingDetail = '/api/rankings/detail';
  static const String rankingPlaces = '/api/rankings/places';
  static const String rankingProvinces = '/api/rankings/provinces';
}

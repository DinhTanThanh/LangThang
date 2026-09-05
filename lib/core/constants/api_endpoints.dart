class ApiEndpoints {
  ApiEndpoints._();

  // Base URL cấu hình máy chủ Backend (thay đổi khi deploy)
  static const String baseUrl = 'https://api.langthang.vn/api/v1';

  // Auth endpoints
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String forgotPassword = '$baseUrl/auth/forgot-password';
  static const String changePassword = '$baseUrl/auth/change-password';

  // Destinations endpoints (3 Miền)
  static const String destinations = '$baseUrl/destinations';
  static String destinationDetail(String id) => '$baseUrl/destinations/$id';
  static String destinationsByRegion(String region) => '$baseUrl/destinations?region=$region';

  // Foods endpoints (Ẩm thực)
  static const String foods = '$baseUrl/foods';
  static String foodDetail(String id) => '$baseUrl/foods/$id';

  // Itineraries endpoints (Hành trình)
  static const String itineraries = '$baseUrl/itineraries';
  static String itineraryDetail(String id) => '$baseUrl/itineraries/$id';

  // Blogs endpoints (Cẩm nang)
  static const String blogs = '$baseUrl/blogs';
  static String blogDetail(String id) => '$baseUrl/blogs/$id';

  // User Profile
  static const String userProfile = '$baseUrl/user/profile';
  static const String updateProfile = '$baseUrl/user/update';
  static const String userReviews = '$baseUrl/user/reviews';
  static const String userSaved = '$baseUrl/user/saved';
}

class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'https://api.langthang.vn/api/v1';

  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String forgotPassword = '$baseUrl/auth/forgot-password';
  static const String changePassword = '$baseUrl/auth/change-password';

  static const String destinations = '$baseUrl/destinations';
  static String destinationDetail(String id) => '$baseUrl/destinations/$id';
  static String destinationsByRegion(String region) => '$baseUrl/destinations?region=$region';

  static const String foods = '$baseUrl/foods';
  static String foodDetail(String id) => '$baseUrl/foods/$id';

  static const String itineraries = '$baseUrl/itineraries';
  static String itineraryDetail(String id) => '$baseUrl/itineraries/$id';

  static const String blogs = '$baseUrl/blogs';
  static String blogDetail(String id) => '$baseUrl/blogs/$id';

  static const String userProfile = '$baseUrl/user/profile';
  static const String updateProfile = '$baseUrl/user/update';
  static const String userReviews = '$baseUrl/user/reviews';
  static const String userSaved = '$baseUrl/user/saved';
}

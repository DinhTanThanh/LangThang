import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/blog_model.dart';
import '../mock/mock_data.dart';
import 'auth_service.dart';
import 'favorite_api_service.dart';

class BlogApiService {
  static final BlogApiService _instance = BlogApiService._internal();
  factory BlogApiService() => _instance;
  BlogApiService._internal();

  static const String _savedBlogsKey = 'user_saved_blog_ids';
  static const String _likedBlogsKey = 'user_liked_blog_ids';

  Map<String, dynamic>? _tryDecodeJson(http.Response response) {
    try {
      final raw = utf8.decode(response.bodyBytes).trim();
      if (raw.isNotEmpty && (raw.startsWith('{') || raw.startsWith('['))) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Lấy danh sách bài viết cẩm nang du lịch
  Future<List<BlogModel>> getBlogs({
    String? category,
    String? keyword,
    String? region,
    String? province,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (category != null && category.isNotEmpty && category != 'all' && category != 'Tất cả') {
        queryParams['category'] = category;
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        queryParams['keyword'] = keyword.trim();
      }

      final endpoints = [
        '${ApiConstants.baseUrl}/api/blogs',
        '${ApiConstants.baseUrl}/api/v1/blogs',
      ];

      final token = await AuthService().getAccessToken();
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      for (final endpoint in endpoints) {
        try {
          final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
          final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));

          if (response.statusCode >= 200 && response.statusCode < 300) {
            final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
            final dynamic items = decoded is Map<String, dynamic>
                ? (decoded['data'] ?? decoded['items'])
                : decoded;

            if (items is List && items.isNotEmpty) {
              final rawList = items.map((e) => BlogModel.fromJson(e as Map<String, dynamic>)).toList();
              final savedIds = await getSavedBlogIds();
              final likedIds = await getLikedBlogIds();

              final enrichedList = rawList.map((b) => _enrichBlog(b, likedIds, savedIds)).toList();

              return filterBlogsList(
                enrichedList,
                category: category,
                keyword: keyword,
                region: region,
                province: province,
              );
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[BlogApiService] getBlogs API error: $e');
    }

    // Fallback: Local filtering on MockData.blogs
    return _filterLocalBlogs(
      category: category,
      keyword: keyword,
      region: region,
      province: province,
    );
  }

  /// Làm giàu bài viết với trạng thái Like, Save và tính toán số lượt Like chính xác
  BlogModel _enrichBlog(BlogModel b, Set<String> likedIds, Set<String> savedIds) {
    final isLiked = likedIds.contains(b.id);
    final isSaved = savedIds.contains(b.id);

    int computedLikes = b.likesCount;
    if (isLiked && !b.isLiked) {
      computedLikes = b.likesCount + 1;
    } else if (!isLiked && b.isLiked) {
      computedLikes = b.likesCount > 0 ? b.likesCount - 1 : 0;
    }

    return b.copyWith(
      isSaved: isSaved,
      isLiked: isLiked,
      likesCount: computedLikes,
    );
  }

  /// Lấy bài viết nổi bật (Spotlight / Featured)
  Future<BlogModel?> getFeaturedBlog() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/blogs/featured');
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = _tryDecodeJson(response);
        if (decoded != null && decoded['data'] is Map<String, dynamic>) {
          final blog = BlogModel.fromJson(decoded['data'] as Map<String, dynamic>);
          final savedIds = await getSavedBlogIds();
          final likedIds = await getLikedBlogIds();
          return _enrichBlog(blog, likedIds, savedIds);
        }
      }
    } catch (_) {}

    // Fallback
    try {
      final all = await getBlogs();
      return all.firstWhere((b) => b.featured, orElse: () => all.first);
    } catch (_) {
      return null;
    }
  }

  /// Lấy chi tiết bài viết
  Future<BlogModel?> getBlogDetail(dynamic idOrSlug) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/blogs/$idOrSlug');
      final token = await AuthService().getAccessToken();
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = _tryDecodeJson(response);
        if (decoded != null && decoded['data'] is Map<String, dynamic>) {
          final blog = BlogModel.fromJson(decoded['data'] as Map<String, dynamic>);
          final savedIds = await getSavedBlogIds();
          final likedIds = await getLikedBlogIds();
          return _enrichBlog(blog, likedIds, savedIds);
        }
      }
    } catch (_) {}

    // Fallback: Find in MockData
    try {
      final idStr = idOrSlug.toString();
      final blog = MockData.blogs.firstWhere(
        (b) => b.id == idStr || b.slug == idStr,
        orElse: () => MockData.blogs.first,
      );
      final savedIds = await getSavedBlogIds();
      final likedIds = await getLikedBlogIds();
      return _enrichBlog(blog, likedIds, savedIds);
    } catch (_) {
      return null;
    }
  }

  /// Toggle Like bài viết (Thả tim - Gọi API Backend và cập nhật danh sách Like riêng biệt)
  Future<bool> toggleLike(dynamic blogOrId, {BlogModel? blog}) async {
    String idStr;
    if (blogOrId is BlogModel) {
      idStr = blogOrId.id;
    } else {
      idStr = blogOrId.toString();
    }

    final parsedId = int.tryParse(idStr) ?? (idStr.hashCode.abs() % 100000);
    bool? apiLikedState;

    // 1. Gọi API ToggleLike của backend
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final endpoints = [
          '${ApiConstants.baseUrl}/api/blogs/$parsedId/toggle-like',
          '${ApiConstants.baseUrl}/api/v1/blogs/$parsedId/toggle-like',
        ];
        for (final ep in endpoints) {
          try {
            final res = await http.post(
              Uri.parse(ep),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 3));

            if (res.statusCode >= 200 && res.statusCode < 300) {
              final decoded = _tryDecodeJson(res);
              if (decoded != null && decoded['data'] is Map<String, dynamic>) {
                apiLikedState = decoded['data']['isLiked'] == true;
                break;
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[BlogApiService] toggleLike API error: $e');
    }

    // 2. Cập nhật danh sách liked locally
    final prefs = await SharedPreferences.getInstance();
    final likedList = prefs.getStringList(_likedBlogsKey) ?? [];
    bool nowLiked;

    if (apiLikedState != null) {
      nowLiked = apiLikedState;
      if (nowLiked) {
        if (!likedList.contains(idStr)) likedList.add(idStr);
      } else {
        likedList.remove(idStr);
      }
    } else {
      if (likedList.contains(idStr)) {
        likedList.remove(idStr);
        nowLiked = false;
      } else {
        likedList.add(idStr);
        nowLiked = true;
      }
    }

    await prefs.setStringList(_likedBlogsKey, likedList);

    // Cập nhật trực tiếp vào MockData in-memory
    final mockIndex = MockData.blogs.indexWhere((b) => b.id == idStr || b.slug == idStr);
    if (mockIndex != -1) {
      final old = MockData.blogs[mockIndex];
      final newLikes = nowLiked
          ? (old.isLiked ? old.likesCount : old.likesCount + 1)
          : (old.isLiked ? (old.likesCount > 0 ? old.likesCount - 1 : 0) : old.likesCount);
      MockData.blogs[mockIndex] = old.copyWith(
        isLiked: nowLiked,
        likesCount: newLikes,
      );
    }

    return nowLiked;
  }

  /// Toggle Bookmark / Save bài viết (Lưu bài viết vào danh sách Yêu thích / Database)
  Future<bool> toggleSave(dynamic blogOrId, {BlogModel? blog}) async {
    String idStr;
    BlogModel? blogData = blog;
    if (blogOrId is BlogModel) {
      blogData = blogOrId;
      idStr = blogOrId.id;
    } else {
      idStr = blogOrId.toString();
      try {
        blogData ??= MockData.blogs.firstWhere(
          (b) => b.id == idStr || b.slug == idStr,
          orElse: () => MockData.blogs.first,
        );
      } catch (_) {}
    }

    final parsedId = int.tryParse(idStr) ?? (idStr.hashCode.abs() % 100000);
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList(_savedBlogsKey) ?? [];
    bool nowSaved = false;

    if (savedList.contains(idStr)) {
      savedList.remove(idStr);
      nowSaved = false;
      await FavoriteApiService().removeFavorite(
        targetType: 4,
        targetId: parsedId,
      );
    } else {
      savedList.add(idStr);
      nowSaved = true;
      await FavoriteApiService().addFavorite(
        targetType: 4,
        targetId: parsedId,
        title: blogData?.title ?? 'Bài viết #$parsedId',
        subtitle: blogData != null ? '${blogData.category} • ${blogData.authorName}' : 'Cẩm nang du lịch',
        coverImg: blogData?.imageUrl ?? '',
        categoryTag: blogData?.category ?? 'Cẩm nang',
        rating: 5.0,
      );
    }

    await prefs.setStringList(_savedBlogsKey, savedList);
    return nowSaved;
  }

  /// Danh sách ID bài viết đã lưu (Hợp nhất Local Cache và Database Mục Yêu thích)
  Future<Set<String>> getSavedBlogIds() async {
    final set = <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      set.addAll(prefs.getStringList(_savedBlogsKey) ?? []);
    } catch (_) {}

    try {
      final favRes = await FavoriteApiService().getFavorites(targetType: 4, pageSize: 100);
      if (favRes.success && favRes.data != null) {
        for (final item in favRes.data!.items) {
          set.add(item.targetId.toString());
        }
      }
    } catch (_) {}

    return set;
  }

  /// Danh sách ID bài viết đã like
  Future<Set<String>> getLikedBlogIds() async {
    final set = <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      set.addAll(prefs.getStringList(_likedBlogsKey) ?? []);
    } catch (_) {}

    return set;
  }

  /// Tạo bài viết mới
  Future<bool> createBlog({
    required String title,
    required String summary,
    required String category,
    int? categoryId,
    required String coverUrl,
    required String content,
    int readTimeMinutes = 5,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/blogs');
      final body = jsonEncode({
        'title': title,
        'excerpt': summary,
        'categoryId': categoryId ?? 1,
        'category': category,
        'coverImageUrl': coverUrl,
        'contentJSON': content,
        'readTimeMinutes': readTimeMinutes,
        'status': 1,
      });

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 5));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return true;
      }
    } catch (_) {}

    // Add to MockData as local fallback
    final newBlog = BlogModel(
      id: 'blog-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      summary: summary,
      category: category,
      categoryId: categoryId,
      imageUrl: coverUrl.isNotEmpty ? coverUrl : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      author: const BlogAuthorModel(name: 'Bạn', role: 'Thành viên', rank: 'Lữ khách'),
      publishedDate: 'Hôm nay',
      readTimeMinutes: readTimeMinutes,
      content: content,
      featured: false,
    );
    MockData.blogs.insert(0, newBlog);
    return true;
  }

  /// Bộ lọc thông minh cho danh sách bài viết (theo Danh mục, Vùng miền, Tỉnh thành, Từ khóa)
  List<BlogModel> filterBlogsList(
    List<BlogModel> list, {
    String? category,
    String? keyword,
    String? region,
    String? province,
  }) {
    var result = List<BlogModel>.from(list);

    // 1. Lọc theo Danh mục
    if (category != null && category.isNotEmpty && category != 'all' && category != 'Tất cả') {
      final cat = category.toLowerCase().trim();
      result = result.where((b) {
        return b.category.toLowerCase().contains(cat) ||
            (b.categoryId != null && b.categoryId.toString() == cat);
      }).toList();
    }

    // 2. Lọc theo Vùng miền
    if (region != null && region.isNotEmpty && region != 'all' && region != 'Tất cả') {
      final reg = region.toLowerCase().trim();
      result = result.where((b) {
        final bReg = b.region.toLowerCase();
        final bProv = b.province.toLowerCase();
        if (reg == 'north' || reg.contains('bắc')) {
          return bReg.contains('bắc') ||
              bReg.contains('north') ||
              _isNorthernProvince(bProv);
        }
        if (reg == 'central' || reg.contains('trung')) {
          return bReg.contains('trung') ||
              bReg.contains('central') ||
              _isCentralProvince(bProv);
        }
        if (reg == 'south' || reg.contains('nam')) {
          return bReg.contains('nam') ||
              bReg.contains('south') ||
              _isSouthernProvince(bProv);
        }
        return bReg.contains(reg) || bProv.contains(reg);
      }).toList();
    }

    // 3. Lọc theo Tỉnh thành (Hỗ trợ multi-token và synonym: Sa Pa/Lào Cai, Hội An/Quảng Nam, TP.HCM/Sài Gòn...)
    if (province != null && province.isNotEmpty && province != 'all' && province != 'Tất cả') {
      final rawTokens = province
          .toLowerCase()
          .split(RegExp(r'[/,\-–&]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e != 'tp.' && e != 'tp' && e != 'tỉnh')
          .toList();

      final tokens = <String>{...rawTokens};
      final pLow = province.toLowerCase();
      if (pLow.contains('hồ chí minh') || pLow.contains('tp. hcm') || pLow.contains('sài gòn') || pLow.contains('hcm')) {
        tokens.addAll(['hồ chí minh', 'sài gòn', 'hcm', 'tp.hcm']);
      }
      if (pLow.contains('sa pa') || pLow.contains('sapa') || pLow.contains('lào cai')) {
        tokens.addAll(['sa pa', 'sapa', 'lào cai']);
      }
      if (pLow.contains('hội an') || pLow.contains('quảng nam')) {
        tokens.addAll(['hội an', 'quảng nam']);
      }
      if (pLow.contains('đà lạt') || pLow.contains('lâm đồng')) {
        tokens.addAll(['đà lạt', 'lâm đồng', 'da lat']);
      }
      if (pLow.contains('phú quốc') || pLow.contains('kiên giang')) {
        tokens.addAll(['phú quốc', 'kiên giang', 'phu quoc']);
      }
      if (pLow.contains('nha trang') || pLow.contains('khánh hòa')) {
        tokens.addAll(['nha trang', 'khánh hòa']);
      }
      if (pLow.contains('quy nhơn') || pLow.contains('bình định')) {
        tokens.addAll(['quy nhơn', 'bình định']);
      }
      if (pLow.contains('vũng tàu') || pLow.contains('bà rịa')) {
        tokens.addAll(['vũng tàu', 'bà rịa']);
      }
      if (pLow.contains('đà nẵng')) {
        tokens.addAll(['đà nẵng', 'da nang']);
      }
      if (pLow.contains('hà nội')) {
        tokens.addAll(['hà nội', 'ha noi']);
      }
      if (pLow.contains('hà giang')) {
        tokens.addAll(['hà giang', 'ha giang', 'đồng văn', 'mã pí lèng', 'nho quế']);
      }
      if (pLow.contains('ninh bình')) {
        tokens.addAll(['ninh bình', 'tràng an', 'tam cốc', 'hang múa']);
      }
      if (pLow.contains('huế')) {
        tokens.addAll(['huế', 'thừa thiên']);
      }
      if (pLow.contains('cần thơ')) {
        tokens.addAll(['cần thơ', 'cái răng', 'ninh kiều']);
      }
      if (pLow.contains('an giang')) {
        tokens.addAll(['an giang', 'châu đốc', 'thất sơn', 'núi sam']);
      }
      if (pLow.contains('quảng ninh')) {
        tokens.addAll(['quảng ninh', 'hạ long', 'cô tô', 'vân đồn']);
      }

      result = result.where((b) {
        final bProv = b.province.toLowerCase();
        final bTitle = b.title.toLowerCase();
        final bSummary = b.summary.toLowerCase();
        final bContent = (b.content ?? '').toLowerCase();
        final bTags = b.tags.map((t) => t.toLowerCase()).join(' ');
        final bPlaces = b.mentionedPlaces
            .map((p) => '${p.name} ${p.province} ${p.address}'.toLowerCase())
            .join(' ');
        final fullSearchText = '$bProv $bTitle $bSummary $bContent $bTags $bPlaces';

        return tokens.any((tok) => fullSearchText.contains(tok));
      }).toList();
    }

    // 4. Lọc theo Từ khóa tìm kiếm (Keyword)
    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = keyword.trim().toLowerCase();
      result = result.where((b) {
        return b.title.toLowerCase().contains(q) ||
            b.summary.toLowerCase().contains(q) ||
            b.category.toLowerCase().contains(q) ||
            b.authorName.toLowerCase().contains(q) ||
            b.province.toLowerCase().contains(q) ||
            b.region.toLowerCase().contains(q) ||
            b.tags.any((t) => t.toLowerCase().contains(q)) ||
            (b.content ?? '').toLowerCase().contains(q) ||
            b.mentionedPlaces.any((p) => p.name.toLowerCase().contains(q) || p.address.toLowerCase().contains(q));
      }).toList();
    }

    return result;
  }

  static bool _isNorthernProvince(String prov) {
    const list = [
      'hà nội', 'hải phòng', 'quảng ninh', 'hà giang', 'lào cai', 'sa pa',
      'ninh bình', 'cao bằng', 'bắc kạn', 'lạng sơn', 'tuyên quang', 'yên bái',
      'thái nguyên', 'phú thọ', 'bắc giang', 'bắc ninh', 'hà nam', 'hải dương',
      'hưng yên', 'nam định', 'thái bình', 'vĩnh phúc', 'hòa bình', 'sơn la',
      'điện biên', 'lai châu', 'mộc châu'
    ];
    return list.any((item) => prov.contains(item));
  }

  static bool _isCentralProvince(String prov) {
    const list = [
      'đà nẵng', 'quảng nam', 'hội an', 'thừa thiên', 'huế', 'quảng bình',
      'quảng trị', 'hà tĩnh', 'nghệ an', 'thanh hóa', 'quảng ngãi', 'bình định',
      'quy nhơn', 'phú yên', 'khánh hòa', 'nha trang', 'ninh thuận', 'bình thuận',
      'phan thiết', 'kon tum', 'gia lai', 'đắk lắk', 'đắk nông', 'lâm đồng', 'đà lạt'
    ];
    return list.any((item) => prov.contains(item));
  }

  static bool _isSouthernProvince(String prov) {
    const list = [
      'hồ chí minh', 'sài gòn', 'bình dương', 'đồng nai', 'bà rịa', 'vũng tàu',
      'tây ninh', 'bình phước', 'long an', 'tiền giang', 'bến tre', 'trà vinh',
      'vĩnh long', 'đồng tháp', 'an giang', 'kiên giang', 'phú quốc', 'cần thơ',
      'hậu giang', 'sóc trăng', 'bạc liêu', 'cà mau'
    ];
    return list.any((item) => prov.contains(item));
  }

  /// Lọc danh sách bài viết từ MockData
  Future<List<BlogModel>> _filterLocalBlogs({
    String? category,
    String? keyword,
    String? region,
    String? province,
  }) async {
    final savedIds = await getSavedBlogIds();
    final likedIds = await getLikedBlogIds();

    final enriched = MockData.blogs.map((b) => _enrichBlog(b, likedIds, savedIds)).toList();

    return filterBlogsList(
      enriched,
      category: category,
      keyword: keyword,
      region: region,
      province: province,
    );
  }
}

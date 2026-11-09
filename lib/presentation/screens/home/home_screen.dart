import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/favorite_api_service.dart';
import '../../../data/services/recent_history_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/home/region_showcase_card.dart';
import '../../widgets/home/collection_track_section.dart';
import '../../widgets/home/top_rated_places_section.dart';
import '../destinations/destinations_screen.dart';
import '../destinations/place_detail_screen.dart';
import '../destinations/province_screen.dart';
import '../destinations/region_screen.dart';
import '../destinations/contribute_place_screen.dart';
import '../chat/chat_inbox_screen.dart';
import '../auth/login_screen.dart';
import '../../../data/services/chat_api_service.dart';
import '../../../data/services/notification_api_service.dart';
import '../../widgets/notification/header_notification_dropdown.dart';
import '../../widgets/common/user_utility_drawer_modal.dart';
import '../../widgets/navigation/system_nav_drawer_modal.dart';
import '../../widgets/home/personalized_recommendation_section.dart';
import '../../widgets/home/personalized_food_section.dart';
import '../../../data/models/food_model.dart';
import '../../../data/services/recommendation_api_service.dart';
import '../../../data/services/device_context_service.dart';
import '../leaderboard/leaderboard_index_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final Function({String? query, String? region, String? category})? onNavigateToSearch;

  const HomeScreen({
    super.key,
    this.onNavigateTab,
    this.onNavigateToSearch,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PlaceApiService _placeApiService = PlaceApiService();
  StreamSubscription<UserModel?>? _userSubscription;

  // Data States
  DualContextHomeFeedResult? _dualFeed;
  List<CollectionDto> _featuredCollections = [];
  List<RegionDto> _regions = [];
  List<PlaceModel> _topRatedPlaces = [];
  List<PlaceModel> _recommendedPlaces = [];
  bool _isPersonalizedRecommendations = false;
  List<FoodModel> _recommendedFoods = [];
  UserModel? _currentUser;
  final GlobalKey _notificationBellKey = GlobalKey();
  bool _isNotificationOpen = false;

  // Hero Filter Options
  List<RegionLookupDto> _heroRegions = [];
  List<LookupItemDto> _heroCategories = [];
  String _selectedHeroRegion = '';
  String _selectedHeroCategory = '';
  final TextEditingController _heroSearchController = TextEditingController();
  String _heroImageUrl = 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=1920&auto=format&fit=crop';

  // Scroll Controller & Viewport/Scroll Lazy Loading Flags
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;

  bool _hasTriggeredCollections = false;
  bool _isLoadingCollections = false;

  bool _hasTriggeredFoods = false;
  bool _isLoadingFoods = false;

  bool _hasTriggeredTopRated = false;
  bool _isLoadingTopRated = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    DeviceContextService().intentChangedNotifier.addListener(_onIntentChanged);
    _currentUser = AuthService().currentUser;
    _userSubscription = AuthService().onUserUpdated.listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isPersonalizedRecommendations = user != null;
        });
        if (user != null) {
          NotificationApiService().getUnreadCount();
        }
        _loadDualContextHomeFeed();
      }
    });
    if (_currentUser != null) {
      NotificationApiService().getUnreadCount();
    }
    // Chỉ nạp nhanh những gì đang hiển thị trên màn hình đầu tiên (Viewport First)
    _loadInitialViewportData();
  }

  /// Lắng nghe sự kiện thay đổi ý định/gu danh mục thời gian thực (0ms reactive)
  void _onIntentChanged() {
    if (mounted) {
      _loadDualContextHomeFeed();
      if (_hasTriggeredCollections) {
        _loadCollectionsAndRegionsLazy();
      }
    }
  }

  /// Lắng nghe vị trí cuộn: Lướt tới đâu thì tự động kích hoạt tải trước dữ liệu tới đó
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.position.pixels;

    // 1. Khi người dùng bắt đầu vuốt xuống (> 60px): Kích hoạt nạp Bộ sưu tập & Vùng miền
    if (offset >= 60 && !_hasTriggeredCollections) {
      _hasTriggeredCollections = true;
      _loadCollectionsAndRegionsLazy();
    }

    // 2. Khi người dùng cuộn tiếp (> 400px): Kích hoạt nạp Món ăn đặc sản gợi ý
    if (offset >= 400 && !_hasTriggeredFoods) {
      _hasTriggeredFoods = true;
      _loadRecommendedFoodsLazy();
    }

    // 3. Khi người dùng cuộn gần tới cuối trang (> 750px): Kích hoạt nạp Điểm đến đánh giá cao nhất
    if (offset >= 750 && !_hasTriggeredTopRated) {
      _hasTriggeredTopRated = true;
      _loadTopRatedPlacesLazy();
    }
  }

  /// Tải dữ liệu Dual-Context Home Feed (Kệ 1 GPS + Kệ 2 Intent)
  Future<void> _loadDualContextHomeFeed() async {
    try {
      final gps = await DeviceContextService().getCurrentGps();
      final intentProvinces = await DeviceContextService().getRecentIntentProvinces();
      final primaryIntent = intentProvinces.isNotEmpty ? intentProvinces.first : null;
      final topCategoryIds = await DeviceContextService().getTopCategoryIds();

      final feed = await RecommendationApiService().getDualContextHomeFeed(
        lat: gps.lat,
        lng: gps.lng,
        intentProvinceId: primaryIntent?.provinceId,
        intentProvinceIds: intentProvinces.map((p) => p.provinceId).toList(),
        intentLabel: primaryIntent?.label,
        topCategoryIds: topCategoryIds,
        topK: 8,
      );

      final foods = _hasTriggeredFoods
          ? await RecommendationApiService().getRecommendedFoods(topK: 8)
          : <FoodModel>[];

      if (mounted) {
        setState(() {
          _dualFeed = feed;
          if (feed.shelf1NearbyPlaces.isNotEmpty) {
            _recommendedPlaces = feed.shelf1NearbyPlaces;
          } else if (feed.shelf2IntentPlaces.isNotEmpty) {
            _recommendedPlaces = feed.shelf2IntentPlaces;
          }
          _isPersonalizedRecommendations = (_currentUser != null) || feed.isPersonalized;
          if (foods.isNotEmpty) {
            _recommendedFoods = foods;
          }
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadDualContextHomeFeed error: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    DeviceContextService().intentChangedNotifier.removeListener(_onIntentChanged);
    _scrollController.dispose();
    _userSubscription?.cancel();
    _heroSearchController.dispose();
    super.dispose();
  }

  /// BƯỚC 1: Chỉ nạp dữ liệu hiển thị trên khung nhìn màn hình đầu tiên (Mất < 300ms, không đơ màn hình)
  Future<void> _loadInitialViewportData() async {
    // 0. Nhanh chóng lấy thông tin người dùng từ cache/token
    try {
      final isLoggedIn = await AuthService().isLoggedIn();
      if (isLoggedIn) {
        final cached = await AuthService().getCachedUser();
        if (cached != null && mounted) {
          setState(() {
            _currentUser = cached;
            _isPersonalizedRecommendations = true;
          });
        }
        // Đồng bộ ngầm profile đầy đủ
        AuthService().getProfile().then((res) {
          if (res.success && res.data != null && mounted) {
            setState(() => _currentUser = res.data);
          }
        });
      }
    } catch (_) {}

    try {
      // Nạp song song SystemSettings, FilterOptions, và Dual-Context Home Feed
      final filterOptionsFuture = _placeApiService.getFilterOptions();
      final settingsFuture = _placeApiService.getSystemSettings();

      final gps = await DeviceContextService().getCurrentGps();
      final intentProvinces = await DeviceContextService().getRecentIntentProvinces();
      final primaryIntent = intentProvinces.isNotEmpty ? intentProvinces.first : null;
      final topCategoryIds = await DeviceContextService().getTopCategoryIds();

      final recommendationsFuture = RecommendationApiService().getDualContextHomeFeed(
        lat: gps.lat,
        lng: gps.lng,
        intentProvinceId: primaryIntent?.provinceId,
        intentProvinceIds: intentProvinces.map((p) => p.provinceId).toList(),
        intentLabel: primaryIntent?.label,
        topCategoryIds: topCategoryIds,
        topK: 8,
      );

      final filterOptionsRes = await filterOptionsFuture;
      final settingsMap = await settingsFuture;
      final recommendationsRes = await recommendationsFuture;

      if (mounted) {
        if (settingsMap['HOME_HERO_IMAGE'] != null && settingsMap['HOME_HERO_IMAGE']!.trim().isNotEmpty) {
          _heroImageUrl = settingsMap['HOME_HERO_IMAGE']!.trim();
        }

        if (filterOptionsRes.data != null) {
          final opts = filterOptionsRes.data!;
          _heroRegions = opts.regions;
          _heroCategories = opts.categories;
        }

        _dualFeed = recommendationsRes;
        if (recommendationsRes.shelf1NearbyPlaces.isNotEmpty) {
          _recommendedPlaces = recommendationsRes.shelf1NearbyPlaces;
        } else if (recommendationsRes.shelf2IntentPlaces.isNotEmpty) {
          _recommendedPlaces = recommendationsRes.shelf2IntentPlaces;
        }
        _isPersonalizedRecommendations = (_currentUser != null) || recommendationsRes.isPersonalized;
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadInitialViewportData error: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // Nạp nhanh trạng thái yêu thích ngầm (không chặn UI)
    FavoriteApiService().getFavoritePlaceIds().then((savedIds) {
      if (mounted && savedIds.isNotEmpty) {
        setState(() {
          _recommendedPlaces = _recommendedPlaces.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList();
        });
      }
    });

    // Nạp lịch sử xem gần đây ngầm
    RecentHistoryService().getRecentVisitedPlaces();

    // Tự động tải trước các phần tiếp theo trong nền để trang chủ luôn đầy đủ nội dung phong phú
    if (!_hasTriggeredCollections) {
      _hasTriggeredCollections = true;
      _loadCollectionsAndRegionsLazy();
    }
    if (!_hasTriggeredFoods) {
      _hasTriggeredFoods = true;
      _loadRecommendedFoodsLazy();
    }
    if (!_hasTriggeredTopRated) {
      _hasTriggeredTopRated = true;
      _loadTopRatedPlacesLazy();
    }
  }

  /// BƯỚC 2A (Lazy): Khi người dùng lướt tới, nạp Bộ sưu tập và Vùng miền
  Future<void> _loadCollectionsAndRegionsLazy() async {
    if (_isLoadingCollections) return;
    setState(() => _isLoadingCollections = true);

    try {
      final gps = await DeviceContextService().getCurrentGps();
      final intentProvinces = await DeviceContextService().getRecentIntentProvinces();
      final topCategoryIds = await DeviceContextService().getTopCategoryIds();

      final collectionsFuture = _placeApiService.getFeaturedCollections(
        count: 6,
        lat: gps.lat,
        lng: gps.lng,
        intentProvinceIds: intentProvinces.map((p) => p.provinceId).toList(),
        topCategoryIds: topCategoryIds,
      );
      final regionsFuture = _placeApiService.getRegions();

      final collectionsRes = await collectionsFuture;
      final regionsRes = await regionsFuture;

      List<CollectionDto> populatedCollections = [];
      if (collectionsRes.data != null) {
        populatedCollections = collectionsRes.data!;
      }

      List<RegionDto> populatedRegions = [];
      if (regionsRes.data != null) {
        populatedRegions = regionsRes.data!;
      }

      // Đồng bộ trạng thái đã lưu
      final savedIds = await FavoriteApiService().getFavoritePlaceIds();
      populatedCollections = populatedCollections.map((col) {
        return col.copyWith(
          places: col.places.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _featuredCollections = populatedCollections;
          _regions = populatedRegions;
          _isLoadingCollections = false;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadCollectionsAndRegionsLazy error: $e');
      if (mounted) {
        setState(() => _isLoadingCollections = false);
      }
    }
  }

  /// BƯỚC 2B (Lazy): Khi người dùng lướt tiếp xuống, nạp Món ăn đặc sản gợi ý
  Future<void> _loadRecommendedFoodsLazy() async {
    if (_isLoadingFoods) return;
    setState(() => _isLoadingFoods = true);

    try {
      final foods = await RecommendationApiService().getRecommendedFoods(topK: 8);
      if (mounted) {
        setState(() {
          _recommendedFoods = foods;
          _isLoadingFoods = false;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadRecommendedFoodsLazy error: $e');
      if (mounted) setState(() => _isLoadingFoods = false);
    }
  }

  /// BƯỚC 2C (Lazy): Khi người dùng lướt xuống cuối trang, nạp Điểm đến đánh giá cao nhất
  Future<void> _loadTopRatedPlacesLazy() async {
    if (_isLoadingTopRated) return;
    setState(() => _isLoadingTopRated = true);

    try {
      final topRatedRes = await _placeApiService.searchPlaces(
        const PlaceFilterParams(sortBy: 'rating_desc', pageSize: 6),
      );
      if (mounted) {
        final savedIds = await FavoriteApiService().getFavoritePlaceIds();
        final rawPlaces = topRatedRes.data ?? [];
        final mapped = rawPlaces.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList();
        setState(() {
          _topRatedPlaces = mapped;
          _isLoadingTopRated = false;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadTopRatedPlacesLazy error: $e');
      if (mounted) setState(() => _isLoadingTopRated = false);
    }
  }

  /// Pull-to-refresh: Làm mới mượt mà các mục đã được kích hoạt
  Future<void> _onRefreshAll() async {
    _hasTriggeredCollections = false;
    _hasTriggeredFoods = false;
    _hasTriggeredTopRated = false;

    await _loadInitialViewportData();

    // Nếu người dùng đang cuộn ở dưới, nạp lại theo vị trí cuộn
    if (_scrollController.hasClients) {
      final offset = _scrollController.position.pixels;
      if (offset >= 60) {
        _hasTriggeredCollections = true;
        _loadCollectionsAndRegionsLazy();
      }
      if (offset >= 400) {
        _hasTriggeredFoods = true;
        _loadRecommendedFoodsLazy();
      }
      if (offset >= 750) {
        _hasTriggeredTopRated = true;
        _loadTopRatedPlacesLazy();
      }
    }
  }

  Future<void> _refreshSavedFavorites() async {
    try {
      final savedIds = await FavoriteApiService().getFavoritePlaceIds();
      RecentHistoryService().getRecentVisitedPlaces();
      if (mounted) {
        setState(() {
          _topRatedPlaces = _topRatedPlaces.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList();
          _recommendedPlaces = _recommendedPlaces.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList();
          _featuredCollections = _featuredCollections.map((col) {
            return col.copyWith(
              places: col.places.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList(),
            );
          }).toList();
        });
      }
    } catch (_) {}
  }

  void _navigateToSearch({String? query, String? region, String? category}) {
    if (widget.onNavigateToSearch != null) {
      widget.onNavigateToSearch!(query: query, region: region, category: category);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DestinationsScreen(
          initialSearchQuery: query,
          initialRegion: region,
          initialCategory: category,
        ),
      ),
    ).then((_) => _refreshSavedFavorites());
  }

  void _navigateToPlaceDetail(PlaceModel place) async {
    DeviceContextService().recordVisitedPlace(place);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(place: place),
      ),
    );
    _refreshSavedFavorites();
  }

  void _navigateToRegionDetail(RegionDto region) {
    String slug = 'mien-bac';
    final nameLower = region.name.toLowerCase();
    if (nameLower.contains('trung')) {
      slug = 'mien-trung';
    } else if (nameLower.contains('nam')) {
      slug = 'mien-nam';
    } else if (nameLower.contains('bắc') || nameLower.contains('bac')) {
      slug = 'mien-bac';
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegionScreen(
          regionSlug: slug,
          region: region,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayRecommended = _recommendedPlaces.isNotEmpty ? _recommendedPlaces : _topRatedPlaces;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B), size: 21),
                tooltip: 'Danh mục điều hướng',
                onPressed: () {
                  SystemNavDrawerModal.show(
                    context,
                    onNavigateTab: widget.onNavigateTab,
                    activeRoute: 'home',
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.6,
                    ),
                    children: [
                      TextSpan(text: 'LangThang'),
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 1. Button "Đề xuất địa điểm" (Dạng icon tròn 36x36 thanh lịch, đồng bộ tuyệt đối)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'Đề xuất địa điểm mới',
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ContributePlaceScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_location_alt_rounded,
                        size: 19,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Button "Thông báo" với dropdown popover & realtime unread badge (36x36)
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: NotificationApiService().unreadCountNotifier,
                  builder: (context, unread, _) {
                    return Stack(
                      key: _notificationBellKey,
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isNotificationOpen
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFF1F5F9).withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _isNotificationOpen ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                              color: _isNotificationOpen
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF334155),
                              size: 20,
                            ),
                            tooltip: 'Thông báo',
                            onPressed: () {
                              setState(() => _isNotificationOpen = true);
                              HeaderNotificationDropdown.show(
                                context,
                                anchorKey: _notificationBellKey,
                                onNavigateTab: widget.onNavigateTab,
                                onDismiss: () {
                                  if (mounted) {
                                    setState(() => _isNotificationOpen = false);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        if (unread > 0)
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

          // 3. Button "Nhắn tin" với realtime unread badge (36x36)
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: StreamBuilder<int>(
                  stream: ChatApiService().onTotalUnreadCountChanged,
                  builder: (context, snapshot) {
                    final unread = snapshot.data ?? ChatApiService().getTotalUnreadCount();
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF334155), size: 19),
                            onPressed: () async {
                              final isLoggedIn = await AuthService().isLoggedIn();
                              final token = await AuthService().getAccessToken();
                              if (!isLoggedIn || token == null || token.isEmpty) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Vui lòng đăng nhập để sử dụng tính năng tin nhắn.'),
                                    backgroundColor: Color(0xFF1E293B),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                final didLogin = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                                if (didLogin != true || !context.mounted) return;
                              }
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ChatInboxScreen()),
                              );
                            },
                          ),
                        ),
                        if (unread > 0)
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

          // 4. Avatar cá nhân hoặc nút Đăng nhập nếu chưa đăng nhập
          if (_currentUser == null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 2),
              child: Center(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen(redirectToHome: true)),
                    );
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF047857).withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Đăng nhập',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    UserUtilityDrawerModal.show(
                      context,
                      onNavigateTab: widget.onNavigateTab,
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFD1FAE5),
                          backgroundImage: getAppImageProvider(_currentUser?.avatarUrl),
                          child: (_currentUser?.avatarUrl == null ||
                                  _currentUser!.avatarUrl.isEmpty)
                              ? Text(
                                  _currentUser?.fullName.isNotEmpty == true
                                      ? _currentUser!.fullName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF047857),
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _onRefreshAll,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HERO BANNER (Matching Share_Locations HeroBanner.tsx)
                    _buildHeroBanner(),

                    const SizedBox(height: 24),

                    // 2.5. PERSONALIZED RECOMMENDATIONS (Dual-Context Kệ 1 GPS & Kệ 2 Điểm đến)
                    PersonalizedRecommendationSection(
                      dualFeed: _dualFeed,
                      places: displayRecommended,
                      isPersonalized: _currentUser != null || _isPersonalizedRecommendations,
                      onPlaceTap: _navigateToPlaceDetail,
                    ),
                    const SizedBox(height: 32),

                    // 3. HOME FEATURED INTERLEAVED (Matching Share_Locations HomeFeaturedInterleaved.tsx)
                    _buildHomeFeaturedInterleaved(),

                    const SizedBox(height: 32),

                    // 3.5. PERSONALIZED FOODS (Matching Share_Locations PersonalizedFoodSection.tsx)
                    if (_recommendedFoods.isNotEmpty) ...[
                      PersonalizedFoodSection(
                        foods: _recommendedFoods,
                        onPlaceTap: _navigateToPlaceDetail,
                      ),
                      const SizedBox(height: 32),
                    ],

                    // 4. TOP RATED PLACES SECTION (Matching Share_Locations TopRatedPlacesSection.tsx)
                    TopRatedPlacesSection(
                      places: _topRatedPlaces,
                      onViewAllTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LeaderboardIndexScreen(
                              onNavigateTab: widget.onNavigateTab,
                            ),
                          ),
                        );
                      },
                      onPlaceTap: _navigateToPlaceDetail,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // =========================================================================
  // 1. HERO BANNER (Matching Share_Locations HeroBanner.tsx)
  // =========================================================================
  Widget _buildHeroBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                // 1. Background Image with reliable loading & fallback
                Positioned.fill(
                  child: Image.network(
                    _heroImageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF38BDF8), Color(0xFF0F172A)],
                              ),
                            ),
                          ),
                          child,
                        ],
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Image.network(
                      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=1200&auto=format&fit=crop',
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF0284C7), Color(0xFF0F172A)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Balanced Gradient Overlay (Ensures title is readable while natural scenery stays bright & visible)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isWide
                            ? const [
                                Color(0xD9F0F9FF), // 85% sky-50 for desktop
                                Color(0x33F0F9FF), // 20%
                                Color(0x590F172A), // 35%
                              ]
                            : const [
                                Color(0xAAF0F9FF), // 67% sky-50 so mountains remain clear
                                Color(0x1FF0F9FF), // 12% in the middle
                                Color(0x4D0F172A), // 30% slate-900
                              ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Banner Content
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 28 : 16,
                    vertical: isWide ? 38 : 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Typography
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          children: [
                            Text(
                              'Cảm Hứng Khám Phá\nVô Vàn Trải Nghiệm',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isWide ? 38 : 25,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.8,
                                height: 1.18,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Khám phá thế giới du lịch nhanh chóng, tiện lợi cùng LangThang — nơi đam mê xê dịch biến thành những hành trình đáng nhớ.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isWide ? 15 : 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF334155),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isWide ? 64 : 32),

                      // Floating Search / Filter Bar
                      if (isWide)
                        _buildWideSearchForm()
                      else
                        _buildCompactSearchForm(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideSearchForm() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 920),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildDestinationField(isWide: true),
            ),
            _buildVerticalDivider(),
            Expanded(
              flex: 2,
              child: _buildRegionDropdown(isWide: true),
            ),
            _buildVerticalDivider(),
            Expanded(
              flex: 2,
              child: _buildCategoryDropdown(isWide: true),
            ),
            const SizedBox(width: 8),
            _buildExploreButton(isFullWidth: false),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSearchForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDestinationField(isWide: false),
          Container(
            height: 1,
            color: const Color(0xFFF1F5F9),
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          Row(
            children: [
              Expanded(child: _buildRegionDropdown(isWide: false)),
              _buildVerticalDivider(),
              Expanded(child: _buildCategoryDropdown(isWide: false)),
            ],
          ),
          const SizedBox(height: 10),
          _buildExploreButton(isFullWidth: true),
        ],
      ),
    );
  }

  Widget _buildDestinationField({required bool isWide}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Điểm đến',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: _heroSearchController,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Bạn muốn đi đâu? (Hà Giang, Đà Lạt...)',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF94A3B8),
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitHeroSearch(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionDropdown({required bool isWide}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.explore_outlined,
              size: 17,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vùng miền',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 8,
                    value: _selectedHeroRegion.isEmpty ? null : _selectedHeroRegion,
                    hint: const Text(
                      'Tất cả miền',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text(
                          'Tất cả miền',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      ..._heroRegions.map(
                        (r) => DropdownMenuItem<String>(
                          value: r.name,
                          child: Text(
                            r.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedHeroRegion = val ?? '');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown({required bool isWide}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.layers_outlined,
              size: 17,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Danh mục',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 8,
                    value: _selectedHeroCategory.isEmpty ? null : _selectedHeroCategory,
                    hint: const Text(
                      'Tất cả danh mục',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text(
                          'Tất cả danh mục',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      ..._heroCategories.map(
                        (c) => DropdownMenuItem<String>(
                          value: c.name,
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedHeroCategory = val ?? '');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreButton({required bool isFullWidth}) {
    return Material(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(isFullWidth ? 16 : 30),
      child: InkWell(
        onTap: _submitHeroSearch,
        borderRadius: BorderRadius.circular(isFullWidth ? 16 : 30),
        child: Container(
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: isFullWidth ? 16 : 22),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Khám phá ngay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFFBBF24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: Color(0xFF451A03),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFFE2E8F0),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  void _submitHeroSearch() {
    if (_selectedHeroCategory.isNotEmpty) {
      final cat = _heroCategories.firstWhere(
        (c) => c.name.toLowerCase() == _selectedHeroCategory.toLowerCase(),
        orElse: () => const LookupItemDto(id: 0, name: ''),
      );
      if (cat.id > 0) {
        DeviceContextService().recordCategoryInterest(cat.id, scoreToAdd: 3);
      }
    }

    _navigateToSearch(
      query: _heroSearchController.text.trim().isNotEmpty
          ? _heroSearchController.text.trim()
          : null,
      region: _selectedHeroRegion.isNotEmpty ? _selectedHeroRegion : null,
      category: _selectedHeroCategory.isNotEmpty ? _selectedHeroCategory : null,
    );
  }

  // =========================================================================
  // 3. HOME FEATURED INTERLEAVED (Matching Share_Locations HomeFeaturedInterleaved.tsx)
  // =========================================================================
  Widget _buildHomeFeaturedInterleaved() {
    final maxGroups = (_featuredCollections.length / 2).ceil() > _regions.length
        ? (_featuredCollections.length / 2).ceil()
        : _regions.length;

    List<Widget> interleavedItems = [];

    for (int g = 0; g < maxGroups; g++) {
      // 1. Collections slice (up to 2 per group)
      final colSlice = _featuredCollections.skip(g * 2).take(2).toList();
      for (final col in colSlice) {
        interleavedItems.add(
          CollectionTrackSection(
            collection: col,
            onPlaceTap: _navigateToPlaceDetail,
          ),
        );
        interleavedItems.add(const SizedBox(height: 24));
      }

      // 2. Region Showcase Card (if available for this group)
      if (g < _regions.length) {
        interleavedItems.add(
          RegionShowcaseCard(
            region: _regions[g],
            onProvinceTap: (regionName, provinceName) {
              if (provinceName != null && provinceName.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProvinceScreen(provinceName: provinceName),
                  ),
                );
              } else {
                _navigateToSearch(region: regionName, query: provinceName);
              }
            },
            onExploreRegionTap: _navigateToRegionDetail,
          ),
        );
        interleavedItems.add(const SizedBox(height: 24));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: interleavedItems,
    );
  }
}

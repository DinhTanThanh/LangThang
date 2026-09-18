import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
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
import '../../widgets/home/place_type_quick_nav_section.dart';
import '../destinations/destinations_screen.dart';
import '../destinations/place_detail_screen.dart';
import '../destinations/region_screen.dart';
import '../chat/chat_inbox_screen.dart';
import '../../../data/services/chat_api_service.dart';

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

  // Data States
  List<CategoryDto> _categories = [];
  List<PlaceTypeDto> _placeTypes = [];
  List<CollectionDto> _featuredCollections = [];
  List<RegionDto> _regions = [];
  List<PlaceModel> _topRatedPlaces = [];
  UserModel? _currentUser;

  // Hero Filter Options
  List<RegionLookupDto> _heroRegions = [];
  List<LookupItemDto> _heroCategories = [];
  String _selectedHeroRegion = '';
  String _selectedHeroCategory = '';
  final TextEditingController _heroSearchController = TextEditingController();

  bool _isLoading = true;

  final List<Map<String, String>> _quickTags = [
    {'label': 'Hà Giang', 'region': 'Miền Bắc'},
    {'label': 'Phong Nha', 'region': 'Miền Trung'},
    {'label': 'Đà Lạt', 'region': 'Miền Trung'},
    {'label': 'Hội An', 'region': 'Miền Trung'},
    {'label': 'Phú Quốc', 'region': 'Miền Nam'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAllRealData();
  }

  @override
  void dispose() {
    _heroSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllRealData() async {
    setState(() => _isLoading = true);

    try {
      // 0. Fetch user profile
      try {
        final cached = await AuthService().getCachedUser();
        if (cached != null) {
          _currentUser = cached;
        }
        if (await AuthService().isLoggedIn()) {
          final profileRes = await AuthService().getProfile();
          if (profileRes.success && profileRes.data != null) {
            _currentUser = profileRes.data;
          }
        }
      } catch (_) {}

      // 1. Fetch filter options, categories, place types, collections, and regions in parallel
      final filterOptionsFuture = _placeApiService.getFilterOptions();
      final categoriesFuture = _placeApiService.getCategories();
      final placeTypesFuture = _placeApiService.getPlaceTypes();
      final collectionsFuture = _placeApiService.getFeaturedCollections(count: 6);
      final regionsFuture = _placeApiService.getRegions();
      final topRatedFuture = _placeApiService.searchPlaces(
        const PlaceFilterParams(sortBy: 'rating_desc', pageSize: 6),
      );

      final filterOptionsRes = await filterOptionsFuture;
      final categoriesRes = await categoriesFuture;
      final placeTypesRes = await placeTypesFuture;
      final collectionsRes = await collectionsFuture;
      final regionsRes = await regionsFuture;
      final topRatedRes = await topRatedFuture;

      if (filterOptionsRes.data != null) {
        final opts = filterOptionsRes.data!;
        _heroRegions = opts.regions;
        _heroCategories = opts.categories;
      }

      if (categoriesRes.data != null) {
        _categories = categoriesRes.data!;
      }

      if (placeTypesRes.data != null && placeTypesRes.data!.isNotEmpty) {
        _placeTypes = placeTypesRes.data!;
      } else if (_categories.isNotEmpty) {
        _placeTypes = _categories
            .map((c) => PlaceTypeDto(
                  id: c.id,
                  name: c.name,
                  iconClass: c.iconClass,
                  placeCount: c.placeCount,
                ))
            .toList();
      }

      if (regionsRes.data != null) {
        _regions = regionsRes.data!;
      }

      if (topRatedRes.data != null) {
        _topRatedPlaces = topRatedRes.data!;
      }

      // 2. Fetch Places for each Collection
      if (collectionsRes.data != null) {
        List<CollectionDto> rawCollections = collectionsRes.data!;
        List<CollectionDto> populatedCollections = [];

        for (final col in rawCollections) {
          if (col.places.isNotEmpty) {
            populatedCollections.add(col);
          } else {
            // Fetch places for this collection or query by collection keyword/type
            final colPlacesRes = await _placeApiService.searchPlaces(
              PlaceFilterParams(
                keyword: col.title.contains('Bắc')
                    ? 'Hà Nội'
                    : (col.title.contains('Trung')
                        ? 'Đà Nẵng'
                        : (col.title.contains('Nam') ? 'Sài Gòn' : null)),
                pageSize: 6,
                sortBy: 'popular_desc',
              ),
            );

            final placesList = (colPlacesRes.data != null && colPlacesRes.data!.isNotEmpty)
                ? colPlacesRes.data!
                : _topRatedPlaces.take(5).toList();

            populatedCollections.add(
              CollectionDto(
                id: col.id,
                title: col.title,
                description: col.description,
                isFeatured: col.isFeatured,
                displayOrder: col.displayOrder,
                coverUrl: col.coverUrl,
                placeCount: col.placeCount > 0 ? col.placeCount : placesList.length,
                places: placesList,
              ),
            );
          }
        }
        _featuredCollections = populatedCollections;
      }

      // 3. Populate Provinces for Regions if needed
      if (_regions.isNotEmpty && _heroRegions.isNotEmpty) {
        List<RegionDto> populatedRegions = [];
        for (final r in _regions) {
          final matchedLookup = _heroRegions.firstWhere(
            (hl) => hl.id == r.id || hl.name.toLowerCase() == r.name.toLowerCase(),
            orElse: () => const RegionLookupDto(id: 0, name: '', provinces: []),
          );

          List<ProvinceDto> provs = r.provinces;
          if (provs.isEmpty && matchedLookup.provinces.isNotEmpty) {
            provs = matchedLookup.provinces.map((lp) {
              return ProvinceDto(
                id: lp.id,
                regionId: r.id,
                regionName: r.name,
                name: lp.name,
                placeCount: 15,
              );
            }).toList();
          }

          populatedRegions.add(
            RegionDto(
              id: r.id,
              name: r.name,
              tagline: r.tagline ?? (r.id == 1 ? 'Vùng đất nghìn năm di sản' : (r.id == 2 ? 'Hành trình di sản & biển ngọc' : 'Sôi động nhịp sống phương Nam')),
              description: r.description ?? 'Khám phá những điểm đến đặc trưng, ẩm thực đậm đà bản sắc và cảnh sắc thiên nhiên tuyệt tác của ${r.name}.',
              imageUrl: r.imageUrl,
              orderIndex: r.orderIndex,
              provinceCount: provs.length,
              provinces: provs,
            ),
          );
        }
        _regions = populatedRegions;
      }

      // 4. Đồng bộ trạng thái đã lưu từ FavoriteApiService
      final savedIds = await FavoriteApiService().getFavoritePlaceIds();
      _topRatedPlaces = _topRatedPlaces.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList();
      _featuredCollections = _featuredCollections.map((col) {
        return col.copyWith(
          places: col.places.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList(),
        );
      }).toList();

      // 5. Nạp danh sách đã xem gần đây
      RecentHistoryService().getRecentVisitedPlaces();
    } catch (e) {
      debugPrint('[HomeScreen] Error loading real data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSavedFavorites() async {
    try {
      final savedIds = await FavoriteApiService().getFavoritePlaceIds();
      RecentHistoryService().getRecentVisitedPlaces();
      if (mounted) {
        setState(() {
          _topRatedPlaces = _topRatedPlaces.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.8,
                ),
                children: [
                  TextSpan(text: 'LangThang'),
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<int>(
            stream: ChatApiService().onTotalUnreadCountChanged,
            builder: (context, snapshot) {
              final unread = snapshot.data ?? ChatApiService().getTotalUnreadCount();
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textPrimary),
                    tooltip: 'Tin nhắn',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChatInboxScreen()),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không có thông báo mới.')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () => widget.onNavigateTab?.call(6),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: (_currentUser?.avatarUrl != null &&
                        _currentUser!.avatarUrl.isNotEmpty)
                    ? NetworkImage(_currentUser!.avatarUrl)
                    : null,
                child: (_currentUser?.avatarUrl == null ||
                        _currentUser!.avatarUrl.isEmpty)
                    ? Text(
                        _currentUser?.fullName.isNotEmpty == true
                            ? _currentUser!.fullName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
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
              onRefresh: _loadAllRealData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HERO BANNER (Matching Share_Locations HeroBanner.tsx)
                    _buildHeroBanner(),

                    const SizedBox(height: 20),

                    // 2. PLACE TYPE QUICK NAV (Matching Share_Locations PlaceTypeQuickNav.tsx)
                    PlaceTypeQuickNavSection(
                      placeTypes: _placeTypes,
                      onViewAllTap: () => _navigateToSearch(),
                      onPlaceTypeTap: (pt) => _navigateToSearch(category: pt.name),
                    ),

                    const SizedBox(height: 24),

                    // 3. HOME FEATURED INTERLEAVED (Matching Share_Locations HomeFeaturedInterleaved.tsx)
                    _buildHomeFeaturedInterleaved(),

                    const SizedBox(height: 32),

                    // 4. TOP RATED PLACES SECTION (Matching Share_Locations TopRatedPlacesSection.tsx)
                    TopRatedPlacesSection(
                      places: _topRatedPlaces,
                      onViewAllTap: () => _navigateToSearch(category: null),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.network(
                'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1920&auto=format&fit=crop',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: const Color(0xFF0F172A)),
              ),
            ),

            // Dark Gradient Overlay matching Web (from-slate-950/90 via-slate-950/45 to-slate-900/30)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFA020617),
                      Color(0xB3020617),
                      Color(0x4D0F172A),
                    ],
                    stops: [0.0, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // Banner Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                      children: [
                        TextSpan(text: 'Mỗi chuyến đi là\n'),
                        TextSpan(
                          text: 'một điều kỳ diệu',
                          style: TextStyle(color: Color(0xFFFDBA74)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Khám phá trọn vẹn cảnh sắc 63 tỉnh thành, lưu giữ hàng ngàn quán ăn đặc sản bản địa và kết nối cùng cộng đồng du lịch tự túc.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Form Box
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Keyword input
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _heroSearchController,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  hintText: 'Bạn muốn đi đâu? (Hà Giang, Tràng An...)',
                                  hintStyle: TextStyle(
                                      color: AppColors.textSecondary, fontSize: 12),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: (value) {
                                  _navigateToSearch(
                                    query: value,
                                    region: _selectedHeroRegion.isNotEmpty
                                        ? _selectedHeroRegion
                                        : null,
                                    category: _selectedHeroCategory.isNotEmpty
                                        ? _selectedHeroCategory
                                        : null,
                                  );
                                },
                              ),
                             ),
                           ],
                         ),

                        const Divider(height: 12, thickness: 1, color: Color(0xFFF1F5F9)),

                        // Filters row
                        Row(
                          children: [
                            // Region dropdown
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedHeroRegion.isEmpty
                                        ? null
                                        : _selectedHeroRegion,
                                    hint: const Row(
                                      children: [
                                        Icon(Icons.navigation_outlined,
                                            size: 13, color: Color(0xFF64748B)),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Tất cả miền',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF475569),
                                                fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                        size: 16, color: Color(0xFF64748B)),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: '',
                                        child: Text('Tất cả miền',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                      ..._heroRegions.map((r) => DropdownMenuItem<String>(
                                            value: r.name,
                                            child: Text(r.name,
                                                style: const TextStyle(fontSize: 11),
                                                overflow: TextOverflow.ellipsis),
                                          )),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _selectedHeroRegion = val ?? '');
                                    },
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Category dropdown
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedHeroCategory.isEmpty
                                        ? null
                                        : _selectedHeroCategory,
                                    hint: const Row(
                                      children: [
                                        Icon(Icons.layers_outlined,
                                            size: 13, color: Color(0xFF64748B)),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Tất cả danh mục',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF475569),
                                                fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                        size: 16, color: Color(0xFF64748B)),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: '',
                                        child: Text('Tất cả danh mục',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                      ..._heroCategories.map((c) => DropdownMenuItem<String>(
                                            value: c.name,
                                            child: Text(c.name,
                                                style: const TextStyle(fontSize: 11),
                                                overflow: TextOverflow.ellipsis),
                                          )),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _selectedHeroCategory = val ?? '');
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Submit Button matching Web HeroBanner.tsx
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () {
                              _navigateToSearch(
                                query: _heroSearchController.text.trim().isNotEmpty
                                    ? _heroSearchController.text.trim()
                                    : null,
                                region: _selectedHeroRegion.isNotEmpty
                                    ? _selectedHeroRegion
                                    : null,
                                category: _selectedHeroCategory.isNotEmpty
                                    ? _selectedHeroCategory
                                    : null,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004F32),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.explore_rounded, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Khám phá ngay',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick Tags
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: Color(0xFFFDBA74)),
                        const SizedBox(width: 4),
                        const Text(
                          'Tìm nhanh: ',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                        ..._quickTags.map((tag) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => _navigateToSearch(
                                  query: tag['label'], region: tag['region']),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  tag['label']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
              _navigateToSearch(region: regionName, query: provinceName);
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

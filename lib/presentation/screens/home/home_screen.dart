import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/auth_service.dart';
import '../destinations/destinations_screen.dart';
import '../destinations/place_detail_screen.dart';
import '../destinations/collections_screen.dart';

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

  // Real Data State
  List<CategoryDto> _categories = [];
  List<CollectionDto> _featuredCollections = [];
  List<RegionDto> _regions = [];
  final Map<int, List<PlaceModel>> _regionPlaces = {};
  List<PlaceModel> _cuisinePlaces = [];
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
      // 0. Fetch real user profile from AuthService
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
      // 1. Fetch filter options, categories, collections, and regions in parallel
      final filterOptionsFuture = _placeApiService.getFilterOptions();
      final categoriesFuture = _placeApiService.getCategories();
      final collectionsFuture = _placeApiService.getFeaturedCollections(count: 6);
      final regionsFuture = _placeApiService.getRegions();

      final filterOptionsRes = await filterOptionsFuture;
      final categoriesRes = await categoriesFuture;
      final collectionsRes = await collectionsFuture;
      final regionsRes = await regionsFuture;

      if (filterOptionsRes.data != null) {
        final opts = filterOptionsRes.data!;
        _heroRegions = opts.regions;
        _heroCategories = opts.categories;
      }

      if (categoriesRes.data != null) {
        _categories = categoriesRes.data!;
      }

      if (collectionsRes.data != null) {
        _featuredCollections = collectionsRes.data!;
      }

      if (regionsRes.data != null) {
        _regions = regionsRes.data!;
      }

      // 2. Fetch Top Rated places (SortBy: rating_desc, PageSize: 6)
      final topRatedRes = await _placeApiService.searchPlaces(
        const PlaceFilterParams(sortBy: 'rating_desc', pageSize: 6),
      );
      if (topRatedRes.data != null) {
        _topRatedPlaces = topRatedRes.data!;
      }

      // 3. Fetch Cuisine places (categoryId matching cuisine or keyword 'ẩm thực', SortBy: rating_desc, PageSize: 4)
      int? cuisineCatId;
      for (final cat in _categories) {
        final name = cat.name.toLowerCase();
        if (name.contains('ẩm thực') || name.contains('quán ăn') || name.contains('món ngon')) {
          cuisineCatId = cat.id;
          break;
        }
      }

      final cuisineRes = await _placeApiService.searchPlaces(
        PlaceFilterParams(
          categoryId: cuisineCatId,
          keyword: cuisineCatId == null ? 'ẩm thực' : null,
          sortBy: 'rating_desc',
          pageSize: 4,
        ),
      );
      if (cuisineRes.data != null && cuisineRes.data!.isNotEmpty) {
        _cuisinePlaces = cuisineRes.data!;
      } else {
        // Fallback to top places if empty
        _cuisinePlaces = _topRatedPlaces.take(4).toList();
      }

      // 4. Fetch places for each region in parallel
      if (_regions.isNotEmpty) {
        final regionFutures = _regions.map((region) {
          return _placeApiService.searchPlaces(
            PlaceFilterParams(
              regionId: region.id,
              sortBy: 'popular_desc',
              pageSize: 8,
            ),
          );
        }).toList();

        final regionResults = await Future.wait(regionFutures);
        for (int i = 0; i < _regions.length; i++) {
          final res = regionResults[i];
          if (res.data != null && res.data!.isNotEmpty) {
            _regionPlaces[_regions[i].id] = res.data!;
          }
        }
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error loading real data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
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
    );
  }

  void _navigateToPlaceDetail(PlaceModel place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(place: place),
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
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadAllRealData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HERO BANNER
                    _buildHeroBanner(),

                    const SizedBox(height: 24),

                    // 2. CATEGORY QUICK NAV
                    _buildCategoryQuickNav(),

                    const SizedBox(height: 28),

                    // 3. FEATURED COLLECTIONS SECTION
                    _buildFeaturedCollectionsSection(),

                    const SizedBox(height: 32),

                    // 4. REGIONS SECTION (Hành trình 3 miền)
                    _buildRegionsSection(),

                    const SizedBox(height: 32),

                    // 5. CUISINE SECTION (Ẩm thực 3 miền)
                    _buildCuisineSection(),

                    const SizedBox(height: 32),

                    // 6. TOP RATED PLACES (Điểm đến đánh giá cao nhất)
                    _buildTopRatedSection(),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================
  // 1. HERO BANNER (Matches Web HeroBanner.tsx)
  // ==========================================
  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.network(
                'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1920&auto=format&fit=crop',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0F172A)),
              ),
            ),
            // Dark Gradient Overlay matching Web (slate-950/90 via slate-950/45 to slate-900/30)
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
                      borderRadius: BorderRadius.circular(20),
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
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  hintText: 'Bạn muốn đi đâu? (Hà Giang, Tràng An...)',
                                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: (value) {
                                  _navigateToSearch(
                                    query: value,
                                    region: _selectedHeroRegion.isNotEmpty ? _selectedHeroRegion : null,
                                    category: _selectedHeroCategory.isNotEmpty ? _selectedHeroCategory : null,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 12, thickness: 0.8, color: Color(0xFFE2E8F0)),

                        // Filters row + Submit button
                        Row(
                          children: [
                            // Region select dropdown
                            Expanded(
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedHeroRegion.isEmpty ? null : _selectedHeroRegion,
                                    hint: const Row(
                                      children: [
                                        Icon(Icons.navigation_outlined, size: 13, color: Color(0xFF64748B)),
                                        SizedBox(width: 4),
                                        Text('Tất cả miền', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: '',
                                        child: Text('Tất cả miền', style: TextStyle(fontSize: 11)),
                                      ),
                                      ..._heroRegions.map((r) => DropdownMenuItem<String>(
                                            value: r.name,
                                            child: Text(r.name, style: const TextStyle(fontSize: 11)),
                                          )),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _selectedHeroRegion = val ?? '');
                                    },
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 6),

                            // Category select dropdown
                            Expanded(
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedHeroCategory.isEmpty ? null : _selectedHeroCategory,
                                    hint: const Row(
                                      children: [
                                        Icon(Icons.layers_outlined, size: 13, color: Color(0xFF64748B)),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Danh mục',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: '',
                                        child: Text('Tất cả danh mục', style: TextStyle(fontSize: 11)),
                                      ),
                                      ..._heroCategories.map((c) => DropdownMenuItem<String>(
                                            value: c.name,
                                            child: Text(c.name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                          )),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _selectedHeroCategory = val ?? '');
                                    },
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 6),

                            // Submit Button
                            ElevatedButton(
                              onPressed: () {
                                _navigateToSearch(
                                  query: _heroSearchController.text.trim().isNotEmpty ? _heroSearchController.text.trim() : null,
                                  region: _selectedHeroRegion.isNotEmpty ? _selectedHeroRegion : null,
                                  category: _selectedHeroCategory.isNotEmpty ? _selectedHeroCategory : null,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: const Size(0, 36),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.explore_rounded, size: 14),
                                  SizedBox(width: 4),
                                  Text('Tìm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
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
                        const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFFDBA74)),
                        const SizedBox(width: 4),
                        const Text(
                          'Tìm nhanh: ',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        ..._quickTags.map((tag) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => _navigateToSearch(query: tag['label'], region: tag['region']),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

                  const SizedBox(height: 16),

                  // 4-item Stats Bar (Matching Web HeroBanner.tsx)
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x26FFFFFF))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHeroStat('63+', 'Tỉnh thành\ntoàn quốc', const Color(0xFFFDBA74)),
                        _buildHeroStat('1,200+', 'Địa điểm &\nMón ngon', const Color(0xFF34D399)),
                        _buildHeroStat('100%', 'Kinh nghiệm\nthực tế', const Color(0xFFFCD34D)),
                        _buildHeroStat('50k+', 'Cộng đồng\nyêu du lịch', const Color(0xFF38BDF8)),
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

  Widget _buildHeroStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 9.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  // ====================================================
  // 2. CATEGORY QUICK NAV (Matches Web CategoryQuickNav)
  // ====================================================
  Widget _buildCategoryQuickNav() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'DANH MỤC TRẢI NGHIỆM',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bạn đang tìm kiếm điều gì?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _navigateToSearch(),
                  child: const Text(
                    'Xem tất cả →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Categories horizontal scroll
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final style = _getCategoryStyle(cat.name);

                return GestureDetector(
                  onTap: () => _navigateToSearch(category: cat.name),
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: style.bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: style.borderColor),
                          ),
                          child: Icon(style.icon, color: style.iconColor, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cat.placeCount > 0 ? '${cat.placeCount} địa điểm' : 'Đang cập nhật',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 3. FEATURED COLLECTIONS SECTION (Matches Web FeaturedCollectionsSection)
  // ====================================================================
  Widget _buildFeaturedCollectionsSection() {
    if (_featuredCollections.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      color: const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, size: 14, color: AppColors.secondary),
                        SizedBox(width: 4),
                        Text(
                          'GỢI Ý ĐỘC QUYỀN',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bộ sưu tập điểm đến nổi bật',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CollectionsScreen()),
                    );
                  },
                  child: const Text(
                    'Xem tất cả →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Collection Cards Carousel
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _featuredCollections.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final col = _featuredCollections[index];
                return GestureDetector(
                  onTap: () => _navigateToSearch(query: col.title),
                  child: Container(
                    width: 270,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            col.coverUrl ?? 'https://images.unsplash.com/photo-1528127269322-539801943592?w=900&h=600&fit=crop&auto=format',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF1E293B)),
                          ),
                          // Dark gradient
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Color(0xF5020617),
                                  Color(0x75020617),
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                          // Text info
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text(
                                        'BỘ SƯU TẬP TUYỂN CHỌN',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        col.placeCount > 0 ? '${col.placeCount} địa điểm' : 'Nhiều điểm đến',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  col.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (col.description != null && col.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    col.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 11,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                const Row(
                                  children: [
                                    Text(
                                      'Khám phá ngay',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // 4. REGIONS SECTION (Matches Web RegionsSection.tsx)
  // ====================================================
  Widget _buildRegionsSection() {
    if (_regions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.map_rounded, size: 14, color: AppColors.secondary),
                  SizedBox(width: 4),
                  Text(
                    'KHÁM PHÁ THEO VÙNG MIỀN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Hành trình 3 miền Bắc - Trung - Nam',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Từ những đỉnh núi mờ sương Tây Bắc đến vẻ trù phú của miệt vườn phương Nam, mỗi vùng miền là một trang ký ức rực rỡ.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Tracks for each region
        ..._regions.map((region) {
          final places = _regionPlaces[region.id] ?? [];
          if (places.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildRegionTrack(region: region, places: places),
          );
        }),
      ],
    );
  }

  Widget _buildRegionTrack({
    required RegionDto region,
    required List<PlaceModel> places,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Track Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          region.tagline ?? '${region.provinceCount} Tỉnh thành',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      region.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _navigateToSearch(region: region.name),
                child: const Text(
                  'Xem tất cả →',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal place cards (matching Web RegionsSection card design)
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: places.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final place = places[index];
              return GestureDetector(
                onTap: () => _navigateToPlaceDetail(place),
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          place.img,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF1E293B)),
                        ),
                        // Gradient
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xFA020617),
                                Color(0x66020617),
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                        // Rating Badge top-left
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                                const SizedBox(width: 3),
                                Text(
                                  place.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Place info bottom
                        Positioned(
                          bottom: 14,
                          left: 14,
                          right: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFFDBA74)),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      place.province.isNotEmpty ? place.province : (place.region.isNotEmpty ? place.region : region.name),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFFDBA74),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (place.desc.isNotEmpty || place.location.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  place.desc.isNotEmpty ? place.desc : place.location,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ====================================================
  // 5. CUISINE SECTION (Matches Web CuisineSection.tsx)
  // ====================================================
  Widget _buildCuisineSection() {
    if (_cuisinePlaces.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.restaurant_rounded, size: 14, color: AppColors.secondary),
                          SizedBox(width: 4),
                          Text(
                            'HƯƠNG VỊ BẢN ĐỊA',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ẩm thực 3 miền',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mỗi món ăn là một câu chuyện văn hóa tinh hoa bản địa.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _navigateToSearch(category: 'Quán ăn'),
                  child: const Text(
                    'Xem tất cả →',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2x2 Food Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              itemCount: _cuisinePlaces.length,
              itemBuilder: (context, index) {
                final place = _cuisinePlaces[index];
                return GestureDetector(
                  onTap: () => _navigateToPlaceDetail(place),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail with badge
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Image.network(
                                  place.img,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFF1F5F9)),
                                ),
                              ),
                            ),
                            // Province badge bottom-left
                            Positioned(
                              bottom: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  place.province.isNotEmpty ? place.province : (place.region.isNotEmpty ? place.region : 'Đặc sản'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Star rating top-right
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 11, color: Color(0xFFFBBF24)),
                                    const SizedBox(width: 2),
                                    Text(
                                      place.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  place.desc.isNotEmpty ? place.desc : place.location,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                ),
                                const Spacer(),
                                const Divider(height: 10, thickness: 0.6, color: Color(0xFFF1F5F9)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              place.hours.isNotEmpty ? place.hours : 'Mở cả ngày',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      place.price.isNotEmpty ? place.price : 'Bình dân',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 6. TOP RATED PLACES (Matches Web TopRatedPlacesSection.tsx)
  // ==========================================================
  Widget _buildTopRatedSection() {
    if (_topRatedPlaces.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.military_tech_rounded, size: 15, color: AppColors.secondary),
                      SizedBox(width: 4),
                      Text(
                        'ĐƯỢC YÊU THÍCH NHẤT',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Điểm đến đánh giá cao nhất',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _navigateToSearch(query: ''),
                child: const Text(
                  'Xem tất cả →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Cards list
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _topRatedPlaces.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final place = _topRatedPlaces[index];
              return GestureDetector(
                onTap: () => _navigateToPlaceDetail(place),
                child: Container(
                  width: 230,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image with badges
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.network(
                                place.img,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFF1F5F9)),
                              ),
                            ),
                          ),
                          // Category tag
                          if (place.category.isNotEmpty)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  place.category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          // Rating Badge
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
                                  const SizedBox(width: 2),
                                  Text(
                                    place.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      place.province.isNotEmpty ? '${place.province}, ${place.region}' : place.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                place.desc.isNotEmpty ? place.desc : place.location,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                              const Spacer(),
                              const Divider(height: 8, thickness: 0.6, color: Color(0xFFF1F5F9)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    place.reviews > 0 ? '${place.reviews} đánh giá' : 'Mới cập nhật',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  Text(
                                    place.price.isNotEmpty ? place.price : 'Miễn phí',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper for category styling matching React CategoryQuickNav ICON_MAP & COLOR_MAP
  _CategoryItemStyle _getCategoryStyle(String name) {
    final n = name.toLowerCase();
    if (n.contains('thắng cảnh') || n.contains('núi') || n.contains('thiên nhiên')) {
      return const _CategoryItemStyle(
        icon: Icons.landscape_rounded,
        iconColor: Color(0xFF047857),
        bgColor: Color(0xFFECFDF5),
        borderColor: Color(0xFFA7F3D0),
      );
    } else if (n.contains('biển') || n.contains('đảo')) {
      return const _CategoryItemStyle(
        icon: Icons.waves_rounded,
        iconColor: Color(0xFF0284C7),
        bgColor: Color(0xFFF0F9FF),
        borderColor: Color(0xFFBAE6FD),
      );
    } else if (n.contains('di tích') || n.contains('lịch sử')) {
      return const _CategoryItemStyle(
        icon: Icons.account_balance_rounded,
        iconColor: Color(0xFFD97706),
        bgColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFDE68A),
      );
    } else if (n.contains('ăn') || n.contains('ẩm thực') || n.contains('nhà hàng')) {
      return const _CategoryItemStyle(
        icon: Icons.restaurant_rounded,
        iconColor: Color(0xFFE11D48),
        bgColor: Color(0xFFFFF1F2),
        borderColor: Color(0xFFFECDD3),
      );
    } else if (n.contains('cà phê') || n.contains('cafe')) {
      return const _CategoryItemStyle(
        icon: Icons.local_cafe_rounded,
        iconColor: Color(0xFFB45309),
        bgColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFDE68A),
      );
    } else if (n.contains('vườn') || n.contains('rừng')) {
      return const _CategoryItemStyle(
        icon: Icons.park_rounded,
        iconColor: Color(0xFF15803D),
        bgColor: Color(0xFFF0FDF4),
        borderColor: Color(0xFFBBF7D0),
      );
    } else if (n.contains('phượt') || n.contains('trải nghiệm') || n.contains('cung')) {
      return const _CategoryItemStyle(
        icon: Icons.explore_rounded,
        iconColor: Color(0xFF4F46E5),
        bgColor: Color(0xFFEEF2FF),
        borderColor: Color(0xFFC7D2FE),
      );
    } else {
      return const _CategoryItemStyle(
        icon: Icons.auto_awesome_rounded,
        iconColor: Color(0xFF0D9488),
        bgColor: Color(0xFFF0FDFA),
        borderColor: Color(0xFF99F6E4),
      );
    }
  }
}

class _CategoryItemStyle {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const _CategoryItemStyle({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });
}

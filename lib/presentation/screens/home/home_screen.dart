import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/destination_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/models/blog_model.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/services/travel_api_service.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/food_card.dart';
import '../../widgets/itinerary_card.dart';
import '../../widgets/blog_card.dart';
import '../../widgets/section_header.dart';
import '../destinations/destination_detail_screen.dart';
import '../destinations/collections_screen.dart';
import '../destinations/destinations_screen.dart';

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
  final TravelApiService _apiService = TravelApiService();

  List<DestinationModel> _northDestinations = [];
  List<DestinationModel> _centralDestinations = [];
  List<DestinationModel> _southDestinations = [];
  List<FoodModel> _allFoods = [];
  List<FoodModel> _filteredFoods = [];
  String _selectedFoodRegion = 'Tất cả';

  List<ItineraryModel> _itineraries = [];
  List<BlogModel> _blogs = [];
  CollectionModel? _featuredCollection;
  List<TourModel> _tours = [];
  bool _isLoading = true;

  final List<Map<String, String>> _quickTags = [
    {'label': 'Hà Giang', 'region': 'Miền Bắc'},
    {'label': 'Phong Nha', 'region': 'Miền Trung'},
    {'label': 'Đà Lạt', 'region': 'Miền Trung'},
    {'label': 'Hội An', 'region': 'Miền Trung'},
    {'label': 'Phú Quốc', 'region': 'Miền Nam'},
  ];

  final List<String> _foodRegionFilters = [
    'Tất cả',
    'Miền Bắc',
    'Miền Trung',
    'Miền Nam',
  ];

  final List<Map<String, dynamic>> _quickCategories = [
    {
      'name': 'Thắng cảnh',
      'icon': Icons.landscape_rounded,
      'color': Color(0xFF047857),
      'bg': Color(0xFFECFDF5),
      'count': '120+ điểm',
    },
    {
      'name': 'Bãi biển',
      'icon': Icons.waves_rounded,
      'color': Color(0xFF0284C7),
      'bg': Color(0xFFF0F9FF),
      'count': '85+ bãi',
    },
    {
      'name': 'Di tích',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFFD97706),
      'bg': Color(0xFFFFFBEB),
      'count': '95+ điểm',
    },
    {
      'name': 'Quán ăn',
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFFE11D48),
      'bg': Color(0xFFFFF1F2),
      'count': '340+ quán',
    },
    {
      'name': 'Cà phê',
      'icon': Icons.local_cafe_rounded,
      'color': Color(0xFFB45309),
      'bg': Color(0xFFFFFBEB),
      'count': '210+ quán',
    },
    {
      'name': 'Phượt & Chill',
      'icon': Icons.explore_rounded,
      'color': Color(0xFF4F46E5),
      'bg': Color(0xFFEEF2FF),
      'count': '150+ cung',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _apiService.getDestinations(region: Region.north),
      _apiService.getDestinations(region: Region.central),
      _apiService.getDestinations(region: Region.south),
      _apiService.getFoods(),
      _apiService.getItineraries(),
      _apiService.getBlogs(),
      _apiService.getFeaturedCollection(),
      _apiService.getTours(),
    ]);

    if (mounted) {
      setState(() {
        _northDestinations = results[0] as List<DestinationModel>;
        _centralDestinations = results[1] as List<DestinationModel>;
        _southDestinations = results[2] as List<DestinationModel>;
        _allFoods = results[3] as List<FoodModel>;
        _filterFoods();
        _itineraries = results[4] as List<ItineraryModel>;
        _blogs = results[5] as List<BlogModel>;
        _featuredCollection = results[6] as CollectionModel;
        _tours = results[7] as List<TourModel>;
        _isLoading = false;
      });
    }
  }

  void _filterFoods() {
    if (_selectedFoodRegion == 'Tất cả') {
      _filteredFoods = _allFoods;
    } else if (_selectedFoodRegion == 'Miền Bắc') {
      _filteredFoods = _allFoods.where((f) => f.subtitle.contains('Bắc') || f.location.contains('Hà Nội')).toList();
    } else if (_selectedFoodRegion == 'Miền Trung') {
      _filteredFoods = _allFoods.where((f) => f.location.contains('Hội An') || f.location.contains('Huế')).toList();
    } else if (_selectedFoodRegion == 'Miền Nam') {
      _filteredFoods = _allFoods.where((f) => f.location.contains('Hồ Chí Minh') || f.location.contains('Sài Gòn')).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
              onTap: () => widget.onNavigateTab?.call(4),
              child: const CircleAvatar(
                radius: 17,
                backgroundImage: NetworkImage('https://i.pravatar.cc/300?img=47'),
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
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HERO BANNER (matching Web HeroBanner.tsx)
                    _buildHeroBanner(),

                    const SizedBox(height: 24),

                    // 2. CATEGORY QUICK NAV (matching Web CategoryQuickNav.tsx)
                    _buildCategoryQuickNav(),

                    const SizedBox(height: 28),

                    // 3. FEATURED COLLECTIONS (matching Web FeaturedCollectionsSection.tsx)
                    _buildFeaturedCollectionsSection(),

                    const SizedBox(height: 32),

                    // 4. REGIONS SECTION (matching Web RegionsSection.tsx)
                    _buildRegionsSection(),

                    const SizedBox(height: 32),

                    // 5. CUISINE SECTION (matching Web CuisineSection.tsx)
                    _buildCuisineSection(),

                    const SizedBox(height: 32),

                    // 6. TOP RATED PLACES (matching Web TopRatedPlacesSection.tsx)
                    _buildTopRatedSection(),

                    const SizedBox(height: 32),

                    // 7. ITINERARIES (Hành trình)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SectionHeader(
                        badgeText: 'Lịch trình tối ưu',
                        badgeIcon: Icons.route_rounded,
                        title: 'Hành trình gợi ý',
                        subtitle: 'Được đúc kết từ những người mê xê dịch thực thụ',
                        actionText: 'Xem thêm',
                        onActionTap: () => widget.onNavigateTab?.call(3),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _itineraries.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return ItineraryCard(
                          itinerary: _itineraries[index],
                          onTap: () => widget.onNavigateTab?.call(3),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // 8. BLOGS & CẨM NANG
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SectionHeader(
                        badgeText: 'Chia sẻ kinh nghiệm',
                        badgeIcon: Icons.menu_book_rounded,
                        title: 'Blog & Cẩm nang',
                        subtitle: 'Bí kíp vi vu và những câu chuyện bản địa',
                        actionText: 'Tất cả bài viết',
                        onActionTap: () => widget.onNavigateTab?.call(3),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _blogs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return BlogCard(
                          blog: _blogs[index],
                          onTap: () => widget.onNavigateTab?.call(3),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget: Hero Banner (Matching Web HeroBanner.tsx)
  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
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
                'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1200&auto=format&fit=crop',
                fit: BoxFit.cover,
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFA020617),
                      Color(0x99020617),
                      Color(0x40020617),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
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
                    'Khám phá trọn vẹn cảnh sắc 63 tỉnh thành, lưu giữ hàng ngàn quán ăn đặc sản bản địa.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Box Pill
                  GestureDetector(
                    onTap: () => _navigateToSearch(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Bạn muốn đi đâu? (Hà Giang, Tràng An...)',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.explore_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Tìm',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick Tags
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFFDBA74)),
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

                  // 4-item Stats Bar
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem('63+', 'Tỉnh thành', const Color(0xFFFDBA74)),
                        _buildStatItem('1,200+', 'Địa điểm', const Color(0xFF34D399)),
                        _buildStatItem('100%', 'Thực tế', const Color(0xFFFCD34D)),
                        _buildStatItem('50k+', 'Cộng đồng', const Color(0xFF38BDF8)),
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

  Widget _buildStatItem(String value, String label, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // Widget: Category Quick Nav (Matching Web CategoryQuickNav.tsx)
  Widget _buildCategoryQuickNav() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            badgeText: 'Danh mục trải nghiệm',
            badgeIcon: Icons.auto_awesome,
            title: 'Bạn đang tìm kiếm điều gì?',
            actionText: 'Tất cả',
            onActionTap: () => _navigateToSearch(),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 105,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quickCategories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final cat = _quickCategories[index];
              return GestureDetector(
                onTap: () => _navigateToSearch(category: cat['name'] as String),
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
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
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: cat['bg'] as Color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        cat['count'] as String,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
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

  // Widget: Featured Collections (Matching Web FeaturedCollectionsSection.tsx)
  Widget _buildFeaturedCollectionsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(
              badgeText: 'Gợi ý độc quyền',
              badgeIcon: Icons.auto_awesome,
              title: 'Bộ sưu tập điểm đến nổi bật',
              actionText: 'Tất cả bộ sưu tập',
              onActionTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CollectionsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CollectionsScreen()),
                );
              },
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
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
                        _tours.isNotEmpty
                            ? _tours.first.imageUrl
                            : 'https://images.unsplash.com/photo-1528127269322-539801943592?w=900&h=600&fit=crop&auto=format',
                        fit: BoxFit.cover,
                      ),
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
                                    '${_tours.length} địa điểm',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _featuredCollection?.title ?? 'Vòng quanh thành phố mang tên Bác',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _featuredCollection?.description ??
                                  'Những trải nghiệm chân thực, sống động nhất tại trái tim Sài Gòn hoa lệ.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget: Regions Section (Matching Web RegionsSection.tsx)
  Widget _buildRegionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            badgeText: 'Khám phá theo vùng miền',
            badgeIcon: Icons.map_rounded,
            title: 'Hành trình 3 miền Bắc - Trung - Nam',
            subtitle: 'Từ đỉnh núi mờ sương Tây Bắc đến vẻ trù phú của miệt vườn',
            actionText: 'Tất cả điểm đến',
            onActionTap: () => _navigateToSearch(),
          ),
        ),
        const SizedBox(height: 16),

        _buildRegionTrack(
          regionName: 'Miền Bắc',
          tagline: 'VÙNG NÚI & ĐỒNG BẰNG',
          destinations: _northDestinations,
        ),
        const SizedBox(height: 20),

        _buildRegionTrack(
          regionName: 'Miền Trung',
          tagline: 'DI SẢN & BIỂN NGỌC',
          destinations: _centralDestinations,
        ),
        const SizedBox(height: 20),

        _buildRegionTrack(
          regionName: 'Miền Nam',
          tagline: 'ĐÔ THỊ & SÔNG NƯỚC',
          destinations: _southDestinations,
        ),
      ],
    );
  }

  Widget _buildRegionTrack({
    required String regionName,
    required String tagline,
    required List<DestinationModel> destinations,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      tagline,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    regionName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _navigateToSearch(region: regionName),
                child: Text(
                  'Xem $regionName →',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: destinations.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final dest = destinations[index];
              return DestinationCard(
                destination: dest,
                width: 220,
                height: 270,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DestinationDetailScreen(destination: dest),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Widget: Cuisine Section (Matching Web CuisineSection.tsx)
  Widget _buildCuisineSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              badgeText: 'Hương vị bản địa',
              badgeIcon: Icons.restaurant_rounded,
              title: 'Ẩm thực 3 miền',
              subtitle: 'Mỗi món ăn là một câu chuyện văn hóa tinh hoa',
              actionText: 'Tất cả quán ngon',
              onActionTap: () => widget.onNavigateTab?.call(2),
            ),
            const SizedBox(height: 12),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _foodRegionFilters.map((tab) {
                  final isSelected = _selectedFoodRegion == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceVariant,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedFoodRegion = tab;
                          _filterFoods();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemCount: _filteredFoods.length > 4 ? 4 : _filteredFoods.length,
              itemBuilder: (context, index) {
                final food = _filteredFoods[index];
                return FoodCard(
                  food: food,
                  onTap: () => widget.onNavigateTab?.call(2),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget: Top Rated Places (Matching Web TopRatedPlacesSection.tsx)
  Widget _buildTopRatedSection() {
    final topList = _northDestinations.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            badgeText: 'Được yêu thích nhất',
            badgeIcon: Icons.military_tech_rounded,
            title: 'Điểm đến đánh giá cao nhất',
            actionText: 'Xem tất cả',
            onActionTap: () => _navigateToSearch(),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: topList.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final dest = topList[index];
              return DestinationCard(
                destination: dest,
                width: 230,
                height: 270,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DestinationDetailScreen(destination: dest),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}


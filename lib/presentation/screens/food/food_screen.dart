import 'package:flutter/material.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/services/travel_api_service.dart';
import '../../widgets/food/food_specialty_card.dart';
import '../../widgets/food/region_food_specialties_section.dart';
import '../destinations/place_detail_screen.dart';

class FoodScreen extends StatefulWidget {
  final String? initialProvince;
  final String? initialRegion;

  const FoodScreen({
    super.key,
    this.initialProvince,
    this.initialRegion,
  });

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final TravelApiService _apiService = TravelApiService();
  final TextEditingController _searchController = TextEditingController();

  List<FoodModel> _allFoods = [];
  List<FoodModel> _filteredFoods = [];
  bool _isLoading = true;

  String _selectedRegion = 'all'; // 'all', 'north', 'central', 'south'
  String _selectedProvince = 'all'; // 'all', 'Hà Nội', 'TP. Hồ Chí Minh', ...
  bool _isGridView = false;

  final List<Map<String, dynamic>> _regions = [
    {'id': 'all', 'name': 'Tất cả 3 miền', 'icon': Icons.public_rounded},
    {'id': 'north', 'name': 'Miền Bắc', 'icon': Icons.location_city_rounded},
    {'id': 'central', 'name': 'Miền Trung', 'icon': Icons.beach_access_rounded},
    {'id': 'south', 'name': 'Miền Nam', 'icon': Icons.wb_sunny_rounded},
  ];

  final List<String> _popularProvinces = [
    'Tất cả',
    'Hà Nội',
    'TP. Hồ Chí Minh',
    'Đà Nẵng',
    'Thừa Thiên Huế',
    'Quảng Nam',
    'Lâm Đồng',
    'Hải Phòng',
    'Ninh Bình',
    'Lào Cai',
    'Khánh Hòa',
    'Cần Thơ',
    'Kiên Giang',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRegion != null) {
      _selectedRegion = widget.initialRegion!;
    }
    if (widget.initialProvince != null) {
      _selectedProvince = widget.initialProvince!;
    }
    _loadFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getFoods();
    if (mounted) {
      setState(() {
        _allFoods = list;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    List<FoodModel> result = List.from(_allFoods);

    // 1. Filter by Region
    if (_selectedRegion != 'all') {
      result = result.where((f) => f.region == _selectedRegion).toList();
    }

    // 2. Filter by Province
    if (_selectedProvince != 'Tất cả' && _selectedProvince != 'all') {
      result = result.where((f) => f.province.toLowerCase().contains(_selectedProvince.toLowerCase())).toList();
    }

    // 3. Search query
    if (query.isNotEmpty) {
      result = result.where((f) {
        final matchName = f.name.toLowerCase().contains(query);
        final matchDesc = f.description.toLowerCase().contains(query);
        final matchProv = f.province.toLowerCase().contains(query);
        final matchPlaces = f.suggestedPlaces.any(
          (p) => p.name.toLowerCase().contains(query) || p.address.toLowerCase().contains(query),
        );
        return matchName || matchDesc || matchProv || matchPlaces;
      }).toList();
    }

    setState(() {
      _filteredFoods = result;
    });
  }

  void _onRegionSelected(String regionId) {
    setState(() {
      _selectedRegion = regionId;
      _selectedProvince = 'Tất cả';
      _applyFilters();
    });
  }

  void _onProvinceSelected(String province) {
    setState(() {
      _selectedProvince = province;
      _applyFilters();
    });
  }

  void _showPlaceDetail(FoodSuggestedPlace place) {
    PlaceModel? matchedPlace;
    try {
      matchedPlace = MockData.places.firstWhere(
        (p) => p.id == place.id || p.name.toLowerCase() == place.name.toLowerCase(),
      );
    } catch (_) {}

    final placeModel = matchedPlace ??
        PlaceModel(
          id: place.id ?? 999,
          name: place.name,
          category: 'Ẩm thực & Cafe',
          location: place.address,
          province: _selectedProvince != 'Tất cả' && _selectedProvince != 'all'
              ? _selectedProvince
              : 'Việt Nam',
          region: _selectedRegion == 'north'
              ? 'Miền Bắc'
              : (_selectedRegion == 'central' ? 'Miền Trung' : 'Miền Nam'),
          type: 'Ẩm thực',
          rating: place.rating,
          reviews: 45,
          price: '40.000đ',
          priceMax: 100000,
          priceRange: '40.000đ - 100.000đ',
          hours: '07:00 - 22:00',
          status: 'Đang mở cửa',
          desc: place.address,
          detailedDescription: 'Địa điểm ẩm thực đặc sản được đánh giá cao.',
          tags: ['Ẩm thực', 'Đặc sản'],
          img: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=600&auto=format&fit=crop',
          mediaUrls: const [
            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=600&auto=format&fit=crop'
          ],
          latitude: place.coordinates != null && place.coordinates!.length >= 2
              ? place.coordinates![0]
              : 21.0285,
          longitude: place.coordinates != null && place.coordinates!.length >= 2
              ? place.coordinates![1]
              : 105.8542,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(place: placeModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final northFoods = _allFoods.where((f) => f.region == 'north').toList();
    final centralFoods = _allFoods.where((f) => f.region == 'central').toList();
    final southFoods = _allFoods.where((f) => f.region == 'south').toList();

    final isDefaultView = _selectedRegion == 'all' &&
        (_selectedProvince == 'Tất cả' || _selectedProvince == 'all') &&
        _searchController.text.isEmpty &&
        !_isGridView;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: Color(0xFF004F32),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khám Phá Ẩm Thực',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Đặc sản 63 tỉnh thành & Quán ngon đề xuất',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_carousel_rounded : Icons.grid_view_rounded,
              color: const Color(0xFF0F172A),
            ),
            tooltip: _isGridView ? 'Chuyển sang chế độ xem theo vùng' : 'Chuyển sang dạng lưới',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF004F32)),
            )
          : RefreshIndicator(
              onRefresh: _loadFoods,
              color: const Color(0xFF004F32),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HERO BANNER
                    _buildHeroBanner(),

                    const SizedBox(height: 16),

                    // 2. SEARCH BAR
                    _buildSearchBar(),

                    const SizedBox(height: 14),

                    // 3. REGION TABS
                    _buildRegionTabs(),

                    const SizedBox(height: 10),

                    // 4. PROVINCE FILTER CHIPS
                    _buildProvinceFilterChips(),

                    const SizedBox(height: 20),

                    // 5. MAIN CONTENT
                    if (isDefaultView) ...[
                      // Multi-region Showcase Matching Share_Locations
                      RegionFoodSpecialtiesSection(
                        regionName: 'Miền Bắc',
                        foods: northFoods,
                        onFoodTap: (food) => _showFoodDetailBottomSheet(context, food),
                        onPlaceTap: _showPlaceDetail,
                      ),
                      const SizedBox(height: 28),
                      RegionFoodSpecialtiesSection(
                        regionName: 'Miền Trung',
                        foods: centralFoods,
                        onFoodTap: (food) => _showFoodDetailBottomSheet(context, food),
                        onPlaceTap: _showPlaceDetail,
                      ),
                      const SizedBox(height: 28),
                      RegionFoodSpecialtiesSection(
                        regionName: 'Miền Nam',
                        foods: southFoods,
                        onFoodTap: (food) => _showFoodDetailBottomSheet(context, food),
                        onPlaceTap: _showPlaceDetail,
                      ),
                      const SizedBox(height: 36),
                    ] else ...[
                      // Filtered List / Grid View
                      _buildFilteredFoodList(),
                      const SizedBox(height: 36),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // =========================================================================
  // 1. HERO BANNER
  // =========================================================================
  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004F32), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004F32).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'TINH HOA ẨM THỰC VIỆT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_allFoods.length} Món đặc sản',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Hương Vị Bản Địa 3 Miền',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Khám phá câu chuyện đằng sau từng món ăn truyền thống và lưu ngay danh sách quán ngon chuẩn vị do người bản xứ giới thiệu.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. SEARCH BAR
  // =========================================================================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => _applyFilters(),
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm món ăn, đặc sản, quán ngon hoặc tỉnh thành...',
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF004F32), size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. REGION TABS
  // =========================================================================
  Widget _buildRegionTabs() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _regions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final region = _regions[index];
          final isSelected = _selectedRegion == region['id'];
          return GestureDetector(
            onTap: () => _onRegionSelected(region['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF004F32) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF004F32) : const Color(0xFFE2E8F0),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF004F32).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    region['icon'] as IconData,
                    size: 14,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    region['name'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 4. PROVINCE FILTER CHIPS
  // =========================================================================
  Widget _buildProvinceFilterChips() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _popularProvinces.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final prov = _popularProvinces[index];
          final isSelected = _selectedProvince == prov;
          return GestureDetector(
            onTap: () => _onProvinceSelected(prov),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  prov,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF065F46) : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 5. FILTERED FOOD LIST (Section / Grid)
  // =========================================================================
  Widget _buildFilteredFoodList() {
    String title = 'Kết Quả Khám Phá';
    if (_selectedProvince != 'Tất cả' && _selectedProvince != 'all') {
      title = 'Đặc Sản $_selectedProvince';
    } else if (_selectedRegion == 'north') {
      title = 'Tinh Hoa Ẩm Thực Miền Bắc';
    } else if (_selectedRegion == 'central') {
      title = 'Tinh Hoa Ẩm Thực Miền Trung';
    } else if (_selectedRegion == 'south') {
      title = 'Tinh Hoa Ẩm Thực Miền Nam';
    }

    if (_filteredFoods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.search_off_rounded, size: 32, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Không tìm thấy món ăn phù hợp',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hãy thử tìm kiếm với từ khóa khác hoặc chọn tỉnh thành khác.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                '${_filteredFoods.length} món',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004F32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Layout: Grid or List
          if (_isGridView)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.52,
              ),
              itemCount: _filteredFoods.length,
              itemBuilder: (context, index) {
                final food = _filteredFoods[index];
                return FoodSpecialtyCard(
                  food: food,
                  width: double.infinity,
                  onTap: () => _showFoodDetailBottomSheet(context, food),
                  onPlaceTap: _showPlaceDetail,
                );
              },
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredFoods.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final food = _filteredFoods[index];
                return FoodSpecialtyCard(
                  food: food,
                  width: double.infinity,
                  onTap: () => _showFoodDetailBottomSheet(context, food),
                  onPlaceTap: _showPlaceDetail,
                );
              },
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. FOOD DETAIL BOTTOM SHEET
  // =========================================================================
  void _showFoodDetailBottomSheet(BuildContext context, FoodModel food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final mediaList = food.allMediaUrls;
        final places = food.suggestedPlaces;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Image Carousel / Hero
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: mediaList.length > 1
                          ? PageView.builder(
                              itemCount: mediaList.length,
                              itemBuilder: (context, idx) {
                                return Image.network(
                                  mediaList[idx],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Icon(Icons.restaurant, size: 40, color: Colors.grey),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Image.network(
                              food.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Center(
                                  child: Icon(Icons.restaurant, size: 40, color: Colors.grey),
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Title & Province
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          food.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      if (food.province.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF6EE7B7)),
                          ),
                          child: Text(
                            food.province,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Price & Rating Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              '${food.rating.toStringAsFixed(1)} (${food.reviewCount} đánh giá)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_offer_outlined, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              food.priceRange,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004F32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Câu chuyện ẩm thực',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    food.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SUGGESTED PLACES LIST
                  if (places.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF004F32)),
                            SizedBox(width: 6),
                            Text(
                              'Địa điểm bán món nức tiếng',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${places.length} quán',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF004F32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...places.map((place) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.restaurant_rounded,
                                color: Color(0xFF004F32),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    place.address,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF6EE7B7)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '★',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        place.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showPlaceDetail(place);
                                  },
                                  child: const Text(
                                    'Chi tiết →',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF004F32),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

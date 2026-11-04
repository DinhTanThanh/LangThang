import 'package:flutter/material.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/region_landing_model.dart';
import '../../../data/services/place_api_service.dart';
import '../../widgets/food/region_food_specialties_section.dart';
import '../../widgets/home/collection_track_section.dart';
import '../../widgets/region/region_blog_section.dart';
import '../../widgets/region/region_hero_bento.dart';
import '../../widgets/region/region_landmarks_section.dart';
import '../../widgets/region/region_search_bar.dart';
import '../../widgets/region/region_spotlight_reviews.dart';
import '../blog/blog_screen.dart';
import 'destinations_screen.dart';
import 'place_detail_screen.dart';
import 'province_screen.dart';
import 'travel_map_screen.dart';

class RegionScreen extends StatefulWidget {
  final String regionSlug;
  final RegionDto? region;

  const RegionScreen({
    super.key,
    required this.regionSlug,
    this.region,
  });

  @override
  State<RegionScreen> createState() => _RegionScreenState();
}

class _RegionScreenState extends State<RegionScreen> {
  final PlaceApiService _apiService = PlaceApiService();
  RegionLandingModel? _regionData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRegionData();
  }

  Future<void> _fetchRegionData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getRegionLanding(widget.regionSlug);
      if (res.success && res.data != null) {
        setState(() {
          _regionData = res.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã có lỗi xảy ra khi tải dữ liệu vùng miền.';
        _isLoading = false;
      });
    }
  }

  void _handleSelectProvince(String province) {
    if (province.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProvinceScreen(provinceName: province),
        ),
      );
    }
  }

  void _handleSearch(String query, String? province) {
    if (query.isEmpty && province != null && province.isNotEmpty) {
      _handleSelectProvince(province);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DestinationsScreen(
          initialSearchQuery: query.isNotEmpty ? query : null,
          initialRegion: _regionData?.name,
          initialProvince: province,
        ),
      ),
    );
  }

  void _handleOpenMap(String? province) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelMapScreen(
          initialRegion: _regionData?.name,
          initialProvince: province,
        ),
      ),
    );
  }

  void _handlePlaceClick(PlaceModel place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(place: place),
      ),
    );
  }

  void _handleLandmarkClick(RegionLandmarkModel landmark) {
    final place = PlaceModel.fromJson({
      'id': landmark.id is int ? landmark.id : (int.tryParse(landmark.id.toString()) ?? 0),
      'name': landmark.name,
      'location': landmark.location.isNotEmpty ? landmark.location : landmark.province,
      'img': landmark.imageUrl ?? '',
      'rating': landmark.rating,
      'reviews': landmark.reviewCount,
      'category': landmark.category ?? 'Điểm đến nổi bật',
      'latitude': landmark.coordinates != null && landmark.coordinates!.isNotEmpty
          ? landmark.coordinates![0]
          : 21.0285,
      'longitude': landmark.coordinates != null && landmark.coordinates!.length > 1
          ? landmark.coordinates![1]
          : 105.8542,
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(place: place),
      ),
    );
  }

  void _handleFoodPlaceClick(FoodSuggestedPlace place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DestinationsScreen(
          initialSearchQuery: place.name,
          initialRegion: _regionData?.name,
        ),
      ),
    );
  }

  void _handleSpotlightMap(RegionSpotlightModel spot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelMapScreen(
          initialSearchQuery: spot.title,
          initialRegion: _regionData?.name,
          initialProvince: spot.province,
        ),
      ),
    );
  }

  void _handleReviewMap(RegionReviewModel review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelMapScreen(
          initialSearchQuery: review.placeName,
          initialRegion: _regionData?.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _regionData?.name ?? (widget.region?.name ?? 'Khám phá vùng miền');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    if (_errorMessage != null || _regionData == null) {
      return _buildErrorState();
    }

    final data = _regionData!;

    return RefreshIndicator(
      onRefresh: _fetchRegionData,
      color: const Color(0xFF004F32),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Bento Grid
            RegionHeroBento(data: data),

            // 2. Search & Province Filter Bar
            RegionSearchBar(
              data: data,
              onSearch: _handleSearch,
              onSelectProvince: _handleSelectProvince,
              onOpenMap: _handleOpenMap,
            ),

            // 3. Featured Collections
            if (data.collections.isNotEmpty) ...[
              for (final col in data.collections)
                if (col.places.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CollectionTrackSection(
                      collection: col,
                      onPlaceTap: _handlePlaceClick,
                    ),
                  ),
            ],

            // 4. Landmarks Section (Địa Điểm Không Thể Bỏ Lỡ)
            if (data.landmarks.isNotEmpty)
              RegionLandmarksSection(
                landmarks: data.landmarks,
                regionName: data.name,
                onLandmarkTap: _handleLandmarkClick,
              ),

            // 5. Food Specialties Section (Tinh Hoa Ẩm Thực)
            if (data.foods.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: RegionFoodSpecialtiesSection(
                  regionName: data.name,
                  foods: data.foods,
                  onPlaceTap: _handleFoodPlaceClick,
                ),
              ),

            // 6. Blog Posts Section (Cẩm Nang & Kinh Nghiệm)
            if (data.blogPosts.isNotEmpty)
              RegionBlogSection(
                posts: data.blogPosts,
                regionName: data.name,
                onPostTap: (post) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BlogScreen(),
                    ),
                  );
                },
                onSeeAllTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BlogScreen(),
                    ),
                  );
                },
              ),

            // 7. Spotlight & Community Reviews
            if (data.spotlight != null || data.reviews.isNotEmpty)
              RegionSpotlightReviews(
                spotlight: data.spotlight,
                reviews: data.reviews,
                onOpenSpotlightMap: _handleSpotlightMap,
                onOpenReviewMap: _handleReviewMap,
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 24,
            width: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 16,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFC0392B), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không thể tải dữ liệu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Không tìm thấy dữ liệu cho vùng miền này.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _fetchRegionData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004F32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Thử lại'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Về trang chủ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

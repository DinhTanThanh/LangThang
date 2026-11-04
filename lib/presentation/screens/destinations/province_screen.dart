import 'package:flutter/material.dart';
import '../../../data/models/api_response.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/province_landing_model.dart';
import '../../../data/models/region_landing_model.dart';
import '../../../data/services/place_api_service.dart';
import '../../widgets/food/region_food_specialties_section.dart';
import '../../widgets/home/collection_track_section.dart';
import '../../widgets/province/province_hero_bento.dart';
import '../../widgets/province/province_itinerary_section.dart';
import '../../widgets/province/province_place_section.dart';
import '../../widgets/province/province_search_bar.dart';
import '../../widgets/region/region_blog_section.dart';
import '../../widgets/region/region_landmarks_section.dart';
import '../../widgets/region/region_spotlight_reviews.dart';
import '../blog/blog_screen.dart';
import 'destinations_screen.dart';
import 'place_detail_screen.dart';
import 'travel_map_screen.dart';

class ProvinceScreen extends StatefulWidget {
  final dynamic provinceId;
  final String? provinceName;
  final String? provinceSlug;

  const ProvinceScreen({
    super.key,
    this.provinceId,
    this.provinceName,
    this.provinceSlug,
  });

  @override
  State<ProvinceScreen> createState() => _ProvinceScreenState();
}

class _ProvinceScreenState extends State<ProvinceScreen> {
  final PlaceApiService _apiService = PlaceApiService();

  ProvinceLandingModel? _landingData;
  List<LookupItemDto> _categories = [];
  List<PlaceModel> _places = [];

  int? _selectedCategoryId;
  String _sortBy = 'rating';

  bool _initialLoading = true;
  bool _placesLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProvinceLanding();
  }

  Future<void> _fetchProvinceLanding() async {
    setState(() {
      _initialLoading = true;
      _errorMessage = null;
    });

    final target = widget.provinceId ?? widget.provinceSlug ?? widget.provinceName ?? 'Đà Nẵng';

    try {
      final results = await Future.wait([
        _apiService.getProvinceLanding(target),
        _apiService.getFilterOptions(),
      ]);

      final landingRes = results[0] as ApiResponse<ProvinceLandingModel>;
      final filterRes = results[1] as ApiResponse<PlaceFilterOptionsDto>;

      if (landingRes.success && landingRes.data != null) {
        if (mounted) {
          setState(() {
            _landingData = landingRes.data;
            if (filterRes.success && filterRes.data != null) {
              _categories = filterRes.data!.categories;
            }
            _initialLoading = false;
          });
          _loadPlaces();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = landingRes.message.isNotEmpty
                ? landingRes.message
                : 'Không thể tải thông tin tỉnh thành.';
            _initialLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Đã có lỗi xảy ra khi tải dữ liệu tỉnh thành.';
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _loadPlaces() async {
    if (_landingData == null) return;

    setState(() => _placesLoading = true);

    try {
      final prov = _landingData!.province;
      final res = await _apiService.searchPlaces(PlaceFilterParams(
        provinceId: prov.id > 0 ? prov.id : null,
        keyword: prov.id > 0 ? null : prov.name,
        categoryId: _selectedCategoryId,
        sortBy: _sortBy == 'rating'
            ? 'rating_desc'
            : _sortBy == 'price_asc'
                ? 'price_asc'
                : 'price_desc',
        pageSize: 48,
      ));

      if (mounted) {
        if (res.success && res.data != null && res.data!.isNotEmpty) {
          setState(() {
            _places = res.data!;
            _placesLoading = false;
          });
        } else {
          // Fallback mapped from landmarks if search returns empty
          if (_landingData!.landmarks.isNotEmpty) {
            final mapped = _landingData!.landmarks.asMap().entries.map((entry) {
              final lm = entry.value;
              return PlaceModel.fromJson({
                'id': lm.id is int ? lm.id : int.tryParse(lm.id.toString()) ?? (entry.key + 1),
                'name': lm.name,
                'location': lm.location.isNotEmpty ? lm.location : prov.name,
                'province': prov.name,
                'img': lm.imageUrl ?? (lm.mediaUrls.isNotEmpty ? lm.mediaUrls.first : ''),
                'rating': lm.rating,
                'reviews': lm.reviewCount,
                'category': lm.category ?? 'Danh lam thắng cảnh',
                'latitude': lm.coordinates != null && lm.coordinates!.isNotEmpty ? lm.coordinates![0] : 16.0544,
                'longitude': lm.coordinates != null && lm.coordinates!.length > 1 ? lm.coordinates![1] : 108.2022,
              });
            }).toList();

            setState(() {
              _places = mapped;
              _placesLoading = false;
            });
          } else {
            setState(() {
              _places = [];
              _placesLoading = false;
            });
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _placesLoading = false);
      }
    }
  }

  void _handleSearch(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DestinationsScreen(
          initialSearchQuery: query.isNotEmpty ? query : null,
          initialProvince: _landingData?.province.name,
        ),
      ),
    );
  }

  void _handleOpenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelMapScreen(
          initialProvince: _landingData?.province.name,
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
      'img': landmark.imageUrl ?? (landmark.mediaUrls.isNotEmpty ? landmark.mediaUrls.first : ''),
      'rating': landmark.rating,
      'reviews': landmark.reviewCount,
      'category': landmark.category ?? 'Điểm đến nổi bật',
      'latitude': landmark.coordinates != null && landmark.coordinates!.isNotEmpty ? landmark.coordinates![0] : 16.0544,
      'longitude': landmark.coordinates != null && landmark.coordinates!.length > 1 ? landmark.coordinates![1] : 108.2022,
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
          initialProvince: _landingData?.province.name,
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
          initialProvince: spot.province.isNotEmpty ? spot.province : _landingData?.province.name,
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
          initialProvince: _landingData?.province.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _landingData?.province.name ?? widget.provinceName ?? 'Khám phá tỉnh thành';

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
    if (_initialLoading) {
      return _buildLoadingSkeleton();
    }

    if (_errorMessage != null || _landingData == null) {
      return _buildErrorState();
    }

    final data = _landingData!;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchProvinceLanding();
      },
      color: const Color(0xFF004F32),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Bento Grid
            ProvinceHeroBento(data: data),

            // 2. Search & Province Filter Bar
            ProvinceSearchBar(
              province: data.province,
              onSearch: _handleSearch,
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
                regionName: data.province.name,
                onLandmarkTap: _handleLandmarkClick,
              ),

            // 5. Food Specialties Section (Tinh Hoa Ẩm Thực)
            if (data.foods.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: RegionFoodSpecialtiesSection(
                  regionName: data.province.name,
                  foods: data.foods,
                  onPlaceTap: _handleFoodPlaceClick,
                ),
              ),

            // 6. Province Itinerary Section (Lịch Trình Khám Phá)
            if (data.itineraries.isNotEmpty)
              ProvinceItinerarySection(
                provinceName: data.province.name,
                itineraries: data.itineraries,
              ),

            // 7. Blog Posts Section (Cẩm Nang & Kinh Nghiệm)
            if (data.blogPosts.isNotEmpty)
              RegionBlogSection(
                posts: data.blogPosts,
                regionName: data.province.name,
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

            // 8. Province Places Section (Địa Điểm Nổi Bật Tại {provinceName} - Batch 12)
            ProvincePlaceSection(
              places: _places,
              provinceName: data.province.name,
              categories: _categories,
              selectedCategoryId: _selectedCategoryId,
              onSelectCategory: (catId) {
                setState(() => _selectedCategoryId = catId);
                _loadPlaces();
              },
              sortBy: _sortBy,
              onSortChange: (sort) {
                setState(() => _sortBy = sort);
                _loadPlaces();
              },
              loading: _placesLoading,
            ),

            // 9. Spotlight & Community Reviews
            if (data.spotlight != null || data.reviews.isNotEmpty)
              RegionSpotlightReviews(
                spotlight: data.spotlight,
                reviews: data.reviews,
                onOpenSpotlightMap: _handleSpotlightMap,
                onOpenReviewMap: _handleReviewMap,
              ),

            const SizedBox(height: 36),
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
            width: 160,
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
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 180,
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
              _errorMessage ?? 'Không tìm thấy dữ liệu cho tỉnh thành này.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _fetchProvinceLanding,
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
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

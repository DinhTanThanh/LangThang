import 'package:flutter/material.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/report_model.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/favorite_api_service.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/recent_history_service.dart';
import '../../../data/services/device_context_service.dart';
import '../../widgets/mapbox_interactive_map.dart';
import '../../widgets/review/place_detail_reviews_section.dart';
import '../../widgets/report/report_modal_sheet.dart';
import '../../widgets/place/share_place_modal.dart';
import '../../widgets/place/record_visit_modal.dart';
import '../../widgets/itinerary/add_place_to_trip_sheet.dart';
import '../../widgets/common/recent_visited_floating_dock.dart';
import '../auth/login_screen.dart';
import '../itineraries/itineraries_screen.dart';
import 'travel_map_screen.dart';

class PlaceDetailScreen extends StatefulWidget {
  final PlaceModel place;

  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late PlaceModel _place;
  bool _isSaved = false;
  bool _isVisited = false;
  List<PlaceModel> _relatedPlaces = [];
  bool _isLoadingRelated = true;

  late double _currentRating;
  late int _currentReviewCount;
  PlaceReviewSummaryModel? _reviewSummary;

  final GlobalKey<MapboxInteractiveMapState> _miniMapKey =
      GlobalKey<MapboxInteractiveMapState>();

  List<String> _galleryImages = [];
  final ScrollController _similarScrollController = ScrollController();

  @override
  void dispose() {
    _similarScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _place = widget.place;
    _isSaved = widget.place.isSaved;
    _isVisited = widget.place.isVisited;
    _currentRating = widget.place.rating > 0 ? widget.place.rating : 5.0;
    _currentReviewCount = widget.place.reviews;

    // Initialize gallery images from place model
    if (_place.mediaUrls.isNotEmpty) {
      _galleryImages = List.from(_place.mediaUrls);
    } else if (_place.img.isNotEmpty) {
      _galleryImages = [_place.img];
    }

    _checkInitialFavorite();
    _checkInitialVisited();
    _fetchPlaceDetail();
    _fetchRelatedPlaces();
    _fetchReviews();
    RecentHistoryService().recordAccessHistory(widget.place);
    DeviceContextService().recordVisitedPlace(widget.place);
  }

  Future<void> _checkInitialVisited() async {
    try {
      final res = await UserProfileApiService().getMyVisitLogs();
      if (res.success && res.data != null && mounted) {
        final hasVisited = res.data!.any((log) => log.placeId == widget.place.id);
        if (hasVisited) {
          setState(() => _isVisited = true);
        }
      }
    } catch (_) {}
  }

  Future<void> _checkInitialFavorite() async {
    try {
      final isFav = await FavoriteApiService().isFavorite(1, widget.place.id);
      if (mounted && (isFav || _place.isSaved)) {
        setState(() => _isSaved = isFav || _place.isSaved);
      }
    } catch (_) {}
  }

  Future<void> _fetchPlaceDetail() async {
    try {
      final isFav = await FavoriteApiService().isFavorite(1, widget.place.id);
      final res = await PlaceApiService().getPlaceDetail(widget.place.id);
      if (mounted && res.data != null) {
        RecentHistoryService().recordAccessHistory(res.data!);
        setState(() {
          _place = res.data!;
          _isSaved = res.data!.isSaved || isFav;
          _isVisited = res.data!.isVisited || _isVisited;
          final fetchedMedia = _place.mediaUrls.where((u) => u.trim().isNotEmpty).toList();
          if (fetchedMedia.isNotEmpty) {
            _galleryImages = fetchedMedia;
          } else if (_place.img.isNotEmpty) {
            _galleryImages = [_place.img];
          }
          if (_place.rating > 0) {
            _currentRating = _place.rating;
          }
          if (_place.reviews > 0) {
            _currentReviewCount = _place.reviews;
          }
        });
      }
    } catch (e) {
      debugPrint('[PlaceDetailScreen] _fetchPlaceDetail error: $e');
    }
  }

  Future<void> _fetchReviews() async {
    try {
      final res = await PlaceApiService().getPlaceReviews(
        widget.place.id,
        page: 1,
        pageSize: 10,
      );
      if (mounted && res.data != null) {
        setState(() {
          _reviewSummary = res.data;
          if (res.data!.totalReviews > 0) {
            _currentReviewCount = res.data!.totalReviews;
            if (res.data!.avgRating > 0) {
              _currentRating = res.data!.avgRating;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[PlaceDetailScreen] _fetchReviews error: $e');
    }
  }

  Future<void> _fetchRelatedPlaces() async {
    try {
      setState(() => _isLoadingRelated = true);
      final similar = await PlaceApiService().getSimilarPlaces(widget.place.id, topK: 12, radiusKm: 30);
      if (mounted && similar.isNotEmpty) {
        setState(() {
          _relatedPlaces = similar.where((p) => p.id != widget.place.id).toList();
          _isLoadingRelated = false;
        });
        return;
      }

      final res = await PlaceApiService().searchPlaces(
        PlaceFilterParams(
          keyword: widget.place.province.isNotEmpty
              ? widget.place.province
              : (widget.place.region.isNotEmpty ? widget.place.region : null),
          pageSize: 12,
          sortBy: 'rating_desc',
        ),
      );
      if (mounted) {
        setState(() {
          if (res.data != null && res.data!.isNotEmpty) {
            _relatedPlaces = res.data!.where((p) => p.id != widget.place.id).take(12).toList();
          }
          _isLoadingRelated = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRelated = false);
      }
    }
  }

  String _formatReviews(int count) {
    if (count <= 0) return '0';
    final str = count.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  void _handleShare() {
    SharePlaceModal.show(context, place: _place);
  }

  void _handleAddToTrip() {
    AddPlaceToTripSheet.show(context, place: _place);
  }

  Future<void> _handleToggleVisit() async {
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng đăng nhập để ghi nhận điểm đến.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (mounted) {
        _checkInitialVisited();
      }
      return;
    }

    final recorded = await RecordVisitModal.show(
      context,
      place: _place,
      onRecorded: () {
        if (mounted) {
          setState(() => _isVisited = true);
        }
      },
    );

    if (recorded == true && mounted) {
      setState(() => _isVisited = true);
    }
  }

  Future<void> _handleToggleSave() async {
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Phiên đăng nhập đã hết hạn hoặc bạn chưa đăng nhập. Đang chuyển đến trang đăng nhập...'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (mounted) {
        _checkInitialFavorite();
        _fetchPlaceDetail();
      }
      return;
    }

    final targetState = !_isSaved;
    setState(() => _isSaved = targetState);

    try {
      final res = targetState
          ? await PlaceApiService().savePlace(_place.id, place: _place)
          : await PlaceApiService().unsavePlace(_place.id);

      if (!mounted) return;
      if (!res.success) {
        setState(() => _isSaved = !targetState);

        final isAuthExpired = res.code == '401' ||
            res.message.toLowerCase().contains('hết hạn') ||
            res.message.toLowerCase().contains('đăng nhập') ||
            res.message.toLowerCase().contains('unauthorized');

        if (isAuthExpired) {
          await AuthService().logout();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục.'),
              backgroundColor: Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          if (mounted) {
            _checkInitialFavorite();
            _fetchPlaceDetail();
          }
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'Không thể lưu vào database.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetState
                ? (res.message.isNotEmpty ? res.message : 'Đã thêm "${_place.name}" vào danh sách yêu thích!')
                : (res.message.isNotEmpty ? res.message : 'Đã bỏ yêu thích địa điểm.'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: targetState ? const Color(0xFF047857) : const Color(0xFF374151),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaved = !targetState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối máy chủ: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final allImgs = _galleryImages.isNotEmpty
        ? _galleryImages
        : (place.img.isNotEmpty ? [place.img] : <String>[]);

    final totalReviews = _reviewSummary?.totalReviews ?? _currentReviewCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 100,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_back_ios_new, size: 15, color: Color(0xFF111827)),
                SizedBox(width: 4),
                Text(
                  'Quay lại',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Chia sẻ',
            icon: const Icon(Icons.share_outlined, size: 20, color: Color(0xFF374151)),
            onPressed: _handleShare,
          ),
          IconButton(
            tooltip: _isVisited ? 'Đã ghi nhận' : 'Ghi nhận điểm đến',
            icon: Icon(
              _isVisited ? Icons.event_available : Icons.calendar_today_outlined,
              size: 20,
              color: _isVisited ? const Color(0xFF047857) : const Color(0xFF374151),
            ),
            onPressed: _handleToggleVisit,
          ),
          IconButton(
            tooltip: _isSaved ? 'Đã yêu thích' : 'Yêu thích',
            icon: Icon(
              _isSaved ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: _isSaved ? const Color(0xFFE11D48) : const Color(0xFF374151),
            ),
            onPressed: _handleToggleSave,
          ),
          IconButton(
            tooltip: 'Báo cáo',
            icon: const Icon(Icons.flag_outlined, size: 20, color: Color(0xFF6B7280)),
            onPressed: () => _showReportModal(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gallery Component
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _buildGallery(allImgs),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Header Overview & Actions
                      _buildHeaderOverview(place, totalReviews),
                      const SizedBox(height: 16),

                      // 2. Overview Card: Description & Highlights & Amenities
                      _buildOverviewCard(place),
                      const SizedBox(height: 16),

                      // 3. Contact & Map Sidebar
                      _buildSidebarCard(place),
                      const SizedBox(height: 20),

                      // 4. Similar Places Section (Matching Share_Locations PlaceDetailRelated.tsx)
                      if (_isLoadingRelated || _relatedPlaces.isNotEmpty) ...[
                        _buildSimilarPlacesSection(),
                        const SizedBox(height: 24),
                      ],

                      // 5. Reviews & Ratings Section (Matching Share_Locations PlaceDetailReviews.tsx)
                      PlaceDetailReviewsSection(
                        placeId: place.id,
                        placeName: place.name,
                        avgRating: _currentRating,
                        totalReviews: totalReviews,
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Dock: Đã xem gần đây
          RecentVisitedFloatingDock(
            onOpenProfile: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),

      // Sticky Bottom Bar
      bottomNavigationBar: _buildStickyBottomBar(place),
    );
  }

  // ==================== 1. HEADER & ACTION BUTTONS ====================
  Widget _buildHeaderOverview(PlaceModel place, int totalReviews) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          // Badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  place.category.isNotEmpty
                      ? place.category
                      : (place.type.isNotEmpty ? place.type : 'Địa điểm nổi bật'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  place.province.isNotEmpty
                      ? place.province
                      : (place.region.isNotEmpty ? place.region : 'Việt Nam'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Place Name
          Text(
            place.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              letterSpacing: -0.4,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),

          // Rating & Address Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 3),
              Text(
                _currentRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${_formatReviews(totalReviews)} đánh giá)',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(width: 6),
              const Text('•', style: TextStyle(color: Color(0xFFD1D5DB))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  place.location.isNotEmpty ? place.location : place.province,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // Actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _handleShare,
                  icon: const Icon(Icons.share_outlined, size: 15, color: Color(0xFF374151)),
                  label: const Text(
                    'Chia sẻ',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),

                OutlinedButton.icon(
                  onPressed: _handleToggleVisit,
                  icon: Icon(
                    _isVisited ? Icons.event_available : Icons.calendar_today_outlined,
                    size: 15,
                    color: _isVisited ? const Color(0xFF047857) : const Color(0xFF4B5563),
                  ),
                  label: Text(
                    _isVisited ? 'Đã ghi nhận' : 'Ghi nhận điểm đến',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _isVisited ? const Color(0xFF047857) : const Color(0xFF374151),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    side: BorderSide(
                      color: _isVisited ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: _isVisited ? const Color(0xFFECFDF5) : Colors.white,
                  ),
                ),
                const SizedBox(width: 8),

                OutlinedButton.icon(
                  onPressed: _handleToggleSave,
                  icon: Icon(
                    _isSaved ? Icons.favorite : Icons.favorite_border,
                    size: 15,
                    color: _isSaved ? const Color(0xFFE11D48) : const Color(0xFF374151),
                  ),
                  label: Text(
                    _isSaved ? 'Đã yêu thích' : 'Yêu thích',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _isSaved ? const Color(0xFFE11D48) : const Color(0xFF374151),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    side: BorderSide(
                      color: _isSaved ? const Color(0xFFFECDD3) : const Color(0xFFE5E7EB),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: _isSaved ? const Color(0xFFFFF1F2) : Colors.white,
                  ),
                ),
                const SizedBox(width: 8),

                OutlinedButton.icon(
                  onPressed: _handleAddToTrip,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 15, color: Color(0xFF047857)),
                  label: const Text(
                    'Lên lịch trình',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: const Color(0xFFECFDF5),
                  ),
                ),
                const SizedBox(width: 8),

                OutlinedButton(
                  onPressed: () => _showReportModal(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.white,
                  ),
                  child: const Icon(Icons.flag_outlined, size: 16, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2. OVERVIEW CARD ====================
  Widget _buildOverviewCard(PlaceModel place) {
    final descriptionText = place.detailedDescription.isNotEmpty
        ? place.detailedDescription
        : (place.desc.isNotEmpty
            ? place.desc
            : 'Điểm đến du lịch và văn hóa đặc sắc được du khách yêu thích khi ghé thăm ${place.province.isNotEmpty ? place.province : place.location}.');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          const Text(
            'Giới thiệu tổng quan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            descriptionText,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.65,
            ),
          ),

          if (place.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: place.tags.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    '#$t',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== 3. CONTACT & MAP SIDEBAR ====================
  Widget _buildSidebarCard(PlaceModel place) {
    final isOpen = place.status.toLowerCase().contains('mở') ||
        place.status.toLowerCase().contains('hoạt động') ||
        place.status.toLowerCase().contains('open') ||
        place.status.toLowerCase().contains('approved');

    final hours = place.hours.isNotEmpty ? place.hours : '08:00 – 17:00 (Hàng ngày)';
    final phone = place.phoneNumber.isNotEmpty ? place.phoneNumber : '1900 6868';
    final website = place.website.isNotEmpty ? place.website : 'https://langthang.vn';

    final lat = place.latitude != 0.0 ? place.latitude : 21.0285;
    final lng = place.longitude != 0.0 ? place.longitude : 105.8542;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          const Text(
            'Thông tin khác',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),

          // 1. Giờ hoạt động
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Giờ hoạt động',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          hours,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isOpen ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOpen ? 'Đang mở' : 'Tạm đóng',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isOpen ? const Color(0xFF065F46) : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Số điện thoại
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Số điện thoại',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Website
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.language_rounded, size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trang thông tin',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      website.replaceAll('https://', '').replaceAll('http://', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 14),

          // 4. Map preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Text(
                    'Vị trí trên bản đồ',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TravelMapScreen(
                        initialPlace: place,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Xem toàn bộ bản đồ',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.fullscreen_rounded, size: 14, color: Color(0xFF059669)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Mini Interactive Map with Pin and Smooth Zoom
          Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Interactive Vector Tile Map
                MapboxInteractiveMap(
                  key: _miniMapKey,
                  initialLat: lat,
                  initialLng: lng,
                  initialZoom: 14.5,
                  customMarkers: [
                    _buildMiniMapMarker(place, lat, lng),
                  ],
                ),

                // Mapbox Brand Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.public, size: 11, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text(
                          'Mapbox',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tap to Expand Fullscreen button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TravelMapScreen(
                            initialPlace: place,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.open_in_full, size: 11, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Xem toàn màn hình',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Smooth Map Controls (Zoom In, Zoom Out, Recenter Pin)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zoom In
                        InkWell(
                          onTap: () => _miniMapKey.currentState?.zoomIn(),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.add, size: 16, color: Color(0xFF111827)),
                          ),
                        ),
                        Container(height: 1, width: 18, color: const Color(0xFFE5E7EB)),
                        // Zoom Out
                        InkWell(
                          onTap: () => _miniMapKey.currentState?.zoomOut(),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.remove, size: 16, color: Color(0xFF111827)),
                          ),
                        ),
                        Container(height: 1, width: 18, color: const Color(0xFFE5E7EB)),
                        // Recenter Pin
                        InkWell(
                          onTap: () => _miniMapKey.currentState?.flyTo(lat, lng, 14.5),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.my_location, size: 14, color: Color(0xFF059669)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  place.location.isNotEmpty ? place.location : place.province,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TravelMapScreen(
                        initialPlace: place,
                        initialSearchQuery: place.name,
                        autoStartDirections: true,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF059669), width: 1.2),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Chỉ đường',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.open_in_new, size: 12, color: Color(0xFF059669)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItinerariesScreen(
                      initialKeyword: place.province.isNotEmpty
                          ? place.province
                          : (place.region.isNotEmpty ? place.region : place.name),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.explore_outlined, size: 16, color: Colors.white),
              label: const Text(
                'Xem lịch trình gợi ý đến đây',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  MapboxCustomMarker _buildMiniMapMarker(PlaceModel place, double lat, double lng) {
    return MapboxCustomMarker(
      id: place.id.toString(),
      latitude: lat,
      longitude: lng,
      alignmentOffset: const Offset(-0.5, -0.9),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TravelMapScreen(
              initialPlace: place,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected / Focused Place Label Badge
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (place.rating > 0) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                  Text(
                    place.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Emerald Map Marker Pin
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on,
              size: 17,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 5. SIMILAR PLACES (Matching Share_Locations PlaceDetailRelated.tsx) ====================
  Widget _buildSimilarPlacesSection() {
    if (!_isLoadingRelated && _relatedPlaces.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // Section Header with Left/Right Scroll Arrows
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Địa Điểm Tương Tự Có Thể Bạn Sẽ Thích',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildScrollArrowButton(
                    icon: Icons.arrow_back,
                    onTap: () {
                      if (_similarScrollController.hasClients) {
                        _similarScrollController.animateTo(
                          (_similarScrollController.offset - 200 * 1.5).clamp(
                            0.0,
                            _similarScrollController.position.maxScrollExtent,
                          ),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildScrollArrowButton(
                    icon: Icons.arrow_forward,
                    onTap: () {
                      if (_similarScrollController.hasClients) {
                        _similarScrollController.animateTo(
                          (_similarScrollController.offset + 200 * 1.5).clamp(
                            0.0,
                            _similarScrollController.position.maxScrollExtent,
                          ),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Horizontal Carousel: Loading Skeleton or Cards List
          if (_isLoadingRelated)
            _buildSimilarPlacesSkeleton()
          else
            SizedBox(
              height: 255,
              child: ListView.separated(
                controller: _similarScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _relatedPlaces.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = _relatedPlaces[index];
                  return _SimilarPlaceItemCard(
                    place: item,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaceDetailScreen(place: item),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSimilarPlacesSkeleton() {
    return SizedBox(
      height: 255,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 195,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScrollArrowButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          hoverColor: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
          child: Center(
            child: Icon(
              icon,
              size: 15,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== STICKY BOTTOM ACTION BAR ====================
  Widget _buildStickyBottomBar(PlaceModel place) {
    final isOpen = place.status.toLowerCase().contains('mở') ||
        place.status.toLowerCase().contains('hoạt động') ||
        place.status.toLowerCase().contains('open') ||
        place.status.toLowerCase().contains('approved');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.price.isNotEmpty ? place.price : 'Miễn phí',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF059669),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${place.priceRange} · ${isOpen ? "Đang mở cửa" : "Tạm đóng"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOpen ? const Color(0xFF059669) : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TravelMapScreen(
                      initialPlace: place,
                      initialSearchQuery: place.name,
                      autoStartDirections: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.navigation_rounded, size: 15, color: Color(0xFF059669)),
              label: const Text(
                'Chỉ đường',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF059669),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF059669)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),

            ElevatedButton.icon(
              onPressed: _handleAddToTrip,
              icon: const Icon(Icons.add_location_alt_rounded, size: 15, color: Colors.white),
              label: const Text(
                'Thêm vào chuyến đi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== GALLERY BENTO COMPONENT ====================
  Widget _buildGallery(List<String> imgs) {
    if (imgs.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFF3F4F6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_camera_outlined, size: 36, color: Color(0xFF9CA3AF)),
              SizedBox(height: 6),
              Text(
                'Chưa có hình ảnh nào cho địa điểm này',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (imgs.length == 1) {
      return Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFF3F4F6),
        ),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onTap: () => _openFullScreenGallery(imgs, 0),
          child: Image.network(
            imgs[0],
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFE5E7EB),
              child: const Icon(Icons.photo, color: Color(0xFF9CA3AF), size: 36),
            ),
          ),
        ),
      );
    }

    if (imgs.length == 2) {
      return Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFF3F4F6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openFullScreenGallery(imgs, 0),
                    child: Image.network(
                      imgs[0],
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openFullScreenGallery(imgs, 1),
                    child: Image.network(
                      imgs[1],
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: _buildViewAllPhotosButton(imgs),
            ),
          ],
        ),
      );
    }

    // 3 or more images: Bento grid
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF3F4F6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              Expanded(
                flex: 6,
                child: GestureDetector(
                  onTap: () => _openFullScreenGallery(imgs, 0),
                  child: Image.network(
                    imgs[0],
                    fit: BoxFit.cover,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(Icons.photo, color: Color(0xFF9CA3AF), size: 36),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openFullScreenGallery(imgs, 1),
                        child: Image.network(
                          imgs[1],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openFullScreenGallery(imgs, 2),
                        child: Image.network(
                          imgs[2],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Positioned(
            bottom: 10,
            right: 10,
            child: _buildViewAllPhotosButton(imgs),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllPhotosButton(List<String> imgs) {
    return GestureDetector(
      onTap: () => _openFullScreenGallery(imgs, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_view_rounded, size: 12, color: Color(0xFF111827)),
            const SizedBox(width: 5),
            Text(
              'Tất cả ${imgs.length} ảnh',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenGallery(List<String> imgs, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenGalleryViewer(images: imgs, initialIndex: initialIndex),
      ),
    );
  }

  // ==================== REPORT MODAL ====================
  void _showReportModal(BuildContext context) {
    ReportModalSheet.show(
      context,
      targetInfo: ReportTargetInfo.forPlace(
        id: _place.id,
        name: _place.name,
        address: _place.location.isNotEmpty ? _place.location : _place.province,
        rating: _currentRating > 0 ? _currentRating : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULL SCREEN GALLERY VIEWER
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGalleryViewer({required this.images, required this.initialIndex});

  @override
  State<_FullScreenGalleryViewer> createState() => _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends State<_FullScreenGalleryViewer> {
  late PageController _pageController;
  late ScrollController _thumbScrollController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _thumbScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (_thumbScrollController.hasClients) {
      _thumbScrollController.animateTo(
        (index * 64.0).clamp(0.0, _thumbScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Ảnh ${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.photo_outlined,
                        color: Colors.white54,
                        size: 60,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (widget.images.length > 1)
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.black.withValues(alpha: 0.8),
              child: ListView.builder(
                controller: _thumbScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.images.length,
                itemBuilder: (context, idx) {
                  final isSelected = idx == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        idx,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF059669) : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Opacity(
                        opacity: isSelected ? 1.0 : 0.5,
                        child: Image.network(
                          widget.images[idx],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: Colors.white10),
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
}

class _SimilarPlaceItemCard extends StatefulWidget {
  final PlaceModel place;
  final VoidCallback onTap;

  const _SimilarPlaceItemCard({
    required this.place,
    required this.onTap,
  });

  @override
  State<_SimilarPlaceItemCard> createState() => _SimilarPlaceItemCardState();
}

class _SimilarPlaceItemCardState extends State<_SimilarPlaceItemCard> {
  int _activeImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final mediaList = place.mediaUrls.isNotEmpty
        ? place.mediaUrls
        : (place.img.isNotEmpty ? [place.img] : []);
    final hasMultipleImages = mediaList.length > 1;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 195,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with aspect ratio 1:1 and rounded-2xl (Matching PlaceDetailRelated.tsx)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (mediaList.isNotEmpty)
                      Image.network(
                        mediaList[_activeImageIndex % mediaList.length],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(Icons.explore_outlined, color: Color(0xFF94A3B8), size: 32),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(Icons.explore_outlined, color: Color(0xFF94A3B8), size: 32),
                        ),
                      ),

                    // Multiple images indicator & arrows
                    if (hasMultipleImages) ...[
                      Positioned(
                        left: 6,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeImageIndex = (_activeImageIndex == 0)
                                    ? mediaList.length - 1
                                    : _activeImageIndex - 1;
                              });
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chevron_left_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeImageIndex = (_activeImageIndex == mediaList.length - 1)
                                    ? 0
                                    : _activeImageIndex + 1;
                              });
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF020617).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_activeImageIndex + 1}/${mediaList.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Place Name
            Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 3),

            // Rating row: Star + rating + bullet + reviewCount
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                const SizedBox(width: 3),
                Text(
                  place.rating > 0 ? place.rating.toStringAsFixed(1) : '4.5',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '·',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${place.reviews > 0 ? place.reviews : 8} đánh giá',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}





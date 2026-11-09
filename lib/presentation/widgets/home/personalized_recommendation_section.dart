import 'package:flutter/material.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/recommendation_api_service.dart';

class PersonalizedRecommendationSection extends StatefulWidget {
  final DualContextHomeFeedResult? dualFeed;
  final List<PlaceModel> places;
  final bool isPersonalized;
  final bool isLoading;
  final ValueChanged<PlaceModel> onPlaceTap;

  const PersonalizedRecommendationSection({
    super.key,
    this.dualFeed,
    this.places = const [],
    this.isPersonalized = false,
    this.isLoading = false,
    required this.onPlaceTap,
  });

  @override
  State<PersonalizedRecommendationSection> createState() => _PersonalizedRecommendationSectionState();
}

class _PersonalizedRecommendationSectionState extends State<PersonalizedRecommendationSection> {
  final ScrollController _legacyScrollController = ScrollController();
  final ScrollController _shelf1ScrollController = ScrollController();
  final ScrollController _shelf2ScrollController = ScrollController();

  int? _activeIntentProvinceId;

  @override
  void dispose() {
    _legacyScrollController.dispose();
    _shelf1ScrollController.dispose();
    _shelf2ScrollController.dispose();
    super.dispose();
  }

  void _scroll(ScrollController controller, double direction) {
    if (!controller.hasClients) return;
    final currentOffset = controller.offset;
    const itemWidth = 200.0;
    final targetOffset = (currentOffset + (direction * itemWidth * 2)).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    controller.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildLoadingSkeleton(),
      );
    }

    final feed = widget.dualFeed;
    final hasShelf1 = feed != null && feed.shelf1NearbyPlaces.isNotEmpty;

    // Phân tích danh sách nhóm điểm đến Kệ 2
    List<IntentDestinationShelfGroup> intentGroups = [];
    if (feed != null && feed.shelf2IntentGroups.isNotEmpty) {
      intentGroups = feed.shelf2IntentGroups.where((g) => g.places.isNotEmpty).toList();
    } else if (feed != null && feed.shelf2IntentPlaces.isNotEmpty) {
      intentGroups = [
        IntentDestinationShelfGroup(
          provinceId: feed.intentProvinceId ?? 0,
          provinceName: feed.intentProvinceName ?? 'Điểm đến',
          intentLabel: feed.intentLabel ?? feed.intentProvinceName ?? 'sắp tới',
          places: feed.shelf2IntentPlaces,
        )
      ];
    }

    final hasShelf2 = intentGroups.isNotEmpty;

    // Nếu không có dữ liệu Dual-Context, fallback hiển thị danh sách đơn lẻ
    if (!hasShelf1 && !hasShelf2) {
      if (widget.places.isEmpty) return const SizedBox.shrink();
      return _buildLegacySingleShelf();
    }

    // Chọn nhóm Kệ 2 đang được kích hoạt (hoặc mặc định nhóm đầu tiên)
    IntentDestinationShelfGroup? activeGroup;
    if (hasShelf2) {
      activeGroup = intentGroups.firstWhere(
        (g) => g.provinceId == _activeIntentProvinceId,
        orElse: () => intentGroups.first,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KỆ 1: Địa điểm quanh vị trí GPS người dùng (Nearby Physical Context)
        if (hasShelf1) ...[
          _buildShelf1Nearby(feed.shelf1NearbyPlaces, feed.physicalProvinceName),
          const SizedBox(height: 28),
        ],

        // 2. KỆ 2: Địa điểm dành cho chuyến đi ý định (Destination Intent Context)
        if (hasShelf2 && activeGroup != null) ...[
          _buildShelf2Intent(intentGroups, activeGroup),
        ],
      ],
    );
  }

  /// Kệ 1: Quanh bạn tại [Tỉnh/Thành phố]
  Widget _buildShelf1Nearby(List<PlaceModel> nearbyPlaces, String? provinceName) {
    final title = 'Quanh bạn tại ${provinceName ?? 'Khu vực lân cận'}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.near_me_rounded, size: 10, color: Color(0xFF047857)),
                          SizedBox(width: 3),
                          Text(
                            'Vị trí GPS thời gian thực',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  _buildArrowButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => _scroll(_shelf1ScrollController, -1),
                    tooltip: 'Lướt sang trái',
                  ),
                  const SizedBox(width: 6),
                  _buildArrowButton(
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => _scroll(_shelf1ScrollController, 1),
                    tooltip: 'Lướt sang phải',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 275,
            child: ListView.separated(
              controller: _shelf1ScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: nearbyPlaces.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final place = nearbyPlaces[index];
                return _RecommendationPlaceCard(
                  place: place,
                  showDistance: true,
                  onTap: () => widget.onPlaceTap(place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Kệ 2: Dành cho chuyến đi [Điểm đến] với Tabs lựa chọn đa tỉnh thành
  Widget _buildShelf2Intent(
    List<IntentDestinationShelfGroup> groups,
    IntentDestinationShelfGroup activeGroup,
  ) {
    final title = 'Dành cho chuyến đi ${activeGroup.intentLabel.isNotEmpty ? activeGroup.intentLabel : activeGroup.provinceName}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBAE6FD), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flight_takeoff_rounded, size: 10, color: Color(0xFF0369A1)),
                          SizedBox(width: 3),
                          Text(
                            'Ý định khám phá & Du lịch',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  _buildArrowButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => _scroll(_shelf2ScrollController, -1),
                    tooltip: 'Lướt sang trái',
                  ),
                  const SizedBox(width: 6),
                  _buildArrowButton(
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => _scroll(_shelf2ScrollController, 1),
                    tooltip: 'Lướt sang phải',
                  ),
                ],
              ),
            ],
          ),

          // Tabs chuyển đổi nhanh giữa các điểm đến đang quan tâm
          if (groups.length > 1) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: groups.map((g) {
                  final isActive = g.provinceId == activeGroup.provinceId;
                  final labelText = g.intentLabel.isNotEmpty ? g.intentLabel : g.provinceName;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _activeIntentProvinceId = g.provinceId;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF047857) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                            width: 1.1,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF047857).withValues(alpha: 0.25),
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
                              Icons.location_on_rounded,
                              size: 13,
                              color: isActive ? Colors.white : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              labelText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                color: isActive ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${g.places.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isActive ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            height: 275,
            child: ListView.separated(
              controller: _shelf2ScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: activeGroup.places.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final place = activeGroup.places[index];
                return _RecommendationPlaceCard(
                  place: place,
                  showMatch: true,
                  onTap: () => widget.onPlaceTap(place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback hiển thị 1 kệ đơn lẻ nếu không có dữ liệu Dual-Context
  Widget _buildLegacySingleShelf() {
    final title = widget.isPersonalized
        ? 'Địa Điểm Gợi Ý Dành Riêng Cho Bạn'
        : 'Địa Điểm Không Thể Bỏ Lỡ';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  _buildArrowButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => _scroll(_legacyScrollController, -1),
                    tooltip: 'Lướt sang trái',
                  ),
                  const SizedBox(width: 6),
                  _buildArrowButton(
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => _scroll(_legacyScrollController, 1),
                    tooltip: 'Lướt sang phải',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 275,
            child: ListView.separated(
              controller: _legacyScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.places.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final place = widget.places[index];
                return _RecommendationPlaceCard(
                  place: place,
                  showMatch: widget.isPersonalized,
                  onTap: () => widget.onPlaceTap(place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: const Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SizedBox(
      height: 275,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return Container(
            width: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
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
}

class _RecommendationPlaceCard extends StatefulWidget {
  final PlaceModel place;
  final bool showDistance;
  final bool showMatch;
  final VoidCallback onTap;

  const _RecommendationPlaceCard({
    required this.place,
    this.showDistance = false,
    this.showMatch = false,
    required this.onTap,
  });

  @override
  State<_RecommendationPlaceCard> createState() => _RecommendationPlaceCardState();
}

class _RecommendationPlaceCardState extends State<_RecommendationPlaceCard> {
  int _activeImageIndex = 0;

  List<String> get _mediaList {
    if (widget.place.mediaUrls.isNotEmpty) {
      return widget.place.mediaUrls;
    }
    if (widget.place.imageUrl.isNotEmpty) {
      return [widget.place.imageUrl];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = _mediaList;
    final hasMultipleImages = mediaList.length > 1;

    // Badges
    final distKm = widget.place.distanceKm;
    final matchPct = widget.place.matchPercentage;
    final hasDistanceBadge = widget.showDistance && distKm != null && distKm > 0;
    final hasMatchBadge = widget.showMatch && matchPct != null && matchPct > 0;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square Thumbnail Image with multi-image navigation matching Web
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 190,
                    height: 190,
                    color: const Color(0xFFF1F5F9),
                    child: mediaList.isNotEmpty
                        ? Image(
                            image: getAppImageProvider(mediaList[_activeImageIndex]) ??
                                const NetworkImage('https://images.unsplash.com/photo-1528127269322-539801943592?w=800&h=500&fit=crop&auto=format'),
                            fit: BoxFit.cover,
                            width: 190,
                            height: 190,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFE2E8F0),
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 32),
                            ),
                          )
                        : Container(
                            alignment: Alignment.center,
                            child: const Icon(Icons.explore_outlined, color: Color(0xFFCBD5E1), size: 36),
                          ),
                  ),
                ),

                // Distance or Match Badge in upper-left corner
                if (hasDistanceBadge)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            distKm < 1 ? '${(distKm * 1000).toStringAsFixed(0)}m' : '${distKm.toStringAsFixed(1)}km',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (hasMatchBadge)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 10.5, color: Colors.white),
                          const SizedBox(width: 2.5),
                          Text(
                            '${matchPct.toStringAsFixed(0)}% hợp gu',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Multi-image switcher arrows (matching Web RecommendationPlaceCard)
                if (hasMultipleImages) ...[
                  Positioned(
                    left: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeImageIndex = _activeImageIndex == 0
                                ? mediaList.length - 1
                                : _activeImageIndex - 1;
                          });
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.chevron_left_rounded, size: 18, color: Colors.white),
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
                            _activeImageIndex = _activeImageIndex == mediaList.length - 1
                                ? 0
                                : _activeImageIndex + 1;
                          });
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  // Image index indicator (1/3)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_activeImageIndex + 1}/${mediaList.length}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Category tag or explain badge
            if (widget.place.category.isNotEmpty) ...[
              Text(
                widget.place.category.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF047857),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
            ],

            // Place Name
            Text(
              widget.place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 3),

            // Rating & Reviews Row (matching Web ⭐ 4.7 · 18 đánh giá)
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 3),
                Text(
                  widget.place.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '·',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${widget.place.reviews} đánh giá',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
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

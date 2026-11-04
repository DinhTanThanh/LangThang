import 'package:flutter/material.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/user_profile_data_models.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/recent_history_service.dart';
import '../../screens/destinations/place_detail_screen.dart';

class RecentVisitedFloatingDock extends StatefulWidget {
  final VoidCallback? onOpenProfile;
  final double bottomMargin;

  const RecentVisitedFloatingDock({
    super.key,
    this.onOpenProfile,
    this.bottomMargin = 24,
  });

  @override
  State<RecentVisitedFloatingDock> createState() => _RecentVisitedFloatingDockState();
}

class _RecentVisitedFloatingDockState extends State<RecentVisitedFloatingDock>
    with SingleTickerProviderStateMixin {
  final RecentHistoryService _recentService = RecentHistoryService();
  bool _isExpanded = false;
  bool _isMiniMode = false;

  // Draggable position coordinates
  Offset? _position;
  bool _isDragging = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _recentService.getRecentVisitedPlaces();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateToDetail(UserAccessHistoryItemModel item) async {
    setState(() => _isExpanded = false);
    final placeRes = await PlaceApiService().getPlaceDetail(item.placeId);
    if (!mounted) return;

    final place = (placeRes.success && placeRes.data != null)
        ? placeRes.data!
        : PlaceModel(
            id: item.placeId,
            name: item.placeName,
            category: item.category.isNotEmpty ? item.category : 'Điểm tham quan',
            location: item.province,
            region: 'Việt Nam',
            province: item.province,
            type: 'Điểm tham quan',
            rating: item.avgRating,
            reviews: 0,
            price: 'Miễn phí',
            priceMax: 0,
            priceRange: 'Miễn phí',
            hours: '07:30 – 17:30',
            status: 'Đang mở cửa',
            desc: '',
            detailedDescription: '',
            phoneNumber: '',
            website: '',
            img: item.coverImg,
            mediaUrls: item.coverImg.isNotEmpty ? [item.coverImg] : [],
            latitude: 21.0285,
            longitude: 105.8542,
            tags: [item.category],
            amenities: const [],
            isSaved: false,
          );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlaceDetailScreen(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // Default initial position on right side, safely above bottom cards/navigation
    if (_position == null) {
      final maxX = (screenSize.width - 60) > 12.0 ? (screenSize.width - 60) : 12.0;
      final maxY = (screenSize.height - 100) > (padding.top + 20) ? (screenSize.height - 100) : (padding.top + 20);
      final initialX = screenSize.width - (_isMiniMode ? 60 : 175);
      final initialY = screenSize.height - widget.bottomMargin - 120;
      _position = Offset(
        initialX.clamp(12.0, maxX),
        initialY.clamp(padding.top + 20, maxY),
      );
    }

    return ValueListenableBuilder<List<UserAccessHistoryItemModel>>(
      valueListenable: _recentService.recentNotifier,
      builder: (context, items, child) {
        if (items.isEmpty) return const SizedBox.shrink();

        final currentPos = _position!;

        return Stack(
          children: [
            // Modal background overlay when expanded
            if (_isExpanded)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _isExpanded = false),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.black.withValues(alpha: 0.4)),
                ),
              ),

            // Draggable Floating Widget
            if (!_isExpanded)
              Positioned(
                left: currentPos.dx,
                top: currentPos.dy,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() => _isDragging = true);
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      final itemWidth = _isMiniMode ? 52.0 : 165.0;
                      final itemHeight = 44.0;
                      final minX = 8.0;
                      final maxX = screenSize.width - itemWidth - 8.0;
                      final minY = padding.top + 10.0;
                      final maxY = screenSize.height - padding.bottom - itemHeight - 70.0;

                      final newX = (_position!.dx + details.delta.dx).clamp(minX, maxX);
                      final newY = (_position!.dy + details.delta.dy).clamp(minY, maxY);
                      _position = Offset(newX, newY);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() => _isDragging = false);
                  },
                  child: AnimatedScale(
                    scale: _isDragging ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: _isMiniMode
                        ? _buildMiniBubble(items)
                        : _buildCollapsedPill(items),
                  ),
                ),
              )
            else
              // Expanded Card centered or aligned nicely near current position
              _buildCenteredExpandedCard(items, screenSize),
          ],
        );
      },
    );
  }

  // ==================== MINI BUBBLE ====================
  Widget _buildMiniBubble(List<UserAccessHistoryItemModel> items) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = true),
      onDoubleTap: () => setState(() => _isMiniMode = false),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF334155), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time_filled_rounded, color: Color(0xFF34D399), size: 18),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== COLLAPSED PILL ====================
  Widget _buildCollapsedPill(List<UserAccessHistoryItemModel> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Grip handle
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 2),
            child: Icon(Icons.drag_indicator_rounded, color: Colors.white.withValues(alpha: 0.4), size: 16),
          ),

          // Tap to expand
          GestureDetector(
            onTap: () => setState(() => _isExpanded = true),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing dot
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  const Icon(Icons.access_time_rounded, color: Color(0xFF34D399), size: 13),
                  const SizedBox(width: 5),

                  const Text(
                    'Đã xem gần đây',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Mini mode button
          GestureDetector(
            onTap: () => setState(() => _isMiniMode = true),
            child: Padding(
              padding: const EdgeInsets.only(left: 6, right: 8),
              child: Icon(Icons.unfold_less_rounded, color: Colors.white.withValues(alpha: 0.5), size: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EXPANDED CARD ====================
  Widget _buildCenteredExpandedCard(List<UserAccessHistoryItemModel> items, Size screenSize) {
    return Center(
      child: Container(
        width: 330,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.65),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: Color(0xFF34D399), size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Địa điểm đã xem gần đây',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${items.length}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      // Clear all button
                      GestureDetector(
                        onTap: () => _recentService.clearAll(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Collapse button
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = false),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // List of items
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    onTap: () => _navigateToDetail(item),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: item.coverImg.isNotEmpty
                                  ? Image.network(
                                      item.coverImg,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xFFF1F5F9),
                                        child: const Icon(Icons.explore_outlined, color: Color(0xFF94A3B8), size: 20),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(Icons.explore_outlined, color: Color(0xFF94A3B8), size: 20),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.placeName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (item.province.isNotEmpty) ...[
                                      const Icon(Icons.location_on_outlined, size: 10, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          item.province,
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    if (item.avgRating > 0) ...[
                                      const SizedBox(width: 4),
                                      const Text('·', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 2),
                                      Text(
                                        item.avgRating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Remove button (X)
                          GestureDetector(
                            onTap: () => _recentService.removeRecentPlace(item.placeId),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _isExpanded = false);
                      widget.onOpenProfile?.call();
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.explore_rounded, size: 13, color: Color(0xFF065F46)),
                        SizedBox(width: 4),
                        Text(
                          'Xem nhật ký cá nhân',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = false),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
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
}

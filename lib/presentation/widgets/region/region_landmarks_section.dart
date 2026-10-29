import 'package:flutter/material.dart';
import '../../../data/models/region_landing_model.dart';
import '../../../data/services/favorite_api_service.dart';

class RegionLandmarksSection extends StatefulWidget {
  final List<RegionLandmarkModel> landmarks;
  final String regionName;
  final Function(RegionLandmarkModel landmark)? onLandmarkTap;

  const RegionLandmarksSection({
    super.key,
    required this.landmarks,
    required this.regionName,
    this.onLandmarkTap,
  });

  @override
  State<RegionLandmarksSection> createState() => _RegionLandmarksSectionState();
}

class _RegionLandmarksSectionState extends State<RegionLandmarksSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scroll(int direction) {
    _scrollController.animateTo(
      _scrollController.offset + direction * 280,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.landmarks.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with nav buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Địa Điểm Không Thể Bỏ Lỡ ${widget.regionName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavButton(Icons.arrow_back_rounded, () => _scroll(-1)),
                    const SizedBox(width: 6),
                    _buildNavButton(Icons.arrow_forward_rounded, () => _scroll(1)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal list of landmark cards
          SizedBox(
            height: 295,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: widget.landmarks.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final landmark = widget.landmarks[index];
                return _LandmarkCard(
                  landmark: landmark,
                  onTap: () => widget.onLandmarkTap?.call(landmark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
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
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}

class _LandmarkCard extends StatefulWidget {
  final RegionLandmarkModel landmark;
  final VoidCallback? onTap;

  const _LandmarkCard({
    required this.landmark,
    this.onTap,
  });

  @override
  State<_LandmarkCard> createState() => _LandmarkCardState();
}

class _LandmarkCardState extends State<_LandmarkCard> {
  int _imageIdx = 0;
  bool _isSaved = false;

  int get _numericLandmarkId {
    if (widget.landmark.id is int) {
      return widget.landmark.id as int;
    }
    final parsed = int.tryParse(widget.landmark.id.toString().replaceAll(RegExp(r'\D'), ''));
    if (parsed != null && parsed > 0) return parsed;
    return (widget.landmark.name.hashCode.abs() % 100000);
  }

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await FavoriteApiService().isFavorite(1, _numericLandmarkId);
    if (mounted) setState(() => _isSaved = saved);
  }

  void _toggleSave() {
    final nextSaved = !_isSaved;
    setState(() => _isSaved = nextSaved);

    final landmark = widget.landmark;
    final id = _numericLandmarkId;
    final mediaList = landmark.mediaUrls.isNotEmpty
        ? landmark.mediaUrls
        : (landmark.imageUrl != null && landmark.imageUrl!.isNotEmpty
            ? [landmark.imageUrl!]
            : ['https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=600&auto=format&fit=crop']);
    final cover = mediaList.isNotEmpty ? mediaList.first : '';

    if (nextSaved) {
      FavoriteApiService().addFavorite(
        targetType: 1, // Place
        targetId: id,
        title: landmark.name,
        subtitle: landmark.location.isNotEmpty ? landmark.location : landmark.province,
        coverImg: cover,
        categoryTag: landmark.category ?? 'Điểm tham quan',
        rating: landmark.rating,
        reviewCount: landmark.reviewCount,
        price: landmark.price ?? 'Miễn phí',
        mediaUrls: mediaList,
      );
    } else {
      FavoriteApiService().removeFavorite(
        targetType: 1,
        targetId: id,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextSaved
              ? 'Đã lưu "${landmark.name}" vào danh sách yêu thích!'
              : 'Đã bỏ lưu địa điểm.',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landmark = widget.landmark;
    final mediaList = landmark.mediaUrls.isNotEmpty
        ? landmark.mediaUrls
        : (landmark.imageUrl != null && landmark.imageUrl!.isNotEmpty
            ? [landmark.imageUrl!]
            : ['https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=600&auto=format&fit=crop']);

    return SizedBox(
      width: 210,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Square Image with Carousel
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      mediaList[_imageIdx],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFE2E8F0),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.black26, size: 36),
                        ),
                      ),
                    ),

                    // Heart save button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _toggleSave,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 16,
                            color: _isSaved ? const Color(0xFFF43F5E) : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),

                    // Multiple images indicator
                    if (mediaList.length > 1) ...[
                      // Left arrow
                      Positioned(
                        left: 6,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _imageIdx = (_imageIdx == 0) ? mediaList.length - 1 : _imageIdx - 1;
                              });
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ),
                      // Right arrow
                      Positioned(
                        right: 6,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _imageIdx = (_imageIdx == mediaList.length - 1) ? 0 : _imageIdx + 1;
                              });
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ),
                      // Badge count
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_imageIdx + 1}/${mediaList.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
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

            // 2. Landmark Info
            Text(
              landmark.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 3),

            // Rating + review count
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 3),
                Text(
                  landmark.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(width: 4),
                Text(
                  '${landmark.reviewCount} đánh giá',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFFA8A29E)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    landmark.location.isNotEmpty ? landmark.location : landmark.province,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
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

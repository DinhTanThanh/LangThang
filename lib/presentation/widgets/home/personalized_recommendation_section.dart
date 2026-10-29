import 'package:flutter/material.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/place_model.dart';

class PersonalizedRecommendationSection extends StatefulWidget {
  final List<PlaceModel> places;
  final bool isPersonalized;
  final bool isLoading;
  final ValueChanged<PlaceModel> onPlaceTap;

  const PersonalizedRecommendationSection({
    super.key,
    required this.places,
    this.isPersonalized = false,
    this.isLoading = false,
    required this.onPlaceTap,
  });

  @override
  State<PersonalizedRecommendationSection> createState() => _PersonalizedRecommendationSectionState();
}

class _PersonalizedRecommendationSectionState extends State<PersonalizedRecommendationSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scroll(double direction) {
    if (!_scrollController.hasClients) return;
    final currentOffset = _scrollController.offset;
    final itemWidth = 200.0;
    final targetOffset = (currentOffset + (direction * itemWidth * 2)).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading && widget.places.isEmpty) {
      return const SizedBox.shrink();
    }

    final title = widget.isPersonalized
        ? 'Địa Điểm Gợi Ý Dành Riêng Cho Bạn'
        : 'Địa Điểm Không Thể Bỏ Lỡ';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
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
              // Arrow Navigation Buttons
              Row(
                children: [
                  _buildArrowButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => _scroll(-1),
                    tooltip: 'Lướt sang trái',
                  ),
                  const SizedBox(width: 6),
                  _buildArrowButton(
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => _scroll(1),
                    tooltip: 'Lướt sang phải',
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Cards List
          if (widget.isLoading)
            _buildLoadingSkeleton()
          else
            SizedBox(
              height: 255,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.places.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final place = widget.places[index];
                  return _RecommendationPlaceCard(
                    place: place,
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
      height: 255,
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
  final VoidCallback onTap;

  const _RecommendationPlaceCard({
    required this.place,
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

import 'package:flutter/material.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/place_api_service.dart';
import '../../screens/destinations/place_detail_screen.dart';

class PersonalizedFoodSection extends StatefulWidget {
  final List<FoodModel> foods;
  final bool isLoading;
  final Function(PlaceModel place)? onPlaceTap;

  const PersonalizedFoodSection({
    super.key,
    required this.foods,
    this.isLoading = false,
    this.onPlaceTap,
  });

  @override
  State<PersonalizedFoodSection> createState() => _PersonalizedFoodSectionState();
}

class _PersonalizedFoodSectionState extends State<PersonalizedFoodSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scroll(double direction) {
    if (!_scrollController.hasClients) return;
    const cardWidth = 270.0;
    final currentOffset = _scrollController.offset;
    final targetOffset = (currentOffset + (direction * cardWidth * 1.5)).clamp(
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
    if (!widget.isLoading && widget.foods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header matching Share_Locations PersonalizedFoodSection.tsx
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Món Ngon Đặc Sản Đề Xuất Theo Gu',
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
                    _buildRoundArrowButton(
                      icon: Icons.arrow_back,
                      onTap: () => _scroll(-1),
                    ),
                    const SizedBox(width: 8),
                    _buildRoundArrowButton(
                      icon: Icons.arrow_forward,
                      onTap: () => _scroll(1),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content: Loading Skeleton or Cards List
          if (widget.isLoading)
            _buildLoadingSkeleton()
          else
            SizedBox(
              height: 415,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.foods.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final food = widget.foods[index];
                  return _PersonalizedFoodCard(
                    food: food,
                    onPlaceTap: widget.onPlaceTap,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundArrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
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

  Widget _buildLoadingSkeleton() {
    return SizedBox(
      height: 415,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return Container(
            width: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 16,
                  width: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
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

class _PersonalizedFoodCard extends StatefulWidget {
  final FoodModel food;
  final Function(PlaceModel place)? onPlaceTap;

  const _PersonalizedFoodCard({
    required this.food,
    this.onPlaceTap,
  });

  @override
  State<_PersonalizedFoodCard> createState() => _PersonalizedFoodCardState();
}

class _PersonalizedFoodCardState extends State<_PersonalizedFoodCard> {
  int _activeImageIndex = 0;

  void _handlePlaceClick(BuildContext context, FoodSuggestedPlace place) async {
    final placeId = place.id;
    if (placeId != null && placeId > 0) {
      try {
        final res = await PlaceApiService().getPlaceDetail(placeId);
        if (res.data != null && context.mounted) {
          if (widget.onPlaceTap != null) {
            widget.onPlaceTap!(res.data!);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaceDetailScreen(place: res.data!),
              ),
            );
          }
          return;
        }
      } catch (_) {}
    }

    // Fallback: Tạo lightweight PlaceModel
    if (context.mounted) {
      final fallbackPlace = PlaceModel(
        id: place.id ?? (widget.food.id.hashCode.abs() % 10000),
        name: place.name.isNotEmpty ? place.name : widget.food.name,
        category: 'Ẩm thực',
        location: place.address.isNotEmpty ? place.address : 'Địa điểm ẩm thực uy tín',
        province: widget.food.province.isNotEmpty ? widget.food.province : 'Việt Nam',
        region: widget.food.region.isNotEmpty ? widget.food.region : 'Việt Nam',
        type: 'Ẩm thực',
        rating: place.rating > 0 ? place.rating : 4.8,
        reviews: 35,
        price: widget.food.priceRange.isNotEmpty ? widget.food.priceRange : '40.000đ - 100.000đ',
        priceMax: 100000,
        priceRange: widget.food.priceRange.isNotEmpty ? widget.food.priceRange : '40.000đ - 100.000đ',
        hours: '08:00 - 22:00',
        status: 'Đang mở cửa',
        desc: widget.food.description.isNotEmpty
            ? widget.food.description
            : 'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.',
        tags: ['Ẩm thực', 'Đặc sản'],
        img: widget.food.imageUrl.isNotEmpty
            ? widget.food.imageUrl
            : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop',
        mediaUrls: widget.food.allMediaUrls,
      );

      if (widget.onPlaceTap != null) {
        widget.onPlaceTap!(fallbackPlace);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceDetailScreen(place: fallbackPlace),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final mediaList = food.allMediaUrls;
    final hasMultipleImages = mediaList.length > 1;

    final displayPlaces = food.suggestedPlaces.isNotEmpty
        ? food.suggestedPlaces.take(2).toList()
        : [
            const FoodSuggestedPlace(
              name: 'Đặc sản ẩm thực nổi bật',
              address: 'Địa điểm ẩm thực uy tín',
              rating: 4.8,
            )
          ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            if (displayPlaces.isNotEmpty) {
              _handlePlaceClick(context, displayPlaces.first);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Image 4:3 AspectRatio with rounded-xl
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (mediaList.isNotEmpty)
                          Image.network(
                            mediaList[_activeImageIndex % mediaList.length],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF8FAFC),
                              child: const Center(
                                child: Icon(Icons.restaurant_rounded, color: Color(0xFF94A3B8), size: 36),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: const Color(0xFFFEF3C7),
                            child: const Center(
                              child: Icon(Icons.restaurant_rounded, color: Color(0xFFF59E0B), size: 36),
                            ),
                          ),

                        // Image Navigation if multiple images
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
                                  width: 26,
                                  height: 26,
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
                                  width: 26,
                                  height: 26,
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

                // 2. Food Name
                Text(
                  food.name,
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

                // 3. Description
                Text(
                  food.description.isNotEmpty
                      ? food.description
                      : 'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 8),

                // 4. QUÁN NGON ĐỀ XUẤT Box (matching Share_Locations PersonalizedFoodSection.tsx)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      const Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 12,
                            color: Color(0xFF065F46),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'QUÁN NGON ĐỀ XUẤT',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // List of suggested places
                      ...displayPlaces.map((place) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _handlePlaceClick(context, place),
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(color: const Color(0xFFD1FAE5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            place.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            place.address.isNotEmpty
                                                ? place.address
                                                : 'Địa điểm ẩm thực uy tín',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFF6EE7B7)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '★',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                          const SizedBox(width: 1.5),
                                          Text(
                                            place.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF047857),
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
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

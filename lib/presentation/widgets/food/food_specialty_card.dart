import 'package:flutter/material.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/services/favorite_api_service.dart';
import '../../screens/destinations/place_detail_screen.dart';

class FoodSpecialtyCard extends StatefulWidget {
  final FoodModel food;
  final String? regionName;
  final VoidCallback? onTap;
  final Function(FoodSuggestedPlace place)? onPlaceTap;
  final double? width;

  const FoodSpecialtyCard({
    super.key,
    required this.food,
    this.regionName,
    this.onTap,
    this.onPlaceTap,
    this.width,
  });

  @override
  State<FoodSpecialtyCard> createState() => _FoodSpecialtyCardState();
}

class _FoodSpecialtyCardState extends State<FoodSpecialtyCard> {
  int _activeImageIndex = 0;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  int get _numericFoodId {
    return int.tryParse(widget.food.id.replaceAll(RegExp(r'\D'), '')) ??
        (widget.food.id.hashCode.abs() % 100000);
  }

  Future<void> _checkSaved() async {
    final saved = await FavoriteApiService().isFavorite(2, _numericFoodId);
    if (mounted) setState(() => _isSaved = saved);
  }

  void _prevImage() {
    final media = widget.food.allMediaUrls;
    if (media.length <= 1) return;
    setState(() {
      _activeImageIndex = (_activeImageIndex == 0) ? media.length - 1 : _activeImageIndex - 1;
    });
  }

  void _nextImage() {
    final media = widget.food.allMediaUrls;
    if (media.length <= 1) return;
    setState(() {
      _activeImageIndex = (_activeImageIndex == media.length - 1) ? 0 : _activeImageIndex + 1;
    });
  }

  void _toggleSave() {
    final nextSaved = !_isSaved;
    setState(() {
      _isSaved = nextSaved;
    });

    final foodId = _numericFoodId;
    final cover = widget.food.imageUrl.isNotEmpty
        ? widget.food.imageUrl
        : (widget.food.allMediaUrls.isNotEmpty ? widget.food.allMediaUrls.first : '');
    final location = widget.food.province.isNotEmpty
        ? widget.food.province
        : (widget.food.region == 'north'
            ? 'Miền Bắc'
            : (widget.food.region == 'central' ? 'Miền Trung' : 'Miền Nam'));

    if (nextSaved) {
      FavoriteApiService().addFavorite(
        targetType: 2, // Food
        targetId: foodId,
        title: widget.food.name,
        subtitle: location,
        coverImg: cover,
        categoryTag: widget.food.type.isNotEmpty ? widget.food.type : 'Đặc sản ẩm thực',
        rating: widget.food.rating > 0 ? widget.food.rating : 5.0,
        reviewCount: 20,
        price: widget.food.priceRange.isNotEmpty ? widget.food.priceRange : 'Tham khảo',
        mediaUrls: widget.food.allMediaUrls,
      );
    } else {
      FavoriteApiService().removeFavorite(
        targetType: 2,
        targetId: foodId,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved ? 'Đã lưu món "${widget.food.name}" vào danh sách yêu thích!' : 'Đã bỏ lưu món ăn.',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handlePlaceClick(BuildContext context, FoodSuggestedPlace place) {
    if (widget.onPlaceTap != null) {
      widget.onPlaceTap!(place);
      return;
    }

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
          province: widget.food.province.isNotEmpty ? widget.food.province : 'Việt Nam',
          region: widget.food.region == 'north'
              ? 'Miền Bắc'
              : (widget.food.region == 'central' ? 'Miền Trung' : 'Miền Nam'),
          type: 'Ẩm thực',
          rating: place.rating,
          reviews: 45,
          price: '40.000đ',
          priceMax: 100000,
          priceRange: widget.food.priceRange.isNotEmpty ? widget.food.priceRange : '40.000đ - 100.000đ',
          hours: '07:00 - 22:00',
          status: 'Đang mở cửa',
          desc: widget.food.description.isNotEmpty ? widget.food.description : place.address,
          detailedDescription: widget.food.description,
          tags: ['Ẩm thực', 'Đặc sản', if (widget.food.province.isNotEmpty) widget.food.province],
          img: widget.food.imageUrl.isNotEmpty
              ? widget.food.imageUrl
              : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=600&auto=format&fit=crop',
          mediaUrls: widget.food.allMediaUrls,
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
    final food = widget.food;
    final mediaList = food.allMediaUrls;
    final hasMultipleImages = mediaList.length > 1;
    final suggestedPlaces = food.suggestedPlaces;

    final cardWidth = widget.width ?? 290.0;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. IMAGE CAROUSEL SECTION (Matching RegionFoodSpecialties.tsx)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Active Image
                        if (mediaList.isNotEmpty)
                          Image.network(
                            mediaList[_activeImageIndex % mediaList.length],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Center(
                                child: Icon(Icons.restaurant_rounded, color: Color(0xFF94A3B8), size: 36),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(Icons.restaurant_rounded, color: Color(0xFF94A3B8), size: 36),
                            ),
                          ),

                        // Heart Button (Top Right)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleSave,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: _isSaved ? const Color(0xFFF43F5E) : const Color(0xFF1E293B),
                                    size: 17,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Province Tag (Top Left)
                        if (food.province.isNotEmpty)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF004F32).withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                food.province,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),

                        // Image Navigation Buttons (If multiple images)
                        if (hasMultipleImages) ...[
                          Positioned(
                            left: 8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _prevImage,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_left_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _nextImage,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF020617).withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_activeImageIndex + 1}/${mediaList.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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

                const SizedBox(height: 12),

                // 2. FOOD TITLE & DESCRIPTION
                Text(
                  food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  food.description.isNotEmpty
                      ? food.description
                      : 'Hương vị đặc trưng truyền thống của vùng đất ${food.province}.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),

                // 3. QUÁN NGON ĐỀ XUẤT (Danh sách địa điểm bán món)
                if (suggestedPlaces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5), // emerald-50/60
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD1FAE5)), // emerald-100
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header "QUÁN NGON ĐỀ XUẤT"
                        const Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 14,
                              color: Color(0xFF065F46), // emerald-800
                            ),
                            SizedBox(width: 5),
                            Text(
                              'QUÁN NGON ĐỀ XUẤT',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: Color(0xFF065F46), // emerald-800
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Store items (Show top 2)
                        ...suggestedPlaces.take(2).map((place) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _handlePlaceClick(context, place),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFD1FAE5), // emerald-100/80
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 3,
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
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              place.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF6EE7B7)), // emerald-300
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              '★',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF047857), // emerald-700
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              place.rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF047857), // emerald-700
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

                const SizedBox(height: 10),

                // 4. PRICE RANGE FOOTER (Matching RegionFoodSpecialties.tsx)
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Mức giá:',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        food.priceRange.isNotEmpty ? food.priceRange : 'Tham khảo',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF004F32), // Emerald deep green
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
  }
}

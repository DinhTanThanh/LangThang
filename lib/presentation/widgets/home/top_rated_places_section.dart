import 'package:flutter/material.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/place_api_service.dart';
import '../../screens/destinations/place_detail_screen.dart';

class TopRatedPlacesSection extends StatefulWidget {
  final List<PlaceModel> places;
  final VoidCallback? onViewAllTap;
  final Function(PlaceModel place)? onPlaceTap;

  const TopRatedPlacesSection({
    super.key,
    required this.places,
    this.onViewAllTap,
    this.onPlaceTap,
  });

  @override
  State<TopRatedPlacesSection> createState() => _TopRatedPlacesSectionState();
}

class _TopRatedPlacesSectionState extends State<TopRatedPlacesSection> {
  final Set<int> _savedIds = {};

  void _toggleSave(PlaceModel place) async {
    final isSaved = _savedIds.contains(place.id);
    setState(() {
      if (isSaved) {
        _savedIds.remove(place.id);
      } else {
        _savedIds.add(place.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !isSaved
              ? 'Đã lưu "${place.name}" vào danh sách yêu thích!'
              : 'Đã bỏ lưu địa điểm.',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      if (!isSaved) {
        await PlaceApiService().savePlace(place.id);
      } else {
        await PlaceApiService().unsavePlace(place.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final displayPlaces = widget.places.take(4).toList();
    if (displayPlaces.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header (Matching TopRatedPlacesSection.tsx)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ĐƯỢC YÊU THÍCH NHẤT',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFD97706), // Amber-600 / secondary-container
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Điểm đến đánh giá cao nhất',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              if (widget.onViewAllTap != null)
                GestureDetector(
                  onTap: widget.onViewAllTap,
                  child: Row(
                    children: const [
                      Text(
                        'Xem tất cả',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF004F32),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF004F32)),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // 2x2 Grid of Top Rated Places
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.60,
            ),
            itemCount: displayPlaces.length,
            itemBuilder: (context, index) {
              final place = displayPlaces[index];
              final isSaved = _savedIds.contains(place.id) || place.isSaved;
              final ratingScore = place.rating > 0 ? place.rating : 5.0;

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    if (widget.onPlaceTap != null) {
                      widget.onPlaceTap!(place);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaceDetailScreen(place: place),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image with heart button
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  place.imageUrl.isNotEmpty
                                      ? place.imageUrl
                                      : 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=600&auto=format&fit=crop',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Icon(Icons.location_on_outlined,
                                          color: Color(0xFF94A3B8), size: 28),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _toggleSave(place),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.95),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isSaved
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            color: isSaved
                                                ? const Color(0xFFF43F5E)
                                                : const Color(0xFF1E293B),
                                            size: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Title
                        Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),

                        const SizedBox(height: 3),

                        // Rating & Reviews
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 2),
                            Text(
                              ratingScore.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text('·',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                place.reviewCount > 0
                                    ? '${place.reviewCount} đánh giá'
                                    : 'Mới',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Price / Location tag
                        Text(
                          place.price.isNotEmpty ? place.price : (place.province.isNotEmpty ? place.province : 'Miễn phí'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF004F32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/favorite_api_service.dart';
import '../../screens/destinations/place_detail_screen.dart';

class PlaceCardInCollection extends StatefulWidget {
  final PlaceModel place;
  final double? width;
  final VoidCallback? onTap;

  const PlaceCardInCollection({
    super.key,
    required this.place,
    this.width,
    this.onTap,
  });

  @override
  State<PlaceCardInCollection> createState() => _PlaceCardInCollectionState();
}

class _PlaceCardInCollectionState extends State<PlaceCardInCollection> {
  int _activeImageIndex = 0;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.place.isSaved;
    _checkSaved();
  }

  @override
  void didUpdateWidget(covariant PlaceCardInCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.id != widget.place.id) {
      _checkSaved();
    }
  }

  Future<void> _checkSaved() async {
    final saved = await FavoriteApiService().isFavorite(1, widget.place.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  void _toggleSave() {
    final nextSaved = !_isSaved;
    setState(() => _isSaved = nextSaved);

    final place = widget.place;
    if (nextSaved) {
      FavoriteApiService().addFavorite(
        targetType: 1, // Place
        targetId: place.id,
        title: place.name,
        subtitle: place.province.isNotEmpty ? place.province : place.location,
        coverImg: place.imageUrl,
        categoryTag: place.category,
        rating: place.rating,
        reviewCount: place.reviewCount,
        price: place.price,
        mediaUrls: place.mediaUrls,
      );
    } else {
      FavoriteApiService().removeFavorite(
        targetType: 1,
        targetId: place.id,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextSaved
              ? 'Đã lưu "${place.name}" vào danh sách yêu thích!'
              : 'Đã bỏ lưu địa điểm.',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _prevImage() {
    final media = widget.place.mediaUrls.isNotEmpty
        ? widget.place.mediaUrls
        : (widget.place.imageUrl.isNotEmpty ? [widget.place.imageUrl] : <String>[]);
    if (media.length <= 1) return;
    setState(() {
      _activeImageIndex = (_activeImageIndex == 0) ? media.length - 1 : _activeImageIndex - 1;
    });
  }

  void _nextImage() {
    final media = widget.place.mediaUrls.isNotEmpty
        ? widget.place.mediaUrls
        : (widget.place.imageUrl.isNotEmpty ? [widget.place.imageUrl] : <String>[]);
    if (media.length <= 1) return;
    setState(() {
      _activeImageIndex = (_activeImageIndex == media.length - 1) ? 0 : _activeImageIndex + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final mediaList = place.mediaUrls.isNotEmpty
        ? place.mediaUrls
        : (place.imageUrl.isNotEmpty ? [place.imageUrl] : <String>[]);
    final hasMultipleImages = mediaList.length > 1;
    final ratingScore = place.rating > 0 ? place.rating : 5.0;
    final cardWidth = widget.width ?? 240.0;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
            if (widget.onTap != null) {
              widget.onTap!();
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
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. IMAGE CONTAINER WITH MULTI-IMAGE CAROUSEL
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
                                child: Icon(Icons.photo_size_select_actual_outlined,
                                    color: Color(0xFF94A3B8), size: 36),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(Icons.location_on_outlined,
                                  color: Color(0xFF94A3B8), size: 36),
                            ),
                          ),

                        // Heart save button
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: _toggleSave,
                            child: Container(
                              width: 28,
                              height: 28,
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
                                size: 15,
                                color: _isSaved ? const Color(0xFFF43F5E) : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),

                        // Multi-image navigation buttons
                        if (hasMultipleImages) ...[
                          Positioned(
                            left: 6,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _prevImage,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.65),
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
                                onTap: _nextImage,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.65),
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
                                color: const Color(0xFF020617).withValues(alpha: 0.75),
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

                // 2. PLACE NAME
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 4),

                // 3. RATING & REVIEWS
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      ratingScore.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '·',
                      style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        place.reviewCount > 0 ? '${place.reviewCount} đánh giá' : 'Mới',
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

                const SizedBox(height: 4),

                // 4. CATEGORY / LOCATION
                Text(
                  place.province.isNotEmpty
                      ? '${place.province} · ${place.category}'
                      : place.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
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

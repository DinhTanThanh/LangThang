import 'package:flutter/material.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/ranking_model.dart';
import '../../screens/destinations/place_detail_screen.dart';

class RankingPlaceCardWidget extends StatefulWidget {
  final RankingPlaceItem place;

  const RankingPlaceCardWidget({super.key, required this.place});

  @override
  State<RankingPlaceCardWidget> createState() => _RankingPlaceCardWidgetState();
}

class _RankingPlaceCardWidgetState extends State<RankingPlaceCardWidget> {
  bool _isDescExpanded = false;
  bool _isReviewExpanded = false;

  void _navigateToDetail() {
    final place = widget.place;
    final placeModel = PlaceModel(
      id: place.id,
      name: place.name,
      category: place.categoryName.isNotEmpty ? place.categoryName : 'Địa điểm',
      location: place.address ?? place.provinceName,
      region: '',
      province: place.provinceName,
      type: place.placeTypeName,
      rating: place.avgRating,
      reviews: place.reviewCount,
      price: '',
      priceMax: 0,
      priceRange: '',
      hours: '',
      status: 'Đang mở cửa',
      desc: place.description ?? '',
      detailedDescription: place.description ?? '',
      phoneNumber: '',
      website: '',
      highlights: place.greatThingsToDo,
      amenities: const [],
      tags: const [],
      img: place.coverImageUrl ?? '',
      mediaUrls: place.coverImageUrl != null ? [place.coverImageUrl!] : const [],
      isSaved: place.favoritesCount > 0,
      isVisited: false,
      latitude: 0,
      longitude: 0,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(place: placeModel),
      ),
    );
  }

  Color _getBadgeBackgroundColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFBBF24); // Amber 400 (Gold)
      case 2:
        return const Color(0xFFE2E8F0); // Slate 200 (Silver)
      case 3:
        return const Color(0xFFFEF3C7); // Amber 100 (Bronze)
      default:
        return const Color(0xFFF1F5F9); // Slate 100
    }
  }

  Color _getBadgeTextColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFF451A03); // Amber 950
      case 2:
        return const Color(0xFF1E293B); // Slate 800
      case 3:
        return const Color(0xFF78350F); // Amber 900
      default:
        return const Color(0xFF475569); // Slate 600
    }
  }

  Border? _getBadgeBorder(int rank) {
    switch (rank) {
      case 1:
        return Border.all(color: const Color(0xFFF59E0B), width: 1);
      case 2:
        return Border.all(color: const Color(0xFFCBD5E1), width: 1);
      case 3:
        return Border.all(color: const Color(0xFFFDE68A), width: 1);
      default:
        return Border.all(color: const Color(0xFFE2E8F0), width: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final desc = place.description ?? '';
    final hasLongDesc = desc.length > 140;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Rank Badge, Place Name, Rating & Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getBadgeBackgroundColor(place.rank),
                  borderRadius: BorderRadius.circular(10),
                  border: _getBadgeBorder(place.rank),
                ),
                child: Text(
                  '#${place.rank}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: _getBadgeTextColor(place.rank),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _navigateToDetail,
                      child: Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // 2. Star Rating & Reviews + Location row (Moved up top!)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          place.avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${place.reviewCount})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: GestureDetector(
                            onTap: _navigateToDetail,
                            child: Text(
                              place.address?.isNotEmpty == true ? place.address! : place.provinceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF065F46),
                              ),
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

          // 3. Cover Image
          GestureDetector(
            onTap: _navigateToDetail,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 200,
                color: const Color(0xFFF1F5F9),
                child: place.coverImageUrl?.isNotEmpty == true
                    ? Image.network(
                        place.coverImageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Description (Full width, clean and spacious)
          if (desc.isNotEmpty) ...[
            Text(
              desc,
              maxLines: _isDescExpanded ? 100 : 3,
              overflow: _isDescExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: Color(0xFF475569),
              ),
            ),
            if (hasLongDesc)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isDescExpanded = !_isDescExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isDescExpanded ? 'Thu gọn' : 'Xem thêm',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      Icon(
                        _isDescExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: const Color(0xFF0F172A),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          // 5. Featured Review Quote Card (if available)
          if (place.featuredReview != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Star rating row
                  Row(
                    children: List.generate(5, (index) {
                      final isFilled = index < place.featuredReview!.rating.round();
                      return Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: isFilled ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
                      );
                    }),
                  ),

                  const SizedBox(height: 6),

                  // Review content
                  Text(
                    '"${place.featuredReview!.content}"',
                    maxLines: _isReviewExpanded ? 100 : 2,
                    overflow: _isReviewExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                      color: Color(0xFF334155),
                    ),
                  ),

                  if (place.featuredReview!.content.length > 90)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isReviewExpanded = !_isReviewExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _isReviewExpanded ? 'Thu gọn' : 'Xem thêm',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Author info & helpful count
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: place.featuredReview!.authorAvatar?.isNotEmpty == true
                            ? NetworkImage(place.featuredReview!.authorAvatar!)
                            : null,
                        child: (place.featuredReview!.authorAvatar == null ||
                                place.featuredReview!.authorAvatar!.isEmpty)
                            ? const Icon(Icons.person, size: 14, color: Color(0xFF64748B))
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          place.featuredReview!.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (place.featuredReview!.likesCount > 0)
                        Text(
                          '${place.featuredReview!.likesCount} lượt hữu ích',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 36, color: Color(0xFF94A3B8)),
            SizedBox(height: 4),
            Text(
              'Chưa có hình ảnh đại diện',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/ranking_model.dart';
import '../../screens/destinations/place_detail_screen.dart';

class DestinationRankCardWidget extends StatefulWidget {
  final DestinationRankingItem destination;
  final Function(int)? onSelectProvince;

  const DestinationRankCardWidget({
    super.key,
    required this.destination,
    this.onSelectProvince,
  });

  @override
  State<DestinationRankCardWidget> createState() => _DestinationRankCardWidgetState();
}

class _DestinationRankCardWidgetState extends State<DestinationRankCardWidget> {
  bool _isDescExpanded = false;

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
        return const Color(0xFF451A03);
      case 2:
        return const Color(0xFF1E293B);
      case 3:
        return const Color(0xFF78350F);
      default:
        return const Color(0xFF475569);
    }
  }

  void _navigateToPlace(AwardWinningPlace place) {
    final placeModel = PlaceModel(
      id: place.id,
      name: place.name,
      category: place.categoryName ?? 'Địa điểm',
      location: place.address ?? widget.destination.name,
      region: widget.destination.regionName,
      province: widget.destination.name,
      type: place.placeTypeName ?? 'Địa điểm',
      rating: place.avgRating,
      reviews: place.reviewCount,
      price: '',
      priceMax: 0,
      priceRange: '',
      hours: '',
      status: 'Đang mở cửa',
      desc: '',
      detailedDescription: '',
      phoneNumber: '',
      website: '',
      highlights: const [],
      amenities: const [],
      tags: const [],
      img: place.thumbnailUrl ?? '',
      mediaUrls: place.thumbnailUrl != null ? [place.thumbnailUrl!] : const [],
      isSaved: false,
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

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    final desc = dest.description?.isNotEmpty == true ? dest.description! : (dest.tagline ?? '');
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
          // 1. Header: Rank Badge, Destination Name, Rating & Region
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getBadgeBackgroundColor(dest.rank),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#${dest.rank}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: _getBadgeTextColor(dest.rank),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => widget.onSelectProvince?.call(dest.id),
                      child: Text(
                        dest.name,
                        maxLines: 1,
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
                    // 2. Star Rating & Reviews + Region & total places (Moved up top!)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          dest.avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${dest.totalReviews})',
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
                        Text(
                          dest.regionName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                        const SizedBox(width: 6),
                        Text(
                          '${dest.totalPlaces} địa điểm',
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
            ],
          ),

          const SizedBox(height: 12),

          // 3. Cover Image
          GestureDetector(
            onTap: () => widget.onSelectProvince?.call(dest.id),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 200,
                color: const Color(0xFFF1F5F9),
                child: dest.imageUrl?.isNotEmpty == true
                    ? Image.network(
                        dest.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Description (Full width, spacious & clean)
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

          // 5. Award Winning Places in Province
          if (dest.awardWinningPlaces.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Top địa điểm tại ${dest.name}'.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            Column(
              children: dest.awardWinningPlaces.take(3).map((place) {
                return GestureDetector(
                  onTap: () => _navigateToPlace(place),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: const Color(0xFFE2E8F0),
                            child: place.thumbnailUrl?.isNotEmpty == true
                                ? Image.network(
                                    place.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.place, color: Color(0xFF94A3B8)),
                                  )
                                : const Icon(Icons.place, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                                  const SizedBox(width: 3),
                                  Text(
                                    place.avgRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${place.reviewCount})',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ],
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

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_city_rounded, size: 36, color: Color(0xFF94A3B8)),
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

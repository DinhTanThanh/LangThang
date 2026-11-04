import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../screens/profile/user_profile_screen.dart';

class ItineraryCatalogCard extends StatelessWidget {
  final ItineraryModel itinerary;
  final bool isSaved;
  final bool isApplied;
  final VoidCallback onQuickPreview;
  final VoidCallback onOpenDetail;
  final ValueChanged<int>? onToggleSave;

  const ItineraryCatalogCard({
    super.key,
    required this.itinerary,
    this.isSaved = false,
    this.isApplied = false,
    required this.onQuickPreview,
    required this.onOpenDetail,
    this.onToggleSave,
  });

  String _resolveCoverImage() {
    if (itinerary.coverUrl != null && itinerary.coverUrl!.isNotEmpty) {
      return itinerary.coverUrl!;
    }
    for (final day in itinerary.days) {
      for (final stop in day.stops) {
        if (stop.img != null && stop.img!.isNotEmpty) {
          return stop.img!;
        }
      }
    }
    // Fallback based on destination keyword
    final d = itinerary.destination.toLowerCase();
    if (d.contains('đà nẵng') || d.contains('quảng nam') || d.contains('hội an')) {
      return 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800&h=500&fit=crop';
    }
    if (d.contains('hà nội')) {
      return 'https://images.unsplash.com/photo-1509023464722-18d996393ca8?w=800&h=500&fit=crop';
    }
    if (d.contains('hồ chí minh') || d.contains('sài gòn')) {
      return 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800&h=500&fit=crop';
    }
    if (d.contains('đà lạt') || d.contains('lâm đồng')) {
      return 'https://images.unsplash.com/photo-1588668214407-6ea9a6d8c272?w=800&h=500&fit=crop';
    }
    if (d.contains('phú quốc') || d.contains('kiên giang')) {
      return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&h=500&fit=crop';
    }
    if (d.contains('sa pa') || d.contains('lào cai')) {
      return 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800&h=500&fit=crop';
    }
    if (d.contains('nha trang') || d.contains('khánh hòa')) {
      return 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800&h=500&fit=crop';
    }
    if (d.contains('huế')) {
      return 'https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=800&h=500&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&h=500&fit=crop';
  }

  @override
  Widget build(BuildContext context) {
    final totalStops = itinerary.stopCount;
    final coverImage = _resolveCoverImage();
    final authorInitial = itinerary.authorName.isNotEmpty ? itinerary.authorName[0].toUpperCase() : 'L';

    // Collect first 3 key stop names for the mini roadmap preview
    final previewStops = <String>[];
    for (final day in itinerary.days) {
      for (final stop in day.stops) {
        if (stop.activity.isNotEmpty && !previewStops.contains(stop.activity)) {
          previewStops.add(stop.activity);
          if (previewStops.length >= 3) break;
        }
      }
      if (previewStops.length >= 3) break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onQuickPreview,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Cover Image (Airbnb / Klook Style with Glassmorphic Badges)
              Stack(
                children: [
                  // Image with gradient
                  SizedBox(
                    height: 185,
                    width: double.infinity,
                    child: Image.network(
                      coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFE2E8F0),
                        child: const Center(
                          child: Icon(Icons.landscape_rounded, size: 48, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Top & Bottom Gradient Shadows for High Readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                          stops: const [0.0, 0.25, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Top-Left: Destination Pill
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF34D399)),
                          const SizedBox(width: 4),
                          Text(
                            itinerary.destination.isNotEmpty ? itinerary.destination : 'Việt Nam',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-Right: Bookmark / Favorite Button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () {
                        if (onToggleSave != null) {
                          onToggleSave!(itinerary.id);
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 18,
                          color: isSaved ? const Color(0xFF059669) : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),

                  // Bottom-Left: Duration & Stop Count Pill
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            itinerary.duration.isNotEmpty ? itinerary.duration : '${itinerary.daysCount} Ngày',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$totalStops điểm dừng',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom-Right: Rating Badge
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 3),
                          Text(
                            '${itinerary.rating}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Card Content (Padding 16px)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Row & Style Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Author
                        InkWell(
                          onTap: () => UserProfileScreen.navigate(
                            context,
                            userId: itinerary.id % 10 + 1,
                            userName: itinerary.authorName.isNotEmpty ? itinerary.authorName : 'Tác giả',
                            userAvatar: itinerary.authorAvatar.isNotEmpty ? itinerary.authorAvatar : null,
                            userRank: itinerary.author.rank.isNotEmpty ? itinerary.author.rank : 'Thổ địa',
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (itinerary.authorAvatar.isNotEmpty)
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  backgroundImage: NetworkImage(itinerary.authorAvatar),
                                )
                              else
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF0F172A),
                                  child: Text(
                                    authorInitial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                itinerary.authorName.isNotEmpty ? itinerary.authorName : 'Cộng đồng',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF059669)),
                            ],
                          ),
                        ),

                        // Style pill
                        if (itinerary.style.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              itinerary.style,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Title
                    Text(
                      itinerary.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        height: 1.3,
                        letterSpacing: -0.2,
                      ),
                    ),

                    // Overview
                    if (itinerary.overview != null && itinerary.overview!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        itinerary.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                    ],

                    // Mini Roadmap Preview (Wanderlog / Klook style)
                    if (previewStops.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.alt_route_rounded, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                previewStops.join('  ➔  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 12),

                    // Footer Row: Budget + Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Estimated Cost
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CHI PHÍ DỰ TÍNH',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            RichText(
                              text: TextSpan(
                                text: itinerary.estimatedCost.isNotEmpty ? itinerary.estimatedCost : 'Linh hoạt',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Action Buttons: Quick Preview + Apply
                        Row(
                          children: [
                            // Quick Preview Icon Button
                            InkWell(
                              onTap: onQuickPreview,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF475569)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Chi tiết',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Apply Button
                            ElevatedButton(
                              onPressed: onOpenDetail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isApplied ? const Color(0xFF047857) : const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isApplied ? 'Đã lưu' : 'Áp dụng',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded, size: 13),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

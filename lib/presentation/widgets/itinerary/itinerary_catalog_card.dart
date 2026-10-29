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

  @override
  Widget build(BuildContext context) {
    final totalStops = itinerary.stopCount;
    final authorInitial = itinerary.authorName.isNotEmpty
        ? itinerary.authorName[0].toUpperCase()
        : 'C';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onQuickPreview,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Author Row & Save Bookmark Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Author Info (Avatar + Name + Verified Badge)
                    Expanded(
                      child: InkWell(
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
                                radius: 17,
                                backgroundColor: const Color(0xFFE2E8F0),
                                backgroundImage: NetworkImage(itinerary.authorAvatar),
                              )
                            else
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: const Color(0xFF0F172A),
                                child: Text(
                                  authorInitial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      itinerary.authorName.isNotEmpty
                                          ? itinerary.authorName
                                          : 'Cộng đồng',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 15,
                                    color: Color(0xFF10B981),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bookmark Icon Button
                    if (onToggleSave != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: isSaved ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                          size: 22,
                        ),
                        onPressed: () => onToggleSave?.call(itinerary.id),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  itinerary.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),

                // Overview / Description
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

                const SizedBox(height: 12),

                // 2-Column Info Card (Matching Share_Locations ItineraryCatalogView)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Left Column: Destination & Duration/Stops
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              itinerary.destination.isNotEmpty
                                  ? itinerary.destination
                                  : itinerary.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${itinerary.duration.isNotEmpty ? itinerary.duration : '${itinerary.daysCount} ngày'} • $totalStops ĐIỂM'
                                  .toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Vertical Divider
                      Container(
                        height: 32,
                        width: 1,
                        color: const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                      ),

                      // Right Column: Estimated Cost
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              itinerary.estimatedCost.isNotEmpty
                                  ? itinerary.estimatedCost
                                  : 'Linh hoạt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF065F46),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'CHI PHÍ DỰ TÍNH',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Bottom Action Buttons Row
                Row(
                  children: [
                    // Xem chi tiết
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onQuickPreview,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF334155),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Xem chi tiết',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Áp dụng
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onOpenDetail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isApplied ? const Color(0xFF047857) : const Color(0xFF065F46),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        child: Text(
                          isApplied ? 'Đã áp dụng' : 'Áp dụng',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

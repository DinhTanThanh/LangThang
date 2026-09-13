import 'package:flutter/material.dart';
import '../../../data/models/region_landing_model.dart';

class RegionSpotlightReviews extends StatelessWidget {
  final RegionSpotlightModel? spotlight;
  final List<RegionReviewModel> reviews;
  final Function(RegionSpotlightModel spotlight)? onOpenSpotlightMap;
  final Function(RegionReviewModel review)? onOpenReviewMap;

  const RegionSpotlightReviews({
    super.key,
    this.spotlight,
    this.reviews = const [],
    this.onOpenSpotlightMap,
    this.onOpenReviewMap,
  });

  @override
  Widget build(BuildContext context) {
    if (spotlight == null && reviews.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Spotlight Banner
          if (spotlight != null) ...[
            _SpotlightBanner(
              spotlight: spotlight!,
              onOpenMap: () => onOpenSpotlightMap?.call(spotlight!),
            ),
            const SizedBox(height: 24),
          ],

          // 2. Community Reviews List
          if (reviews.isNotEmpty) ...[
            const Text(
              'Đánh Giá Thực Tế Từ Cộng Đồng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Trải nghiệm chân thực và những gợi ý không thể bỏ qua từ các thành viên LangThang',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final rev = reviews[index];
                return _ReviewCard(
                  review: rev,
                  onOpenMap: () => onOpenReviewMap?.call(rev),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SpotlightBanner extends StatelessWidget {
  final RegionSpotlightModel spotlight;
  final VoidCallback? onOpenMap;

  const _SpotlightBanner({
    required this.spotlight,
    this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1917),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF292524)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Opacity(
                opacity: 0.35,
                child: Image.network(
                  spotlight.bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF292524),
                  ),
                ),
              ),
            ),

            // Gradient Tint
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC0C0A09),
                      Color(0xF00C0A09),
                    ],
                  ),
                ),
              ),
            ),

            // Foreground Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Award Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 14),
                        SizedBox(width: 5),
                        Text(
                          'TIÊU ĐIỂM ĐIỂM ĐẾN NỔI BẬT',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    spotlight.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    spotlight.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE7E5E4),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    spotlight.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFA8A29E),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats Row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF292524)),
                        bottom: BorderSide(color: Color(0xFF292524)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${spotlight.avgRating.toStringAsFixed(1)} / 5.0',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Text(
                                  'Đánh giá trung bình',
                                  style: TextStyle(
                                    color: Color(0xFF78716C),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Container(height: 24, width: 1, color: const Color(0xFF292524)),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${spotlight.totalReviews.toString()}+',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'Lượt review chân thực',
                              style: TextStyle(
                                color: Color(0xFF78716C),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Highlights Pills
                  if (spotlight.highlights.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: spotlight.highlights.map((h) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF292524),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF44403C)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 13),
                            const SizedBox(width: 5),
                            Text(
                              h,
                              style: const TextStyle(
                                color: Color(0xFFE7E5E4),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Button Open Map
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onOpenMap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC0392B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: const Text(
                        'Khám phá tiêu điểm trên Bản đồ',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final RegionReviewModel review;
  final VoidCallback? onOpenMap;

  const _ReviewCard({
    required this.review,
    this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Reviewer info & Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage: review.reviewerAvatar != null
                        ? NetworkImage(review.reviewerAvatar!)
                        : null,
                    child: review.reviewerAvatar == null
                        ? Text(
                            review.reviewerName.isNotEmpty ? review.reviewerName.substring(0, 1) : 'U',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004F32)),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        review.visitDate,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(
                  review.rating,
                  (_) => const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Place Name Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFE4E6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFC0392B)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    review.placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC0392B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Text(
            '"${review.content}"',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF334155),
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),

          // Images Grid
          if (review.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  review.images.first,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFF1F5F9),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Footer: Helpful count & Map Pin Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.thumb_up_alt_outlined, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    '${review.likesCount} hữu ích',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              InkWell(
                onTap: onOpenMap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF004F32)),
                      SizedBox(width: 4),
                      Text(
                        'Xem trên Map',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF004F32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

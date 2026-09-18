import 'package:flutter/material.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../core/constants/app_colors.dart';

class PlaceTypeQuickNavSection extends StatelessWidget {
  final List<PlaceTypeDto> placeTypes;
  final bool isLoading;
  final VoidCallback? onViewAllTap;
  final Function(PlaceTypeDto item)? onPlaceTypeTap;

  const PlaceTypeQuickNavSection({
    super.key,
    required this.placeTypes,
    this.isLoading = false,
    this.onViewAllTap,
    this.onPlaceTypeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && placeTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Matching PlaceTypeQuickNav.tsx)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Bạn đang tìm kiếm điều gì?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                if (onViewAllTap != null)
                  GestureDetector(
                    onTap: onViewAllTap,
                    child: Row(
                      children: const [
                        Text(
                          'Xem tất cả',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Horizontal scroll of 4:3 place type cards
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: isLoading ? 5 : placeTypes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (isLoading) {
                  return Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  );
                }

                final item = placeTypes[index];
                return _buildPlaceTypeCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceTypeCard(PlaceTypeDto item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPlaceTypeTap?.call(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF047857),
                    child: const Icon(Icons.explore_rounded, color: Colors.white30, size: 28),
                  ),
                )
              else
                Container(
                  color: const Color(0xFF047857),
                  child: const Icon(Icons.explore_rounded, color: Colors.white30, size: 28),
                ),

              // Gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xEE020617),
                      Color(0x66020617),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
              ),

              // Title
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

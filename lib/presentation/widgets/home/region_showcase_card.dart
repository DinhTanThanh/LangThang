import 'package:flutter/material.dart';
import '../../../data/models/place_filter_dto.dart';

class RegionShowcaseCard extends StatelessWidget {
  final RegionDto region;
  final Function(String regionName, String? provinceName)? onProvinceTap;
  final Function(RegionDto region)? onExploreRegionTap;

  const RegionShowcaseCard({
    super.key,
    required this.region,
    this.onProvinceTap,
    this.onExploreRegionTap,
  });

  @override
  Widget build(BuildContext context) {
    final heroImage = (region.imageUrl != null && region.imageUrl!.isNotEmpty)
        ? region.imageUrl!
        : (region.id == 1
            ? 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1200&auto=format&fit=crop'
            : (region.id == 2
                ? 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?q=80&w=1200&auto=format&fit=crop'
                : 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?q=80&w=1200&auto=format&fit=crop'));

    final provinces = region.provinces;
    final displayProvinces = provinces.take(8).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO IMAGE WITH REGION TAGLINE OVERLAY
            GestureDetector(
              onTap: () => onExploreRegionTap?.call(region),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      heroImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(
                          child: Icon(Icons.landscape_rounded, color: Colors.white30, size: 48),
                        ),
                      ),
                    ),
                    // Gradient overlay matching Share_Locations (slate-950/70 to transparent)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xEB020617),
                            Color(0x80020617),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    // Title on image
                    Positioned(
                      bottom: 14,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004F32),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              region.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            region.tagline != null && region.tagline!.isNotEmpty
                                ? '${region.name} — ${region.tagline}'
                                : region.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. REGION DESCRIPTION & PROVINCES GRID
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region.description != null && region.description!.isNotEmpty
                        ? region.description!
                        : 'Khám phá những điểm đến đặc trưng, ẩm thực đậm đà bản sắc và cảnh sắc thiên nhiên tuyệt tác của ${region.name}.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),

                  if (displayProvinces.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Các tỉnh thành nổi bật:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Text(
                          '${displayProvinces.length}/${provinces.length} tỉnh thành',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Grid 2 or 4 columns of provinces
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.6,
                      ),
                      itemCount: displayProvinces.length,
                      itemBuilder: (context, index) {
                        final prov = displayProvinces[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => onProvinceTap?.call(region.name, prov.name),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    prov.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    prov.placeCount > 0 ? '${prov.placeCount} địa điểm' : 'Khám phá ngay',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF047857),
                                      fontWeight: FontWeight.w600,
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

                  const SizedBox(height: 16),

                  // 3. ACTION BUTTON (Matching Share_Locations Button)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => onExploreRegionTap?.call(region),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004F32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Khám phá tất cả tỉnh thành ${region.name}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
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

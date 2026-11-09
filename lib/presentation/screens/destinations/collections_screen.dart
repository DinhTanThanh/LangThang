import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/services/travel_api_service.dart';
import '../../../data/services/place_api_service.dart';
import '../../widgets/tour_card.dart';
import 'place_detail_screen.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final TravelApiService _apiService = TravelApiService();
  CollectionModel? _featuredCollection;
  List<TourModel> _tours = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final collection = await _apiService.getFeaturedCollection();
    final tours = await _apiService.getTours();
    if (mounted) {
      setState(() {
        _featuredCollection = collection;
        _tours = tours;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleTourTap(TourModel tour) async {
    final placeId = int.tryParse(tour.id);
    if (placeId != null && placeId > 0) {
      final res = await PlaceApiService().getPlaceDetail(placeId);
      if (!mounted) return;
      if (res.success && res.data != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceDetailScreen(place: res.data!),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Khám phá: ${tour.title}'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const fallbackImage =
        'https://images.unsplash.com/photo-1528127269322-539801943592?w=900&h=600&fit=crop&auto=format';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bộ sưu tập nổi bật',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Tag & Title (matching FeaturedCollectionsSection.tsx)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: AppColors.secondary),
                        SizedBox(width: 4),
                        Text(
                          'GỢI Ý ĐỘC QUYỀN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.secondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bộ sưu tập điểm đến nổi bật',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Những trải nghiệm chân thực, sống động nhất được tuyển chọn kỹ lưỡng trên khắp mọi miền.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Hero Featured Card (Full bleed rounded 24px)
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Khám phá: ${_featuredCollection?.title ?? "Bộ sưu tập"}'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    child: Container(
                      height: 360,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              _tours.isNotEmpty ? _tours.first.imageUrl : fallbackImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Image.network(
                                fallbackImage,
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Gradient Overlay matching Web (from-slate-950/95 via-slate-950/40 to-transparent)
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xF5020617),
                                    Color(0x75020617),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                            // Content
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'BỘ SƯU TẬP TUYỂN CHỌN',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${_tours.length} địa điểm',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _featuredCollection?.title ?? 'Vòng quanh thành phố mang tên Bác',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _featuredCollection?.description ??
                                        'Khám phá những trải nghiệm ẩm thực, văn hóa và góc phố độc đáo nhất.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Row(
                                    children: [
                                      Text(
                                        'Khám phá ngay',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Header for Tour items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Danh sách trải nghiệm (${_tours.length})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 14, color: AppColors.star),
                            SizedBox(width: 3),
                            Text(
                              'Chuẩn 5.0★',
                              style: TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Tour Cards List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tours.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final tour = _tours[index];
                      return SizedBox(
                        width: double.infinity,
                        child: TourCard(
                          tour: tour,
                          onTap: () => _handleTourTap(tour),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}


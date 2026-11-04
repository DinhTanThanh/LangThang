import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/models/province_landing_model.dart';
import '../../../data/services/itinerary_api_service.dart';
import '../itinerary/itinerary_quick_preview_modal.dart';
import '../../screens/itineraries/itinerary_detail_screen.dart';
import '../../screens/profile/user_profile_screen.dart';

class ProvinceItinerarySection extends StatefulWidget {
  final String provinceName;
  final List<ProvinceItineraryModel>? itineraries;
  final List<ProvinceItineraryModel>? initialItineraries;
  final Function(ProvinceItineraryModel itinerary)? onItineraryTap;

  const ProvinceItinerarySection({
    super.key,
    required this.provinceName,
    this.itineraries,
    this.initialItineraries,
    this.onItineraryTap,
  });

  @override
  State<ProvinceItinerarySection> createState() => _ProvinceItinerarySectionState();
}

class _ProvinceItinerarySectionState extends State<ProvinceItinerarySection> {
  List<ProvinceItineraryModel> _itineraryList = [];
  bool _loading = false;
  final Set<int> _appliedIds = {};

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  @override
  void didUpdateWidget(covariant ProvinceItinerarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provinceName != widget.provinceName) {
      _loadItineraries();
    }
  }

  String _cleanName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'^(tp|thành phố|tỉnh)\.?\s+', caseSensitive: false), '')
        .trim();
  }

  Future<void> _loadItineraries() async {
    try {
      final applied = await ItineraryApiService().getAppliedItineraryIds();
      if (mounted) {
        setState(() {
          _appliedIds.addAll(applied);
        });
      }
    } catch (_) {}

    final passedItineraries = widget.itineraries ?? widget.initialItineraries;
    if (passedItineraries != null && passedItineraries.isNotEmpty) {
      setState(() {
        _itineraryList = passedItineraries;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final allItineraries = await ItineraryApiService().getItineraries(pageSize: 50);
      final target = _cleanName(widget.provinceName);

      final matched = allItineraries.where((item) {
        final dest = _cleanName(item.destination);
        final tit = _cleanName(item.title);
        return dest.contains(target) || tit.contains(target) || target.contains(dest);
      }).map((dto) {
        return ProvinceItineraryModel(
          id: dto.id,
          title: dto.title,
          destination: dto.destination.isNotEmpty ? dto.destination : widget.provinceName,
          region: dto.region,
          duration: dto.duration,
          daysCount: dto.daysCount,
          style: dto.style,
          estimatedCost: dto.estimatedCost,
          coverUrl: dto.coverUrl ?? '',
          overview: dto.overview,
          authorName: dto.author.name,
          authorAvatar: dto.author.avatar,
        );
      }).toList();

      if (mounted) {
        if (matched.isNotEmpty) {
          setState(() {
            _itineraryList = matched;
            _loading = false;
          });
        } else {
          // Fallback matching the screenshot style
          setState(() {
            _itineraryList = [
              ProvinceItineraryModel(
                id: 401,
                title: 'Con Đường Di Sản Miền Trung: ${widget.provinceName} & Danh Thắng Cổ Kính (4N3Đ)',
                destination: widget.provinceName,
                region: 'Miền Trung',
                duration: '4 ngày 3 đêm',
                daysCount: 4,
                style: 'Di sản & Văn hóa',
                estimatedCost: '4,800,000đ',
                coverUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600&fit=crop',
                overview: 'Tour khám phá trọn vẹn cảnh sắc miền Trung từ các danh thắng nổi tiếng, cung điện đền đài mộng mơ đến vẻ đẹp cổ kính lung linh...',
                authorName: 'Phạm Văn Phong',
                authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&fit=crop',
              ),
            ];
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _itineraryList = [
            ProvinceItineraryModel(
              id: 401,
              title: 'Con Đường Di Sản Miền Trung: ${widget.provinceName} & Danh Thắng Cổ Kính (4N3Đ)',
              destination: widget.provinceName,
              region: 'Miền Trung',
              duration: '4 ngày 3 đêm',
              daysCount: 4,
              style: 'Di sản & Văn hóa',
              estimatedCost: '4,800,000đ',
              coverUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600&fit=crop',
              overview: 'Tour khám phá trọn vẹn cảnh sắc miền Trung từ các danh thắng nổi tiếng, cung điện đền đài mộng mơ đến vẻ đẹp cổ kính lung linh...',
              authorName: 'Phạm Văn Phong',
              authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&fit=crop',
            ),
          ];
          _loading = false;
        });
      }
    }
  }

  ItineraryModel _mapToItineraryModel(ProvinceItineraryModel item) {
    List<ItineraryDayModel> daysList = [];
    if (item.days != null && item.days!.isNotEmpty) {
      daysList = item.days!.map((d) {
        if (d is ItineraryDayModel) return d;
        if (d is Map<String, dynamic>) return ItineraryDayModel.fromJson(d);
        return const ItineraryDayModel(dayNumber: 1, title: 'Lộ trình tham quan');
      }).toList();
    } else {
      daysList = [
        const ItineraryDayModel(
          dayNumber: 1,
          title: 'Ngày 1: Check-in & Khám phá trung tâm',
          stops: [
            ItineraryStopModel(id: 's1', time: '08:00', activity: 'Đón khách & Ăn sáng đặc sản', location: 'Trung tâm thành phố'),
            ItineraryStopModel(id: 's2', time: '10:00', activity: 'Tham quan danh thắng nổi bật', location: 'Quần thể di tích'),
            ItineraryStopModel(id: 's3', time: '14:30', activity: 'Check-in cảnh đẹp địa phương', location: 'Điểm check-in nổi tiếng'),
          ],
        ),
        const ItineraryDayModel(
          dayNumber: 2,
          title: 'Ngày 2: Trải nghiệm văn hóa & Ẩm thực',
          stops: [
            ItineraryStopModel(id: 's4', time: '09:00', activity: 'Khám phá làng nghề truyền thống', location: 'Khu du lịch sinh thái'),
            ItineraryStopModel(id: 's5', time: '18:00', activity: 'Thưởng thức ẩm thực đêm', location: 'Phố đi bộ & Chợ đêm'),
          ],
        ),
      ];
    }

    return ItineraryModel(
      id: item.id,
      title: item.title,
      destination: item.destination.isNotEmpty ? item.destination : widget.provinceName,
      region: item.region.isNotEmpty ? item.region : 'Việt Nam',
      duration: item.duration,
      daysCount: item.daysCount,
      nightsCount: item.daysCount > 1 ? item.daysCount - 1 : 0,
      style: item.style,
      estimatedCost: item.estimatedCost,
      coverUrl: item.coverUrl,
      overview: item.overview,
      author: ItineraryAuthorModel(
        name: item.authorName,
        avatar: item.authorAvatar,
      ),
      days: daysList,
    );
  }

  void _handleOpenDetail(ProvinceItineraryModel item) {
    if (widget.onItineraryTap != null) {
      widget.onItineraryTap!(item);
      return;
    }
    final fullModel = _mapToItineraryModel(item);
    ItineraryQuickPreviewModal.show(
      context,
      itinerary: fullModel,
      onApply: () => _handleApply(item),
    );
  }

  void _handleApply(ProvinceItineraryModel item) async {
    setState(() {
      _appliedIds.add(item.id);
    });

    final fullModel = _mapToItineraryModel(item);
    await ItineraryApiService().applyItinerary(item.id, itinerary: fullModel, isApplying: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã áp dụng lịch trình "${item.title}" vào chuyến đi của bạn!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF004F32),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItineraryDetailScreen(itinerary: fullModel),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _itineraryList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Lịch Trình Khám Phá ${widget.provinceName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
        ),

        // List of Itineraries
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF004F32),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _itineraryList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = _itineraryList[index];
              return _buildItineraryCard(context, item);
            },
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildItineraryCard(BuildContext context, ProvinceItineraryModel item) {
    final isApplied = _appliedIds.contains(item.id);

    // Calculate total stops
    int totalStops = 12;
    if (item.days != null && item.days!.isNotEmpty) {
      totalStops = item.days!.fold<int>(0, (sum, d) {
        if (d is ItineraryDayModel) return sum + d.stops.length;
        if (d is Map<String, dynamic> && d['stops'] is List) {
          return sum + (d['stops'] as List).length;
        }
        return sum + 3;
      });
    }

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author Row
          InkWell(
            onTap: () => UserProfileScreen.navigate(
              context,
              userId: item.id % 10 + 1,
              userName: item.authorName.isNotEmpty ? item.authorName : 'Tác giả',
              userAvatar: item.authorAvatar,
              userRank: 'Thổ địa',
            ),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.authorAvatar != null && item.authorAvatar!.isNotEmpty)
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(item.authorAvatar!),
                  )
                else
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF0F172A),
                    child: Text(
                      item.authorName.isNotEmpty ? item.authorName[0].toUpperCase() : 'P',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(width: 9),
                Text(
                  item.authorName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Title & Overview
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              height: 1.35,
              letterSpacing: -0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.overview != null && item.overview!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              item.overview!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),

          // 3. Stats Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Left column: Destination + Duration & Stops
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.destination.isNotEmpty ? item.destination : widget.provinceName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.duration.toUpperCase()} • $totalStops ĐIỂM',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                // Right column: Cost + Label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.estimatedCost,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF004F32),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Action Buttons (Xem chi tiết & Áp dụng)
          Row(
            children: [
              // Button 1: Xem chi tiết
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () => _handleOpenDetail(item),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    child: const Text(
                      'Xem chi tiết',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Button 2: Áp dụng
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => _handleApply(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApplied ? const Color(0xFF064E3B) : const Color(0xFF004F32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    child: Text(
                      isApplied ? 'Đã áp dụng' : 'Áp dụng',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/user_profile_data_models.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../screens/destinations/place_detail_screen.dart';
import '../mapbox_interactive_map.dart';

class VisitedLogSectionWidget extends StatefulWidget {
  final VoidCallback? onLogChanged;

  const VisitedLogSectionWidget({
    super.key,
    this.onLogChanged,
  });

  @override
  State<VisitedLogSectionWidget> createState() => _VisitedLogSectionWidgetState();
}

class _VisitedLogSectionWidgetState extends State<VisitedLogSectionWidget> {
  final UserProfileApiService _profileApiService = UserProfileApiService();
  final PlaceApiService _placeApiService = PlaceApiService();

  List<VisitLogItemModel> _allLogs = [];
  bool _isLoading = true;

  // View mode: 'list' or 'map'
  String _viewMode = 'list';

  // Privacy filter: null = all, 0 = public, 1 = private
  int? _privacyFilter;

  // Selected log on Map
  VisitLogItemModel? _mapSelectedLog;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final res = await _profileApiService.getMyVisitLogs();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _allLogs = res.data!;
        }
      });
    }
  }

  List<VisitLogItemModel> get _filteredLogs {
    if (_privacyFilter == null) return _allLogs;
    return _allLogs.where((log) => log.privacy == _privacyFilter).toList();
  }

  int get _publicCount => _allLogs.where((l) => l.privacy == 0).length;
  int get _privateCount => _allLogs.where((l) => l.privacy == 1).length;

  int get _uniqueProvincesCount {
    return _allLogs.map((l) => l.province.trim()).where((p) => p.isNotEmpty).toSet().length;
  }

  Future<void> _togglePrivacy(VisitLogItemModel log) async {
    final newPrivacy = log.privacy == 1 ? 0 : 1;
    final updated = log.copyWith(privacy: newPrivacy);

    setState(() {
      final idx = _allLogs.indexWhere((l) => l.id == log.id);
      if (idx != -1) _allLogs[idx] = updated;
    });

    await _profileApiService.changeVisitLogPrivacy(log.id, newPrivacy);
    widget.onLogChanged?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newPrivacy == 0
            ? 'Đã chuyển sang Công khai'
            : 'Đã chuyển sang Chỉ mình tôi'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _deleteLog(VisitLogItemModel log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa nhật ký ghé thăm?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Bạn có chắc muốn xóa nhật ký tại "${log.placeName}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa ngay'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final removed = log;
      setState(() {
        _allLogs.removeWhere((l) => l.id == log.id);
      });

      await _profileApiService.deleteVisitLog(log.id);
      widget.onLogChanged?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa nhật ký "${removed.placeName}"'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _openAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddVisitLogSheet(
        onSaved: (newItem) {
          setState(() {
            _allLogs.insert(0, newItem);
          });
          widget.onLogChanged?.call();
        },
      ),
    );
  }

  void _openEditModal(VisitLogItemModel log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditVisitLogSheet(
        log: log,
        onUpdated: (updatedItem) {
          setState(() {
            final idx = _allLogs.indexWhere((l) => l.id == updatedItem.id);
            if (idx != -1) _allLogs[idx] = updatedItem;
          });
          widget.onLogChanged?.call();
        },
      ),
    );
  }

  void _navigateToDetail(VisitLogItemModel log) async {
    if (log.placeId > 0) {
      final placeRes = await _placeApiService.getPlaceDetail(log.placeId);
      if (!mounted) return;
      final place = (placeRes.success && placeRes.data != null)
          ? placeRes.data!
          : PlaceModel(
              id: log.placeId,
              name: log.placeName,
              category: log.category.isNotEmpty ? log.category : 'Điểm tham quan',
              location: log.province,
              region: 'Việt Nam',
              province: log.province,
              type: 'Điểm tham quan',
              rating: 5.0,
              reviews: 0,
              price: 'Miễn phí',
              priceMax: 0,
              priceRange: 'Miễn phí',
              hours: '07:30 – 17:30',
              status: 'Đang mở cửa',
              desc: '',
              detailedDescription: '',
              phoneNumber: '',
              website: '',
              img: log.coverImg,
              mediaUrls: log.coverImg.isNotEmpty ? [log.coverImg] : [],
              latitude: log.lat ?? 21.0285,
              longitude: log.lng ?? 105.8542,
              tags: [log.category],
              amenities: const [],
              isSaved: false,
            );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PlaceDetailScreen(place: place)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Header Section =====
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nhật ký đã ghé thăm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_allLogs.length} địa điểm đã ghé qua · $_uniqueProvincesCount tỉnh thành',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons: View mode switcher
                  Row(
                    children: [
                      // View Switcher (Danh sách / Bản đồ)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _viewMode = 'list'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _viewMode == 'list' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _viewMode == 'list'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.grid_view_rounded,
                                      size: 14,
                                      color: _viewMode == 'list' ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Danh sách',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _viewMode == 'list' ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _viewMode = 'map'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _viewMode == 'map' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _viewMode == 'map'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.map_outlined,
                                      size: 14,
                                      color: _viewMode == 'map' ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Bản đồ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _viewMode == 'map' ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Button "Ghi nhận điểm đến"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openAddModal,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Ghi nhận điểm đến',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF065F46),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ===== Privacy Filter Chips =====
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Tất cả (${_allLogs.length})',
                isSelected: _privacyFilter == null,
                onTap: () => setState(() => _privacyFilter = null),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                icon: Icons.public_rounded,
                label: 'Công khai ($_publicCount)',
                isSelected: _privacyFilter == 0,
                selectedColor: const Color(0xFF065F46),
                onTap: () => setState(() => _privacyFilter = 0),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                icon: Icons.lock_outline_rounded,
                label: 'Chỉ mình tôi ($_privateCount)',
                isSelected: _privacyFilter == 1,
                selectedColor: const Color(0xFF1E293B),
                onTap: () => setState(() => _privacyFilter = 1),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ===== Content Body =====
        if (_isLoading)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
            ),
          )
        else if (_viewMode == 'map')
          _buildMapView(filtered)
        else if (filtered.isEmpty)
          _buildEmptyState()
        else
          _buildGridView(filtered),
      ],
    );
  }

  Widget _buildFilterChip({
    IconData? icon,
    required String label,
    required bool isSelected,
    Color? selectedColor,
    required VoidCallback onTap,
  }) {
    final activeBg = selectedColor ?? const Color(0xFF0F172A);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeBg : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeBg.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== GRID / CARD VIEW ====================
  Widget _buildGridView(List<VisitLogItemModel> logs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            return _buildVisitedLogCard(logs[index]);
          },
        );
      },
    );
  }

  Widget _buildVisitedLogCard(VisitLogItemModel log) {
    final isPrivate = log.privacy == 1;

    return GestureDetector(
      onTap: () => _navigateToDetail(log),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aspect ratio square image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.05,
                    child: log.coverImg.isNotEmpty
                        ? Image.network(
                            log.coverImg,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(Icons.explore_outlined, color: Color(0xFF94A3B8), size: 32),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(Icons.explore_outlined, color: Color(0xFF94A3B8), size: 32),
                            ),
                          ),
                  ),

                  // Privacy Toggle Button (Top Right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _togglePrivacy(log),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isPrivate
                              ? const Color(0xFF0F172A).withValues(alpha: 0.85)
                              : const Color(0xFF059669).withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isPrivate ? Icons.lock_outline_rounded : Icons.public_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and action buttons (Edit & Delete)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            log.placeName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openEditModal(log),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.edit_outlined, size: 14, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteLog(log),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFF43F5E)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Visited Date
                    Row(
                      children: [
                        const Text(
                          'Ghé thăm: ',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        Expanded(
                          child: Text(
                            log.visitedDate.isNotEmpty ? log.visitedDate : 'Gần đây',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Location & Category
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            log.province.isNotEmpty
                                ? (log.category.isNotEmpty ? '${log.province} · ${log.category}' : log.province)
                                : 'Việt Nam',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MAP VIEW ====================
  Widget _buildMapView(List<VisitLogItemModel> logs) {
    if (logs.isEmpty) {
      return _buildEmptyState();
    }

    final markers = logs.map((log) {
      final lat = log.lat ?? 16.047079;
      final lng = log.lng ?? 108.20623;

      return MapboxCustomMarker(
        id: 'visit_log_${log.id}',
        latitude: lat,
        longitude: lng,
        child: GestureDetector(
          onTap: () {
            setState(() => _mapSelectedLog = log);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  log.placeName,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    final centerLat = logs.first.lat ?? 16.047079;
    final centerLng = logs.first.lng ?? 108.20623;

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MapboxInteractiveMap(
            initialLat: centerLat,
            initialLng: centerLng,
            initialZoom: 5.5,
            customMarkers: markers,
          ),

          // Selected Log Floating Popup at Bottom
          if (_mapSelectedLog != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: _mapSelectedLog!.coverImg.isNotEmpty
                            ? Image.network(_mapSelectedLog!.coverImg, fit: BoxFit.cover)
                            : Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.explore, size: 20)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mapSelectedLog!.placeName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ghé ngày: ${_mapSelectedLog!.visitedDate}',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065F46),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _navigateToDetail(_mapSelectedLog!),
                      child: const Text('Xem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _mapSelectedLog = null),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.explore_outlined, color: Color(0xFF059669), size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'Chưa có nhật ký chuyến đi nào',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hãy bắt đầu lưu lại các địa điểm du lịch, danh lam thắng cảnh bạn đã từng đặt chân tới.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _openAddModal,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'Ghi nhận điểm đến đầu tiên',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065F46),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ADD VISIT LOG BOTTOM SHEET
// ============================================================================
class _AddVisitLogSheet extends StatefulWidget {
  final Function(VisitLogItemModel) onSaved;

  const _AddVisitLogSheet({required this.onSaved});

  @override
  State<_AddVisitLogSheet> createState() => _AddVisitLogSheetState();
}

class _AddVisitLogSheetState extends State<_AddVisitLogSheet> {
  final PlaceApiService _placeApiService = PlaceApiService();
  final UserProfileApiService _profileApiService = UserProfileApiService();

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<PlaceModel> _searchResults = [];
  bool _isSearching = false;
  PlaceModel? _selectedPlace;

  DateTime _visitedDate = DateTime.now();
  int _privacy = 0; // 0: Công khai, 1: Riêng tư
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final res = await _placeApiService.searchPlaces(
          PlaceFilterParams(keyword: query.trim(), pageSize: 6),
        );
        if (mounted) {
          setState(() {
            _searchResults = res.data ?? [];
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF065F46)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _visitedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedPlace == null) {
      setState(() => _errorMessage = 'Vui lòng tìm kiếm và chọn một địa điểm cụ thể.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final formattedDate =
        '${_visitedDate.year}-${_visitedDate.month.toString().padLeft(2, '0')}-${_visitedDate.day.toString().padLeft(2, '0')}';

    final res = await _profileApiService.createVisitLog(
      placeId: _selectedPlace!.id,
      visitedDate: formattedDate,
      privacy: _privacy,
      placeName: _selectedPlace!.name,
      province: _selectedPlace!.province,
      category: _selectedPlace!.category,
      coverImg: _selectedPlace!.imageUrl,
      lat: _selectedPlace!.latitude,
      lng: _selectedPlace!.longitude,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res.success && res.data != null) {
        widget.onSaved(res.data!);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã ghi nhận "${_selectedPlace!.name}" vào nhật ký!'),
            backgroundColor: const Color(0xFF065F46),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        setState(() => _errorMessage = res.message.isNotEmpty ? res.message : 'Lỗi khi lưu nhật ký');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.explore_rounded, color: Color(0xFF065F46), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ghi nhận điểm đến đã ghé',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Lưu lại dấu chân trên hành trình khám phá',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFE11D48), fontWeight: FontWeight.bold),
                ),
              ),

            // Search input
            const Text('Tìm và chọn địa điểm *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Nhập tên địa điểm để tìm...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  suffixIcon: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF065F46)),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
            ),

            // Search results list
            if (_searchResults.isNotEmpty && _selectedPlace == null) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final p = _searchResults[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: p.imageUrl.isNotEmpty
                              ? Image.network(p.imageUrl, fit: BoxFit.cover)
                              : Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.location_on, size: 18)),
                        ),
                      ),
                      title: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(p.province, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Chọn', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPlace = p;
                          _searchController.text = p.name;
                          _searchResults = [];
                        });
                      },
                    );
                  },
                ),
              ),
            ],

            // Selected Place Indicator
            if (_selectedPlace != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF065F46), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedPlace!.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPlace = null;
                          _searchController.clear();
                        });
                      },
                      child: const Text(
                        'Đổi địa điểm',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Pick Date
            const Text('Ngày ghé thăm *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_visitedDate.day.toString().padLeft(2, '0')}/${_visitedDate.month.toString().padLeft(2, '0')}/${_visitedDate.year}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Privacy Checkbox
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _privacy == 1,
                    activeColor: const Color(0xFF065F46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() => _privacy = (val == true) ? 1 : 0);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _privacy = (_privacy == 1) ? 0 : 1),
                  child: const Text(
                    'Chỉ mình tôi thấy (Riêng tư)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Submit Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065F46),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Lưu điểm đến', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EDIT VISIT LOG BOTTOM SHEET
// ============================================================================
class _EditVisitLogSheet extends StatefulWidget {
  final VisitLogItemModel log;
  final Function(VisitLogItemModel) onUpdated;

  const _EditVisitLogSheet({
    required this.log,
    required this.onUpdated,
  });

  @override
  State<_EditVisitLogSheet> createState() => _EditVisitLogSheetState();
}

class _EditVisitLogSheetState extends State<_EditVisitLogSheet> {
  final UserProfileApiService _profileApiService = UserProfileApiService();

  late DateTime _visitedDate;
  late int _privacy;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _visitedDate = DateTime.tryParse(widget.log.visitedDate) ?? DateTime.now();
    _privacy = widget.log.privacy;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF065F46)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _visitedDate = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final formattedDate =
        '${_visitedDate.year}-${_visitedDate.month.toString().padLeft(2, '0')}-${_visitedDate.day.toString().padLeft(2, '0')}';

    await _profileApiService.updateVisitLog(
      widget.log.id,
      visitedDate: formattedDate,
      privacy: _privacy,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      final updated = widget.log.copyWith(
        visitedDate: formattedDate,
        privacy: _privacy,
      );
      widget.onUpdated(updated);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã cập nhật nhật ký thành công!'),
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chỉnh sửa điểm đến đã ghé',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Place Name
          const Text('Địa điểm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              widget.log.placeName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),

          const SizedBox(height: 14),

          // Pick Date
          const Text('Ngày ghé thăm *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_visitedDate.day.toString().padLeft(2, '0')}/${_visitedDate.month.toString().padLeft(2, '0')}/${_visitedDate.year}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Privacy Checkbox
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _privacy == 1,
                  activeColor: const Color(0xFF065F46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() => _privacy = (val == true) ? 1 : 0);
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _privacy = (_privacy == 1) ? 0 : 1),
                child: const Text(
                  'Chỉ mình tôi thấy (Riêng tư)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Submit Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF065F46),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Cập nhật', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

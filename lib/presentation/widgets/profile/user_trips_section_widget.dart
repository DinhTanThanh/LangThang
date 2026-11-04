import 'package:flutter/material.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/user_profile_data_models.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../../data/services/itinerary_api_service.dart';
import '../../screens/itineraries/itinerary_detail_screen.dart';

class UserTripsSectionWidget extends StatefulWidget {
  final bool isDrawer;
  final VoidCallback? onClose;
  final ValueChanged<String>? onToast;

  const UserTripsSectionWidget({
    super.key,
    this.isDrawer = false,
    this.onClose,
    this.onToast,
  });

  @override
  State<UserTripsSectionWidget> createState() => _UserTripsSectionWidgetState();
}

class _UserTripsSectionWidgetState extends State<UserTripsSectionWidget> {
  final UserProfileApiService _profileApiService = UserProfileApiService();
  final ItineraryApiService _itineraryApiService = ItineraryApiService();
  final TextEditingController _searchController = TextEditingController();

  List<UserTripItemModel> _trips = [];
  bool _isLoading = true;
  bool _isCreating = false;
  int? _loadingTripId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    try {
      final res = await _profileApiService.getMyTrips(pageSize: 50);
      if (mounted) {
        setState(() {
          _trips = res.data ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCreateNewTrip() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    try {
      final newTrip = await _itineraryApiService.createNewTrip(
        title: 'Chuyến đi mới của tôi',
        description: 'Lên kế hoạch cho chuyến hành trình mới.',
      );

      if (!mounted) return;
      setState(() => _isCreating = false);

      if (newTrip != null) {
        widget.onToast?.call('Tạo chuyến đi mới thành công!');
        widget.onClose?.call();

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItineraryDetailScreen(
              itinerary: newTrip,
            ),
          ),
        );
        _loadTrips();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Không thể tạo chuyến đi lúc này. Vui lòng thử lại.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo chuyến đi: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteTrip(UserTripItemModel trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Xóa chuyến đi?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn xóa chuyến đi "${trip.title}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final originalList = List<UserTripItemModel>.from(_trips);
    setState(() {
      _trips.removeWhere((t) => t.id == trip.id);
    });

    final success = await _profileApiService.deleteTrip(trip.id);
    if (!mounted) return;

    if (success) {
      widget.onToast?.call('Đã xóa chuyến đi thành công.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${trip.title}"'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      setState(() => _trips = originalList);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không thể xóa chuyến đi lúc này.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleOpenTrip(UserTripItemModel trip) async {
    if (_loadingTripId != null) return;
    setState(() => _loadingTripId = trip.id);

    try {
      ItineraryModel? detail = await _itineraryApiService.getItineraryDetail(trip.id);

      detail ??= ItineraryModel(
        id: trip.id,
        title: trip.title,
        destination: trip.province ?? 'Việt Nam',
        region: 'Việt Nam',
        duration: '${trip.durationDays} ngày ${trip.nightsCount > 0 ? '${trip.nightsCount} đêm' : ''}',
        daysCount: trip.durationDays,
        nightsCount: trip.nightsCount,
        overview: trip.description ?? 'Lịch trình du lịch do bạn tạo.',
        coverUrl: trip.coverImageUrl ?? '',
        author: const ItineraryAuthorModel(name: 'Bạn', avatar: ''),
      );

      if (!mounted) return;
      setState(() => _loadingTripId = null);

      widget.onClose?.call();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItineraryDetailScreen(
            itinerary: detail!,
          ),
        ),
      );
      _loadTrips();
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTripId = null);
      }
    }
  }

  String _formatDuration(int days, int nights) {
    final d = days > 0 ? days : 1;
    final n = nights >= 0 ? nights : (d > 1 ? d - 1 : 0);
    if (n == 0) return '$d ngày';
    return '$d ngày $n đêm';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Chưa định ngày';
    try {
      final date = DateTime.parse(raw);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return raw;
    }
  }

  List<UserTripItemModel> get _filteredTrips {
    if (_searchQuery.trim().isEmpty) return _trips;
    final q = _searchQuery.toLowerCase().trim();
    return _trips.where((t) {
      final title = t.title.toLowerCase();
      final prov = (t.province ?? '').toLowerCase();
      final desc = (t.description ?? '').toLowerCase();
      return title.contains(q) || prov.contains(q) || desc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTrips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Toolbar: Search + Create New Trip Button
        _buildToolbar(),

        // Body
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF047857), strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text(
                    'Đang tải danh sách chuyến đi...',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          )
        else if (filtered.isEmpty)
          _buildEmptyState()
        else
          widget.isDrawer
              ? Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildDrawerTripCard(filtered[index]),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _buildFullTripCard(filtered[index]),
                ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isDrawer ? 14 : 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isDrawer ? BorderRadius.zero : BorderRadius.circular(16),
        border: widget.isDrawer
            ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))
            : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Search Box
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm chuyến đi của bạn...',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Button Tạo Chuyến
          ElevatedButton.icon(
            onPressed: _isCreating ? null : _handleCreateNewTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isCreating
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.8),
                  )
                : const Icon(Icons.add_rounded, size: 16),
            label: Text(
              _isCreating ? 'Đang tạo...' : 'Tạo chuyến',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.luggage_outlined, size: 30, color: Color(0xFF047857)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Chưa có chuyến đi nào phù hợp',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lên kế hoạch cho chuyến hành trình khám phá các điểm đến tuyệt đẹp của Việt Nam ngay!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _isCreating ? null : _handleCreateNewTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_location_alt_outlined, size: 16),
            label: const Text(
              'Lên lịch trình ngay',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Compact Clean Drawer Layout (Matching TripsUtility.tsx)
  Widget _buildDrawerTripCard(UserTripItemModel trip) {
    final isPublished = trip.privacy == 0 || trip.status == 1;
    final isLoadingThis = _loadingTripId == trip.id;

    return InkWell(
      onTap: () => _handleOpenTrip(trip),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Luggage Icon or Cover
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: trip.coverImageUrl?.isNotEmpty == true
                  ? buildAppImage(
                      trip.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: const Icon(Icons.luggage_rounded, color: Color(0xFF047857), size: 22),
                    )
                  : const Icon(Icons.luggage_rounded, color: Color(0xFF047857), size: 22),
            ),
            const SizedBox(width: 12),

            // Middle Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Text(
                        _formatDuration(trip.durationDays, trip.nightsCount),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                      const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 10.5, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 3),
                          Text(
                            _formatDate(trip.startDate ?? trip.createdAt),
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      if (trip.province?.isNotEmpty == true) ...[
                        const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 10.5, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 2),
                            Text(
                              trip.province!,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right Status Badge & Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPublished ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isPublished ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPublished ? Icons.public_rounded : Icons.lock_outline_rounded,
                            size: 10,
                            color: isPublished ? const Color(0xFF047857) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isPublished ? 'Đã công bố' : 'Riêng tư',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isPublished ? const Color(0xFF047857) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                      tooltip: 'Xóa chuyến đi',
                      onPressed: () => _handleDeleteTrip(trip),
                    ),
                  ],
                ),
                if (isLoadingThis) ...[
                  const SizedBox(height: 4),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(color: Color(0xFF047857), strokeWidth: 1.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Full Rich Card Layout for Profile Tab (Matching UserProfileTripCard.tsx)
  Widget _buildFullTripCard(UserTripItemModel trip) {
    final isPublished = trip.privacy == 0 || trip.status == 1;
    final isLoadingThis = _loadingTripId == trip.id;
    final coverImage = trip.coverImageUrl?.isNotEmpty == true
        ? trip.coverImageUrl!
        : 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=600&h=300&fit=crop';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image & Badges
          Stack(
            children: [
              InkWell(
                onTap: () => _handleOpenTrip(trip),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: buildAppImage(
                    coverImage,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: const Color(0xFFECFDF5),
                      child: const Center(
                        child: Icon(Icons.luggage_rounded, size: 40, color: Color(0xFF047857)),
                      ),
                    ),
                  ),
                ),
              ),

              // Status Badge (Top Left)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPublished ? Icons.public_rounded : Icons.lock_outline_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPublished ? 'Đã công bố' : 'Riêng tư',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              // Delete Button (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _handleDeleteTrip(trip),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Province & Date Row
                Row(
                  children: [
                    if (trip.province?.isNotEmpty == true) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF047857)),
                            const SizedBox(width: 3),
                            Text(
                              trip.province!,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(trip.startDate ?? trip.createdAt),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                InkWell(
                  onTap: () => _handleOpenTrip(trip),
                  child: Text(
                    trip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                ),

                if (trip.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    trip.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Footer: Metrics + Action button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Stops
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 13, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 3),
                            Text(
                              '${trip.totalStopsCount} điểm dừng',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Duration
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF047857)),
                              const SizedBox(width: 3),
                              Text(
                                _formatDuration(trip.durationDays, trip.nightsCount),
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Open Trip Button
                    InkWell(
                      onTap: () => _handleOpenTrip(trip),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLoadingThis) ...[
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(color: Color(0xFF047857), strokeWidth: 1.8),
                              ),
                              const SizedBox(width: 6),
                            ],
                            const Text(
                              'Xem hành trình',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF047857)),
                          ],
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
    );
  }
}

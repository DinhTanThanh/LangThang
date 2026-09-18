import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/travel_api_service.dart';
import '../../widgets/itinerary/itinerary_stop_detail_sheet.dart';
import '../../widgets/itinerary/itinerary_members_sheet.dart';
import '../../widgets/itinerary/itinerary_budget_sheet.dart';
import '../../widgets/itinerary/itinerary_wishlist_sheet.dart';
import '../../widgets/itinerary/add_itinerary_stop_sheet.dart';
import '../../widgets/itinerary/itinerary_place_picker_sheet.dart';

class ItineraryDetailScreen extends StatefulWidget {
  final ItineraryModel itinerary;
  final bool initialIsSaved;

  const ItineraryDetailScreen({
    super.key,
    required this.itinerary,
    this.initialIsSaved = false,
  });

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  late ItineraryModel _itinerary;
  late bool _isSaved;
  int _selectedDayIndex = 0; // 0 = All Days, 1 = Day 1, etc.
  bool _isCompactView = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _itinerary = widget.itinerary;
    _isSaved = widget.initialIsSaved || _itinerary.isSaved;
    _fetchFullDetail();
  }

  Future<void> _fetchFullDetail() async {
    final detail = await TravelApiService().getItineraryDetail(_itinerary.id);
    if (mounted && detail != null) {
      setState(() {
        _itinerary = detail;
      });
    }
  }

  void _toggleSave() async {
    final willSave = !_isSaved;
    setState(() {
      _isSaved = willSave;
      _itinerary = _itinerary.copyWith(isSaved: willSave);
    });

    await TravelApiService().saveItinerary(_itinerary.id, itinerary: _itinerary, isSaving: willSave);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willSave ? 'Đã lưu lịch trình vào bộ sưu tập cá nhân!' : 'Đã bỏ lưu lịch trình.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: willSave ? const Color(0xFF047857) : const Color(0xFF374151),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveTripChanges() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    await TravelApiService().saveItinerary(_itinerary.id, itinerary: _itinerary, isSaving: true);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã lưu tất cả thay đổi lịch trình thành công!'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showAddStopOptions(int dayNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thêm điểm vào Ngày $dayNumber',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF059669)),
              ),
              title: const Text('Chọn từ danh sách địa điểm du lịch', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Tra cứu hàng ngàn điểm tham quan, ẩm thực có sẵn', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                ItineraryPlacePickerSheet.show(
                  context,
                  dayNumber: dayNumber,
                  onSelectPlace: (stop) => _handleAddStop(dayNumber, stop),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF2563EB)),
              ),
              title: const Text('Tự nhập điểm dừng tùy chỉnh', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Nhập tên điểm, thời gian, chi phí và ghi chú riêng', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                AddItineraryStopSheet.show(
                  context,
                  dayNumber: dayNumber,
                  onAddStop: (stop) => _handleAddStop(dayNumber, stop),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleAddStop(int dayNumber, ItineraryStopModel newStop) {
    final days = List<ItineraryDayModel>.from(_itinerary.days);
    final dayIdx = days.indexWhere((d) => d.dayNumber == dayNumber);

    if (dayIdx != -1) {
      final updatedStops = List<ItineraryStopModel>.from(days[dayIdx].stops)..add(newStop);
      days[dayIdx] = days[dayIdx].copyWith(stops: updatedStops);
      setState(() {
        _itinerary = _itinerary.copyWith(days: days);
        _hasUnsavedChanges = true;
      });
    }
  }

  void _handleDeleteStop(int dayNumber, String stopId) {
    final days = List<ItineraryDayModel>.from(_itinerary.days);
    final dayIdx = days.indexWhere((d) => d.dayNumber == dayNumber);

    if (dayIdx != -1) {
      final updatedStops = days[dayIdx].stops.where((s) => s.id != stopId).toList();
      days[dayIdx] = days[dayIdx].copyWith(stops: updatedStops);
      setState(() {
        _itinerary = _itinerary.copyWith(days: days);
        _hasUnsavedChanges = true;
      });
    }
  }

  void _handleMoveStopToDay(int fromDayNumber, int toDayNumber, ItineraryStopModel stop) {
    if (fromDayNumber == toDayNumber) return;
    final days = List<ItineraryDayModel>.from(_itinerary.days);
    final fromIdx = days.indexWhere((d) => d.dayNumber == fromDayNumber);
    final toIdx = days.indexWhere((d) => d.dayNumber == toDayNumber);

    if (fromIdx != -1 && toIdx != -1) {
      days[fromIdx] = days[fromIdx].copyWith(
        stops: days[fromIdx].stops.where((s) => s.id != stop.id).toList(),
      );
      days[toIdx] = days[toIdx].copyWith(
        stops: List<ItineraryStopModel>.from(days[toIdx].stops)..add(stop),
      );
      setState(() {
        _itinerary = _itinerary.copyWith(days: days);
        _hasUnsavedChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chuyển "${stop.activity}" sang Ngày $toDayNumber!'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _handleMoveStopToWishlist(int fromDayNumber, ItineraryStopModel stop) {
    final days = List<ItineraryDayModel>.from(_itinerary.days);
    final fromIdx = days.indexWhere((d) => d.dayNumber == fromDayNumber);

    if (fromIdx != -1) {
      days[fromIdx] = days[fromIdx].copyWith(
        stops: days[fromIdx].stops.where((s) => s.id != stop.id).toList(),
      );
      final updatedBacklog = List<ItineraryStopModel>.from(_itinerary.backlogStops)..add(stop);

      setState(() {
        _itinerary = _itinerary.copyWith(
          days: days,
          backlogStops: updatedBacklog,
        );
        _hasUnsavedChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chuyển "${stop.activity}" vào danh sách dự phòng!'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _handleAddFromWishlist(ItineraryStopModel stop, int targetDayNumber) {
    final days = List<ItineraryDayModel>.from(_itinerary.days);
    final dayIdx = days.indexWhere((d) => d.dayNumber == targetDayNumber);

    if (dayIdx != -1) {
      final updatedStops = List<ItineraryStopModel>.from(days[dayIdx].stops)..add(stop);
      days[dayIdx] = days[dayIdx].copyWith(stops: updatedStops);

      final updatedBacklog = _itinerary.backlogStops.where((s) => s.id != stop.id).toList();

      setState(() {
        _itinerary = _itinerary.copyWith(
          days: days,
          backlogStops: updatedBacklog,
        );
        _hasUnsavedChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm "${stop.activity}" vào Ngày $targetDayNumber!'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _handleAddNewDay() {
    final newDayNum = _itinerary.days.length + 1;
    final newDay = ItineraryDayModel(
      dayNumber: newDayNum,
      title: 'Lộ trình khám phá Ngày $newDayNum',
      description: 'Lộ trình tham quan và trải nghiệm ẩm thực địa phương.',
      stops: [],
    );

    final updatedDays = List<ItineraryDayModel>.from(_itinerary.days)..add(newDay);
    setState(() {
      _itinerary = _itinerary.copyWith(
        days: updatedDays,
        daysCount: newDayNum,
        nightsCount: newDayNum > 1 ? newDayNum - 1 : 0,
      );
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm Ngày $newDayNum vào lịch trình!'),
        backgroundColor: const Color(0xFF047857),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleDeleteDay(int dayNumber) {
    if (_itinerary.days.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lịch trình cần có ít nhất 1 ngày.')),
      );
      return;
    }

    final updatedDays = _itinerary.days
        .where((d) => d.dayNumber != dayNumber)
        .toList()
        .asMap()
        .entries
        .map((e) => e.value.copyWith(dayNumber: e.key + 1))
        .toList();

    setState(() {
      _itinerary = _itinerary.copyWith(
        days: updatedDays,
        daysCount: updatedDays.length,
        nightsCount: updatedDays.length > 1 ? updatedDays.length - 1 : 0,
      );
      if (_selectedDayIndex > updatedDays.length) {
        _selectedDayIndex = 0;
      }
      _hasUnsavedChanges = true;
    });
  }

  void _showEditTitleDialog() {
    final controller = TextEditingController(text: _itinerary.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên chuyến đi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Nhập tiêu đề chuyến đi...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _itinerary = _itinerary.copyWith(title: controller.text.trim());
                  _hasUnsavedChanges = true;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showBudgetTargetDialog() {
    final presets = [3000000, 5000000, 8000000, 10000000, 15000000, 20000000];
    final controller = TextEditingController(
      text: _itinerary.budgetTarget != null ? _itinerary.budgetTarget!.toInt().toString() : '5000000',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Đặt ngân sách mục tiêu',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Ngân sách mong muốn (VNĐ)',
                  prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF059669)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Hoặc chọn nhanh:', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((p) {
                  return ActionChip(
                    label: Text('${(p / 1000000).toInt()} triệu đ'),
                    onPressed: () {
                      controller.text = p.toString();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5000000;
                    setState(() {
                      _itinerary = _itinerary.copyWith(budgetTarget: parsed);
                      _hasUnsavedChanges = true;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cập nhật ngân sách', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = _itinerary.calculatedTotalCost;
    final budgetTarget = _itinerary.budgetTarget ?? (totalCost > 0 ? totalCost * 1.15 : 5000000);
    final ratio = (budgetTarget > 0 && totalCost > 0) ? (totalCost / budgetTarget).clamp(0.0, 1.0) : 1.0;
    final isOverBudget = totalCost > budgetTarget;

    final displayedDays = _selectedDayIndex == 0
        ? _itinerary.days
        : _itinerary.days.where((d) => d.dayNumber == _selectedDayIndex).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          // Parallax Hero App Bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF064E3B),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              // Save / Bookmark Action
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  backgroundColor: _isSaved ? const Color(0xFFE11D48) : Colors.black.withValues(alpha: 0.4),
                  child: IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _toggleSave,
                  ),
                ),
              ),
              // Share Action
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  child: IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Đã sao chép liên kết chia sẻ lịch trình!'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _itinerary.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF064E3B),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tags Row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF047857),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _itinerary.duration,
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _itinerary.destination,
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Title with tap to edit
                        InkWell(
                          onTap: _showEditTitleDialog,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _itinerary.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Body Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unsaved Changes Bar (Matching ItineraryPlannerToolbar.tsx)
                if (_hasUnsavedChanges)
                  Container(
                    color: const Color(0xFFFFFBEB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Bạn có thay đổi chưa lưu',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveTripChanges,
                          icon: _isSaving
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 14),
                          label: Text(_isSaving ? 'Đang lưu...' : 'Lưu lại', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Overview & Author Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Author Row & Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF059669),
                                backgroundImage: _itinerary.authorAvatar.isNotEmpty
                                    ? NetworkImage(_itinerary.authorAvatar)
                                    : null,
                                child: _itinerary.authorAvatar.isEmpty
                                    ? Text(
                                        _itinerary.authorName.isNotEmpty ? _itinerary.authorName[0].toUpperCase() : 'A',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _itinerary.authorName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                  ),
                                  Text(
                                    _itinerary.author.rank,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                                const SizedBox(width: 4),
                                Text(
                                  '${_itinerary.rating} (${_itinerary.reviewCount})',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (_itinerary.overview != null && _itinerary.overview!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _itinerary.overview!,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563), height: 1.5),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Budget Progress Card inside Summary
                      InkWell(
                        onTap: _showBudgetTargetDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isOverBudget ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isOverBudget ? const Color(0xFFFECACA) : const Color(0xFFDCFCE7)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.payments_rounded, size: 16, color: isOverBudget ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                                      const SizedBox(width: 6),
                                      Text(
                                        isOverBudget ? 'Vượt ngân sách mục tiêu' : 'Dự toán ngân sách',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isOverBudget ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6B7280)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    totalCost > 0
                                        ? '${totalCost.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ'
                                        : _itinerary.estimatedCost,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: isOverBudget ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                                    ),
                                  ),
                                  Text(
                                    'Mục tiêu: ${budgetTarget.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOverBudget ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 5,
                                  backgroundColor: isOverBudget ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Action Toolbar (Members, Budget, Wishlist, Add Day, Add Stop)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickActionBtn(
                          icon: Icons.group_rounded,
                          label: 'Thành viên (${_itinerary.members.isNotEmpty ? _itinerary.members.length : 1})',
                          onTap: () => ItineraryMembersSheet.show(
                            context,
                            members: _itinerary.members,
                            onMembersChanged: (newMembers) {
                              setState(() {
                                _itinerary = _itinerary.copyWith(members: newMembers);
                                _hasUnsavedChanges = true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickActionBtn(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Ngân sách',
                          onTap: () => ItineraryBudgetSheet.show(context, itinerary: _itinerary),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickActionBtn(
                          icon: Icons.bookmark_add_rounded,
                          label: 'Dự phòng (${_itinerary.backlogStops.length})',
                          onTap: () => ItineraryWishlistSheet.show(
                            context,
                            backlogStops: _itinerary.backlogStops,
                            days: _itinerary.days,
                            onAddStopToDay: _handleAddFromWishlist,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickActionBtn(
                          icon: Icons.calendar_month_rounded,
                          label: '+ Thêm ngày',
                          onTap: _handleAddNewDay,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickActionBtn(
                          icon: Icons.add_location_alt_rounded,
                          label: '+ Thêm điểm',
                          isPrimary: true,
                          onTap: () => _showAddStopOptions(_selectedDayIndex > 0 ? _selectedDayIndex : 1),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Day Selector Sticky Header Tabs
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildDayTab(0, 'Tất cả (${_itinerary.daysCount} ngày)'),
                        ..._itinerary.days.map((d) => _buildDayTab(d.dayNumber, 'Ngày ${d.dayNumber}')),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE5E7EB)),

                // Timeline Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDayIndex == 0 ? 'Toàn bộ hành trình' : 'Hành trình Ngày $_selectedDayIndex',
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                          ),
                          IconButton(
                            icon: Icon(
                              _isCompactView ? Icons.view_agenda_rounded : Icons.view_headline_rounded,
                              size: 18,
                              color: const Color(0xFF059669),
                            ),
                            onPressed: () {
                              setState(() => _isCompactView = !_isCompactView);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Days list
                      ...displayedDays.map((day) => _buildDayTimelineSection(day)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF059669) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isPrimary ? const Color(0xFF059669) : const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isPrimary ? Colors.white : const Color(0xFF059669)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTab(int index, String label) {
    final isSelected = _selectedDayIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedDayIndex = index),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF059669) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayTimelineSection(ItineraryDayModel day) {
    final dayCost = day.stops.fold(0.0, (acc, s) => acc + s.costEstimateNum);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          day.dayNumber.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày ${day.dayNumber}: ${day.title}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                          ),
                          Row(
                            children: [
                              Text(
                                '${day.stops.length} điểm dừng',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              ),
                              if (dayCost > 0) ...[
                                const Text(' • ', style: TextStyle(color: Color(0xFF9CA3AF))),
                                Text(
                                  '${dayCost.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Actions: Add Stop to Day & Day Options
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF059669), size: 22),
                    tooltip: 'Thêm điểm dừng vào Ngày ${day.dayNumber}',
                    onPressed: () => _showAddStopOptions(day.dayNumber),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF6B7280)),
                    onSelected: (val) {
                      if (val == 'delete') {
                        _handleDeleteDay(day.dayNumber);
                      }
                    },
                    itemBuilder: (context) => [
                      if (_itinerary.days.length > 1)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Xóa ngày này', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.5)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 14),

          // Stops Timeline
          if (day.stops.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.place_outlined, size: 32, color: Color(0xFFD1D5DB)),
                    const SizedBox(height: 8),
                    const Text('Chưa có điểm dừng nào trong ngày này.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12.5)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddStopOptions(day.dayNumber),
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Thêm điểm ngay', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: day.stops.length,
              itemBuilder: (context, index) {
                final stop = day.stops[index];
                final isLast = index == day.stops.length - 1;

                return Column(
                  children: [
                    _buildStopCard(day.dayNumber, stop),
                    if (!isLast) _buildTransportConnector(stop.transportMode),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStopCard(int dayNumber, ItineraryStopModel stop) {
    return InkWell(
      onTap: () => ItineraryStopDetailSheet.show(
        context,
        stop: stop,
        dayNumber: dayNumber,
        onDelete: () => _handleDeleteStop(dayNumber, stop.id),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Time badge, Activity name, Cost, and Stop Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text(
                        stop.time,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Name
                Expanded(
                  child: Text(
                    stop.activity,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                ),

                // Cost Tag
                if (stop.costEstimate != null && stop.costEstimate!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      stop.costEstimate!,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                    ),
                  ),

                // Stop Options Menu
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF9CA3AF)),
                  onSelected: (action) {
                    if (action == 'detail') {
                      ItineraryStopDetailSheet.show(
                        context,
                        stop: stop,
                        dayNumber: dayNumber,
                        onDelete: () => _handleDeleteStop(dayNumber, stop.id),
                      );
                    } else if (action == 'wishlist') {
                      _handleMoveStopToWishlist(dayNumber, stop);
                    } else if (action == 'delete') {
                      _handleDeleteStop(dayNumber, stop.id);
                    } else if (action.startsWith('move_')) {
                      final targetDay = int.tryParse(action.replaceFirst('move_', '')) ?? 1;
                      _handleMoveStopToDay(dayNumber, targetDay, stop);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'detail',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Text('Xem chi tiết', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'wishlist',
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_add_outlined, size: 15, color: Color(0xFF3B82F6)),
                          SizedBox(width: 8),
                          Text('Chuyển vào Điểm dự phòng', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    ..._itinerary.days.where((d) => d.dayNumber != dayNumber).map((d) => PopupMenuItem(
                          value: 'move_${d.dayNumber}',
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              Text('Chuyển sang Ngày ${d.dayNumber}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        )),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text('Xóa điểm dừng', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF059669)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    stop.location,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563)),
                  ),
                ),
              ],
            ),

            // Description
            if (!_isCompactView && stop.description != null && stop.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                stop.description!,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), height: 1.4),
              ),
            ],

            // Tips Box
            if (!_isCompactView && stop.tips != null && stop.tips!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 11, color: Color(0xFFD97706)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Mẹo: ${stop.tips}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransportConnector(String transportMode) {
    IconData icon = Icons.two_wheeler_rounded;
    if (transportMode.toLowerCase().contains('ô tô') || transportMode.toLowerCase().contains('taxi')) {
      icon = Icons.directions_car_rounded;
    } else if (transportMode.toLowerCase().contains('đi bộ')) {
      icon = Icons.directions_walk_rounded;
    } else if (transportMode.toLowerCase().contains('tàu') || transportMode.toLowerCase().contains('cano')) {
      icon = Icons.directions_boat_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 16,
            color: const Color(0xFFD1D5DB),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 12, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 4),
          Text(
            '$transportMode • 15 phút di chuyển',
            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/travel_api_service.dart';
import '../../../data/services/itinerary_api_service.dart';
import '../../../data/services/auth_service.dart';
import '../auth/login_screen.dart';
import '../../widgets/itinerary/itinerary_stop_detail_sheet.dart';
import '../../widgets/itinerary/itinerary_members_sheet.dart';
import '../../widgets/itinerary/itinerary_budget_sheet.dart';
import '../../widgets/itinerary/add_itinerary_stop_sheet.dart';
import '../../widgets/itinerary/itinerary_place_picker_sheet.dart';
import '../../widgets/itinerary/publish_trip_modal.dart';

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
  bool _isPublished = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _currentUserRole = 'Owner';

  final Set<int> _expandedDayIndices = {};
  int _selectedDayTab = 0; // 0 = Tat ca, 1..N = Ngay N, -1 = Kho luu tru
  bool _isSearchVisible = false;
  bool _isWishlistExpanded = true;
  String _searchQuery = '';
  final TextEditingController _quickWishlistController = TextEditingController();

  final List<Color> _dayBadgeColors = const [
    Color(0xFF065F46), // Emerald
    Color(0xFF0284C7), // Sky
    Color(0xFF7C3AED), // Violet
    Color(0xFFD97706), // Amber
    Color(0xFFE11D48), // Rose
    Color(0xFF0D9488), // Teal
  ];

  bool get isOwner => _currentUserRole == 'Owner';
  bool get isEditor => _currentUserRole == 'Editor';
  bool get isViewer => _currentUserRole == 'Viewer';

  bool get canEditStops => (isOwner || isEditor) && !_isPublished;
  bool get canPublish => isOwner;
  bool get canManageMembers => isOwner && !_isPublished;

  @override
  void initState() {
    super.initState();
    _itinerary = widget.itinerary;
    _isPublished = _itinerary.style.contains('Công khai') || _itinerary.id < 100000;
    // Default open all days
    for (int i = 0; i < _itinerary.days.length; i++) {
      _expandedDayIndices.add(i);
    }
    _updateCurrentUserRole();
    _fetchFullDetail();
  }

  @override
  void dispose() {
    _quickWishlistController.dispose();
    super.dispose();
  }

  Future<void> _updateCurrentUserRole() async {
    final cachedUser = await AuthService().getCachedUser() ?? AuthService().currentUser;
    if (cachedUser == null) {
      if (mounted) setState(() => _currentUserRole = 'Owner');
      return;
    }

    if (_itinerary.members.isEmpty) {
      if (mounted) setState(() => _currentUserRole = 'Owner');
      return;
    }

    final userIdInt = int.tryParse(cachedUser.id) ?? -1;
    final myRecord = _itinerary.members.firstWhere(
      (m) => (userIdInt > 0 && m.id > 0 && m.id == userIdInt) ||
             (cachedUser.email.isNotEmpty && m.email.isNotEmpty && m.email.toLowerCase() == cachedUser.email.toLowerCase()),
      orElse: () => const TripMemberModel(id: -1, name: '', role: 'Owner'),
    );

    if (mounted) {
      setState(() {
        if (myRecord.id != -1) {
          _currentUserRole = myRecord.role;
        } else {
          _currentUserRole = 'Owner';
        }
      });
    }
  }

  Future<void> _fetchFullDetail() async {
    final detail = await TravelApiService().getItineraryDetail(_itinerary.id);
    if (mounted && detail != null) {
      setState(() {
        _itinerary = detail;
        for (int i = 0; i < _itinerary.days.length; i++) {
          _expandedDayIndices.add(i);
        }
      });
      _updateCurrentUserRole();
    }
  }

  Future<bool> _ensureAuthenticated(String actionDescription) async {
    final token = await AuthService().getAccessToken();
    if (token != null && token.isNotEmpty) return true;

    if (!mounted) return false;
    final proceedToLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF065F46), size: 24),
            SizedBox(width: 8),
            Text('Yêu cầu đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Phiên đăng nhập đã hết hạn hoặc bạn chưa đăng nhập. Vui lòng đăng nhập lại để $actionDescription và lưu vào cơ sở dữ liệu.',
          style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF475569)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF064E3B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (proceedToLogin == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      final refreshedToken = await AuthService().getAccessToken();
      final authed = refreshedToken != null && refreshedToken.isNotEmpty;
      if (authed) {
        _updateCurrentUserRole();
      }
      return authed;
    }
    return false;
  }

  void _showPermissionDeniedSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _saveTripChanges() async {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem (Chỉ đọc). Không thể lưu thay đổi.');
      return;
    }

    final isAuthed = await _ensureAuthenticated('lưu lịch trình chuyến đi');
    if (!isAuthed) return;

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final success = await TravelApiService().applyItinerary(_itinerary.id, itinerary: _itinerary, isApplying: true);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã lưu toàn bộ lịch trình chuyến đi thành công vào cơ sở dữ liệu!'),
            backgroundColor: const Color(0xFF065F46),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Không thể lưu chuyến đi. Vui lòng thử lại!'),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _openMembersSheet() async {
    final isAuthed = await _ensureAuthenticated('xem và quản lý thành viên chuyến đi');
    if (!isAuthed || !mounted) return;

    await _updateCurrentUserRole();
    if (!mounted) return;

    ItineraryMembersSheet.show(
      context,
      tripId: _itinerary.id,
      tripTitle: _itinerary.title,
      members: _itinerary.members,
      currentUserRole: _currentUserRole,
      isLocked: _isPublished,
      onMembersChanged: (m) => setState(() {
        _itinerary = _itinerary.copyWith(members: m);
        _hasUnsavedChanges = true;
      }),
    );
  }

  Future<void> _togglePublish() async {
    if (!canPublish) {
      _showPermissionDeniedSnackBar('Chỉ Trưởng đoàn mới có quyền xuất bản hoặc thay đổi chế độ công khai của chuyến đi.');
      return;
    }

    final isAuthed = await _ensureAuthenticated('xuất bản chuyến đi');
    if (!isAuthed || !mounted) return;

    if (_isPublished) {
      // Prompt to unpublish and unlock
      final shouldUnpublish = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.lock_open_rounded, color: Color(0xFFD97706), size: 22),
              SizedBox(width: 8),
              Text('Hủy xuất bản chuyến đi?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: const Text(
            'Chuyến đi sẽ được chuyển về chế độ Riêng tư và MỞ KHÓA CHỈNH SỬA cho bạn và các thành viên cùng lên lịch.\n\nBạn có muốn tiếp tục?',
            style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF475569)),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Giữ công khai', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF065F46),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Hủy xuất bản & Mở khóa', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

      if (shouldUnpublish == true && mounted) {
        setState(() {
          _isPublished = false;
          _itinerary = _itinerary.copyWith(style: 'Riêng tư');
          _hasUnsavedChanges = true;
        });
        await TravelApiService().applyItinerary(_itinerary.id, itinerary: _itinerary, isApplying: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã hủy xuất bản chuyến đi. Lịch trình đã được MỞ KHÓA để chỉnh sửa.'),
              backgroundColor: const Color(0xFF065F46),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } else {
      // Open Publish modal with full required info and view-only warning
      PublishTripModal.show(
        context,
        itinerary: _itinerary,
        onPublish: (newTitle, description, coverUrl) async {
          final res = await ItineraryApiService().publishTrip(
            _itinerary.id,
            title: newTitle,
            description: description,
            coverUrl: coverUrl ?? _itinerary.coverUrl,
          );

          if (mounted) {
            if (res.success) {
              setState(() {
                _isPublished = true;
                _itinerary = _itinerary.copyWith(
                  title: newTitle,
                  overview: description,
                  coverUrl: coverUrl ?? _itinerary.coverUrl,
                  style: 'Công khai',
                );
                _hasUnsavedChanges = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message.isNotEmpty ? res.message : 'Đã xuất bản chuyến đi công khai! Chuyến đi hiện đã KHÓA ở chế độ chỉ xem.'),
                  backgroundColor: const Color(0xFF065F46),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 4),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message.isNotEmpty ? res.message : 'Xuất bản chuyến đi thất bại. Vui lòng thử lại!'),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
      );
    }
  }

  void _toggleAllDays() {
    setState(() {
      if (_expandedDayIndices.length == _itinerary.days.length) {
        _expandedDayIndices.clear();
      } else {
        _expandedDayIndices.clear();
        for (int i = 0; i < _itinerary.days.length; i++) {
          _expandedDayIndices.add(i);
        }
      }
    });
  }

  void _toggleDay(int index) {
    setState(() {
      if (_expandedDayIndices.contains(index)) {
        _expandedDayIndices.remove(index);
      } else {
        _expandedDayIndices.add(index);
      }
    });
  }

  void _handleAddNewDay() {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền thêm ngày.');
      return;
    }

    final nextDayNum = _itinerary.days.length + 1;
    final newDay = ItineraryDayModel(
      dayNumber: nextDayNum,
      title: 'Lộ trình Ngày $nextDayNum: Khám phá điểm đến',
      description: 'Lộ trình tham quan và trải nghiệm ẩm thực địa phương.',
      stops: [],
    );

    final updatedDays = List<ItineraryDayModel>.from(_itinerary.days)..add(newDay);
    setState(() {
      _itinerary = _itinerary.copyWith(
        days: updatedDays,
        daysCount: nextDayNum,
        nightsCount: nextDayNum > 1 ? nextDayNum - 1 : 0,
      );
      _expandedDayIndices.add(updatedDays.length - 1);
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm Ngày $nextDayNum vào lịch trình!'),
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleDeleteDay(int dayIndex) {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền xóa ngày.');
      return;
    }

    if (_itinerary.days.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chuyến đi cần tối thiểu 1 ngày.')),
      );
      return;
    }

    final updatedDays = List<ItineraryDayModel>.from(_itinerary.days)..removeAt(dayIndex);
    final renumberedDays = updatedDays.asMap().entries.map((e) {
      final idx = e.key;
      final day = e.value;
      return day.copyWith(dayNumber: idx + 1);
    }).toList();

    setState(() {
      _itinerary = _itinerary.copyWith(
        days: renumberedDays,
        daysCount: renumberedDays.length,
        nightsCount: renumberedDays.length > 1 ? renumberedDays.length - 1 : 0,
      );
      _expandedDayIndices.clear();
      for (int i = 0; i < renumberedDays.length; i++) {
        _expandedDayIndices.add(i);
      }
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xóa ngày khỏi lịch trình. Các ngày sau đã được đánh số lại.'),
        backgroundColor: const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showEditDayDialog(int dayIndex) {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền chỉnh sửa ngày.');
      return;
    }

    final day = _itinerary.days[dayIndex];
    final titleController = TextEditingController(text: day.title);
    final dateController = TextEditingController(text: day.date ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Chỉnh sửa Ngày ${day.dayNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Tiêu đề ngày',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateController,
              decoration: InputDecoration(
                labelText: 'Ngày dự kiến (YYYY-MM-DD)',
                hintText: '2026-09-22',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final newTitle = titleController.text.trim().isNotEmpty ? titleController.text.trim() : day.title;
              final newDate = dateController.text.trim().isNotEmpty ? dateController.text.trim() : null;
              final updatedDays = List<ItineraryDayModel>.from(_itinerary.days);
              updatedDays[dayIndex] = day.copyWith(title: newTitle, date: newDate);
              setState(() {
                _itinerary = _itinerary.copyWith(days: updatedDays);
                _hasUnsavedChanges = true;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46), foregroundColor: Colors.white),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  String get _formattedTripDateText {
    if (_itinerary.startDate == null || _itinerary.startDate!.isEmpty) {
      return 'Chưa đặt ngày';
    }
    try {
      final start = DateTime.parse(_itinerary.startDate!);
      final startFormatted = '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
      if (_itinerary.endDate != null && _itinerary.endDate!.isNotEmpty) {
        final end = DateTime.parse(_itinerary.endDate!);
        final endFormatted = '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
        if (start.year == end.year) {
          return '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} - $endFormatted';
        }
        return '$startFormatted - $endFormatted';
      }
      return startFormatted;
    } catch (_) {
      return _itinerary.startDate!;
    }
  }

  Future<void> _showTripDatePicker() async {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền thay đổi ngày đi của chuyến đi.');
      return;
    }

    DateTime initialStart = DateTime.now();
    if (_itinerary.startDate != null && _itinerary.startDate!.isNotEmpty) {
      try {
        initialStart = DateTime.parse(_itinerary.startDate!);
      } catch (_) {}
    }

    DateTime initialEnd = initialStart.add(Duration(days: _itinerary.daysCount > 1 ? _itinerary.daysCount - 1 : 1));
    if (_itinerary.endDate != null && _itinerary.endDate!.isNotEmpty) {
      try {
        initialEnd = DateTime.parse(_itinerary.endDate!);
      } catch (_) {}
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.date_range_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Thời gian chuyến đi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Current date info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 28, color: Color(0xFF065F46)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ngày đi hiện tại:',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formattedTripDateText,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Tổng thời gian: ${_itinerary.daysCount} Ngày ${_itinerary.nightsCount} Đêm',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action: Open Date Range Picker
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF065F46), size: 20),
              ),
              title: const Text('Chọn khoảng ngày trên lịch', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text('Chọn ngày bắt đầu và kết thúc cho chuyến đi', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            const SizedBox(height: 8),

            // Action: Reset/Clear Dates
            if (_itinerary.startDate != null && _itinerary.startDate!.isNotEmpty) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFEE2E2))),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.event_busy_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                title: const Text('Xóa ngày (Đặt lại về "Chưa đặt ngày")', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                subtitle: const Text('Lưu chuyến đi không cố định ngày khởi hành', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (action == 'clear') {
      setState(() {
        _itinerary = _itinerary.copyWith(
          startDate: '',
          endDate: '',
        );
        _hasUnsavedChanges = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa ngày khởi hành (Chuyển về Chưa đặt ngày).'),
            backgroundColor: Color(0xFF334155),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (action == 'pick' && mounted) {
      final pickedRange = await showDateRangePicker(
        context: context,
        initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        helpText: 'CHỌN THỜI GIAN CHUYẾN ĐI',
        cancelText: 'HỦY',
        confirmText: 'CHỌN',
        saveText: 'LƯU',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF065F46),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF0F172A),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedRange != null && mounted) {
        final startStr = '${pickedRange.start.year.toString().padLeft(4, '0')}-${pickedRange.start.month.toString().padLeft(2, '0')}-${pickedRange.start.day.toString().padLeft(2, '0')}';
        final endStr = '${pickedRange.end.year.toString().padLeft(4, '0')}-${pickedRange.end.month.toString().padLeft(2, '0')}-${pickedRange.end.day.toString().padLeft(2, '0')}';
        final diffDays = pickedRange.end.difference(pickedRange.start).inDays + 1;
        final nights = diffDays > 1 ? diffDays - 1 : 0;

        // Update each day date accordingly
        final updatedDays = <ItineraryDayModel>[];
        for (int i = 0; i < _itinerary.days.length; i++) {
          final dayDate = pickedRange.start.add(Duration(days: i));
          final dayDateStr = '${dayDate.year.toString().padLeft(4, '0')}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
          updatedDays.add(_itinerary.days[i].copyWith(date: dayDateStr));
        }

        setState(() {
          _itinerary = _itinerary.copyWith(
            startDate: startStr,
            endDate: endStr,
            daysCount: diffDays > _itinerary.daysCount ? diffDays : _itinerary.daysCount,
            nightsCount: nights > _itinerary.nightsCount ? nights : _itinerary.nightsCount,
            duration: '$diffDays Ngày ${nights > 0 ? '$nights Đêm' : ''}',
            days: updatedDays.isNotEmpty ? updatedDays : _itinerary.days,
          );
          _hasUnsavedChanges = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật ngày đi: $startStr đến $endStr ($diffDays ngày)'),
            backgroundColor: const Color(0xFF065F46),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showEditTitleDialog() {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền chỉnh sửa thông tin chuyến đi.');
      return;
    }

    final controller = TextEditingController(text: _itinerary.title);
    final provController = TextEditingController(text: _itinerary.destination);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thông tin chuyến đi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Tên chuyến đi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: provController,
              decoration: InputDecoration(
                labelText: 'Tỉnh / Thành phố',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showTripDatePicker();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF065F46)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Thời gian chuyến đi', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                          Text(_formattedTripDateText, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _itinerary = _itinerary.copyWith(
                    title: controller.text.trim(),
                    destination: provController.text.trim().isNotEmpty ? provController.text.trim() : _itinerary.destination,
                  );
                  _hasUnsavedChanges = true;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46), foregroundColor: Colors.white),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showAddStopOptions(int dayNumber) {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền thêm điểm dừng.');
      return;
    }
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
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
                child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF065F46)),
              ),
              title: const Text('Chọn từ danh sách địa điểm du lịch', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Tra cứu hàng ngàn điểm tham quan, ẩm thực có sẵn', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                ItineraryPlacePickerSheet.show(
                  context,
                  tripId: _itinerary.id,
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
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền thêm điểm dừng.');
      return;
    }

    if (dayNumber <= 0) {
      setState(() {
        _itinerary = _itinerary.copyWith(
          backlogStops: [..._itinerary.backlogStops, newStop],
        );
        _hasUnsavedChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm "${newStop.activity}" vào Kho lưu trữ!'),
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final days = List<ItineraryDayModel>.from(_itinerary.days);
    final targetDayNumber = dayNumber;
    var dayIdx = days.indexWhere((d) => d.dayNumber == targetDayNumber);

    if (dayIdx == -1) {
      // Tự động tạo ngày mới nếu chưa có ngày này
      final newDay = ItineraryDayModel(
        dayNumber: targetDayNumber,
        title: 'Lộ trình Ngày $targetDayNumber: Khám phá điểm đến',
        description: 'Lộ trình tham quan và trải nghiệm ẩm thực địa phương.',
        stops: [newStop],
      );
      days.add(newDay);
      days.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      dayIdx = days.indexWhere((d) => d.dayNumber == targetDayNumber);
    } else {
      final updatedStops = List<ItineraryStopModel>.from(days[dayIdx].stops)..add(newStop);
      days[dayIdx] = days[dayIdx].copyWith(stops: updatedStops);
    }

    setState(() {
      _itinerary = _itinerary.copyWith(
        days: days,
        daysCount: days.length,
        nightsCount: days.length > 1 ? days.length - 1 : 0,
      );
      if (!_expandedDayIndices.contains(dayIdx)) {
        _expandedDayIndices.add(dayIdx);
      }
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm "${newStop.activity}" vào Ngày $targetDayNumber!'),
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleDeleteStop(int dayNumber, String stopId, String name) {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền xóa điểm dừng.');
      return;
    }

    final days = List<ItineraryDayModel>.from(_itinerary.days);
    final dayIdx = days.indexWhere((d) => d.dayNumber == dayNumber);

    if (dayIdx != -1) {
      final updatedStops = days[dayIdx].stops.where((s) => s.id != stopId).toList();
      days[dayIdx] = days[dayIdx].copyWith(stops: updatedStops);
      setState(() {
        _itinerary = _itinerary.copyWith(days: days);
        _hasUnsavedChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa "$name".'),
          backgroundColor: const Color(0xFF334155),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _handleMoveStopToDay(int fromDayNumber, int toDayNumber, ItineraryStopModel stop) {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền thay đổi điểm dừng.');
      return;
    }
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
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _handleMoveStopToWishlist(int fromDayNumber, ItineraryStopModel stop) {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền thay đổi điểm dừng.');
      return;
    }
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
          content: Text('Đã chuyển "${stop.activity}" về Kho lưu trữ!'),
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _handleMoveWishlistToDay(int targetDayNumber, ItineraryStopModel stop) {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền xếp điểm dừng.');
      return;
    }
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
          content: Text('Đã xếp "${stop.activity}" vào Ngày $targetDayNumber!'),
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _handleQuickAddWishlist() {
    if (!canEditStops) {
      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền thêm địa điểm.');
      return;
    }
    final text = _quickWishlistController.text.trim();
    if (text.isEmpty) return;

    final newStop = ItineraryStopModel(
      id: 'wishlist-${DateTime.now().millisecondsSinceEpoch}',
      time: '09:00',
      startTime: '09:00',
      endTime: '10:30',
      activity: text,
      location: _itinerary.destination.isNotEmpty ? _itinerary.destination : 'Trung tâm',
      category: 'Điểm tham quan',
      costEstimate: '50.000đ',
      costEstimateNum: 50000,
      description: 'Lưu vào kho chờ xếp lịch',
    );

    setState(() {
      _itinerary = _itinerary.copyWith(
        backlogStops: [..._itinerary.backlogStops, newStop],
      );
      _hasUnsavedChanges = true;
      _quickWishlistController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã lưu "$text" vào Kho lưu trữ!'),
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = _itinerary.calculatedTotalCost;
    final budgetTarget = _itinerary.budgetTarget ?? 5000000;
    final percentUsed = budgetTarget > 0 ? ((totalCost / budgetTarget) * 100).round() : 0;
    final isOverBudget = totalCost > budgetTarget;
    final members = _itinerary.members;

    // Filtered Days by Search Query
    final query = _searchQuery.trim().toLowerCase();
    final allFilteredDays = _itinerary.days.map((day) {
      if (query.isEmpty) return day;
      final filteredStops = day.stops.where((s) {
        return s.activity.toLowerCase().contains(query) ||
            s.location.toLowerCase().contains(query) ||
            s.category.toLowerCase().contains(query) ||
            (s.description ?? '').toLowerCase().contains(query);
      }).toList();
      return day.copyWith(stops: filteredStops);
    }).toList();

    final displayedDays = _selectedDayTab == 0
        ? allFilteredDays
        : (_selectedDayTab > 0
            ? allFilteredDays.where((d) => d.dayNumber == _selectedDayTab).toList()
            : <ItineraryDayModel>[]);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildModernAppBar(members),
      body: Stack(
        children: [
          RefreshIndicator(
            color: const Color(0xFF059669),
            onRefresh: _fetchFullDetail,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role or Publication Status Banners
                  _buildStatusBanner(),

                  // Trip Summary Bento Hero Card
                  _buildTripSummaryCard(totalCost, budgetTarget, percentUsed, isOverBudget),

                  const SizedBox(height: 14),

                  // Horizontal Sticky Day Tabs (Mobile Segmented Bar)
                  _buildDayTabsBar(),

                  const SizedBox(height: 12),

                  // Optional Search Bar (if opened or active query)
                  if (_isSearchVisible || _searchQuery.isNotEmpty) ...[
                    _buildInlineSearchBar(),
                    const SizedBox(height: 12),
                  ],

                  // Content depending on selected tab
                  if (_selectedDayTab == -1) ...[
                    // Dedicated Wishlist / Backlog View
                    _buildWishlistSection(isStandalone: true),
                  ] else if (_itinerary.days.isEmpty) ...[
                    _buildEmptyTripPlaceholder(),
                  ] else if (displayedDays.isEmpty && _searchQuery.isNotEmpty) ...[
                    _buildNoSearchResultsPlaceholder(),
                  ] else ...[
                    // Timeline of Selected / All Days
                    ...displayedDays.asMap().entries.map((entry) {
                      final day = entry.value;
                      final dIdx = _itinerary.days.indexWhere((d) => d.dayNumber == day.dayNumber);
                      return _buildDayTimelineCard(day, dIdx >= 0 ? dIdx : entry.key);
                    }),

                    // If viewing All Days, show Wishlist at bottom as a collapsible section
                    if (_selectedDayTab == 0) ...[
                      const SizedBox(height: 8),
                      _buildWishlistSection(isStandalone: false),
                    ],
                  ],

                  const SizedBox(height: 14),

                  // Discover Places Banner
                  _buildPlaceExplorerBanner(),
                ],
              ),
            ),
          ),

          // Persistent Floating Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActionBar(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(List<TripMemberModel> members) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
        onPressed: () async {
          if (_hasUnsavedChanges) {
            await TravelApiService().applyItinerary(_itinerary.id, itinerary: _itinerary, isApplying: true);
          }
          if (mounted) Navigator.pop(context);
        },
      ),
      title: InkWell(
        onTap: _showEditTitleDialog,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _itinerary.title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF94A3B8)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF059669)),
                  const SizedBox(width: 2),
                  Text(
                    '${_itinerary.destination.isNotEmpty ? _itinerary.destination : 'Việt Nam'} · ${_itinerary.daysCount}N${_itinerary.nightsCount}Đ',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Quick Save Indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: InkWell(
            onTap: _isSaving ? null : _saveTripChanges,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _hasUnsavedChanges ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _hasUnsavedChanges ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSaving)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    Icon(
                      _hasUnsavedChanges ? Icons.save_rounded : Icons.check_circle_outline_rounded,
                      size: 13,
                      color: _hasUnsavedChanges ? Colors.white : const Color(0xFF059669),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    _isSaving
                        ? 'Đang lưu...'
                        : (_hasUnsavedChanges ? 'Lưu *' : 'Đã lưu'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _hasUnsavedChanges ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Members Button
        IconButton(
          tooltip: 'Thành viên chuyến đi',
          icon: Badge(
            isLabelVisible: members.isNotEmpty,
            label: Text(
              '${members.isNotEmpty ? members.length : 1}',
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF059669),
            child: const Icon(Icons.group_rounded, color: Color(0xFF475569), size: 21),
          ),
          onPressed: _openMembersSheet,
        ),

        // More Options Popup Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF475569), size: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (val) {
            if (val == 'publish') {
              _togglePublish();
            } else if (val == 'edit_title') {
              _showEditTitleDialog();
            } else if (val == 'dates') {
              _showTripDatePicker();
            } else if (val == 'budget') {
              ItineraryBudgetSheet.show(
                context,
                itinerary: _itinerary,
                onBudgetChanged: (newBudget) {
                  setState(() {
                    _itinerary = _itinerary.copyWith(budgetTarget: newBudget);
                    _hasUnsavedChanges = true;
                  });
                },
              );
            } else if (val == 'add_day') {
              _handleAddNewDay();
            } else if (val == 'toggle_all') {
              _toggleAllDays();
            } else if (val == 'search') {
              setState(() => _isSearchVisible = !_isSearchVisible);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'publish',
              child: Row(
                children: [
                  Icon(
                    _isPublished ? Icons.lock_outline_rounded : Icons.public_rounded,
                    size: 16,
                    color: _isPublished ? const Color(0xFFD97706) : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPublished ? 'Hủy xuất bản (Chuyển riêng tư)' : 'Xuất bản công khai',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit_title',
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF475569)),
                  SizedBox(width: 8),
                  Text('Đổi tên & Điểm đến', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'dates',
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF475569)),
                  SizedBox(width: 8),
                  Text('Cài đặt ngày khởi hành', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'budget',
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF475569)),
                  SizedBox(width: 8),
                  Text('Quản lý ngân sách', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_day',
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Text('Thêm ngày mới', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'toggle_all',
              child: Row(
                children: [
                  Icon(Icons.unfold_more_rounded, size: 16, color: Color(0xFF475569)),
                  SizedBox(width: 8),
                  Text('Thu gọn / Mở rộng tất cả', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'search',
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: Color(0xFF475569)),
                  const SizedBox(width: 8),
                  Text(
                    _isSearchVisible ? 'Ẩn thanh tìm kiếm' : 'Tìm kiếm trong lịch trình',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF1F5F9), height: 1),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_isPublished) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFFD97706)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chế độ Chỉ xem (Đã xuất bản)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Chuyến đi đã xuất bản công khai. Bạn không thể sửa điểm dừng khi đang ở chế độ này.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.35),
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: _togglePublish,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.lock_open_rounded, size: 12, color: Color(0xFF065F46)),
                          SizedBox(width: 4),
                          Text(
                            'Hủy xuất bản để mở khóa chỉnh sửa',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    } else if (isViewer) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: const [
            Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bạn đang là Thành viên xem (Viewer) của chuyến đi này.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } else if (isEditor) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: const [
            Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFF059669)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bạn có quyền Cộng tác viên (Editor) để cùng lên lịch trình.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTripSummaryCard(double totalCost, double budgetTarget, int percentUsed, bool isOverBudget) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title + Privacy Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _itinerary.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          'Điểm đến: ${_itinerary.destination.isNotEmpty ? _itinerary.destination : 'Việt Nam'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Privacy Badge Tap
              InkWell(
                onTap: _togglePublish,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isPublished ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isPublished ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPublished ? Icons.public_rounded : Icons.lock_outline_rounded,
                        size: 11,
                        color: _isPublished ? const Color(0xFF065F46) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPublished ? 'CÔNG KHAI' : 'RIÊNG TƯ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _isPublished ? const Color(0xFF065F46) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3 Metric Bento Tiles: Thời gian, Ngân sách, Điểm dừng
          Row(
            children: [
              // 1. Date Tile
              Expanded(
                child: InkWell(
                  onTap: _showTripDatePicker,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text(
                              'Thời gian',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formattedTripDateText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_itinerary.daysCount} ngày',
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Budget Tile
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (!canEditStops) {
                      _showPermissionDeniedSnackBar('Bạn đang ở chế độ xem. Không có quyền điều chỉnh ngân sách.');
                      return;
                    }
                    ItineraryBudgetSheet.show(
                      context,
                      itinerary: _itinerary,
                      onBudgetChanged: (newBudget) {
                        setState(() {
                          _itinerary = _itinerary.copyWith(budgetTarget: newBudget);
                          _hasUnsavedChanges = true;
                        });
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isOverBudget ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOverBudget ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 12,
                              color: isOverBudget ? const Color(0xFFE11D48) : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ngân sách',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isOverBudget ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          totalCost > 0
                              ? '${(totalCost / 1000000).toStringAsFixed(1)}tr / ${(budgetTarget / 1000000).toStringAsFixed(1)}tr'
                              : '0 / ${(budgetTarget / 1000000).toStringAsFixed(1)}tr',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isOverBudget ? const Color(0xFFBE123C) : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Mini Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            height: 4,
                            width: double.infinity,
                            color: const Color(0xFFE2E8F0),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (percentUsed / 100).clamp(0.0, 1.0),
                              child: Container(
                                color: isOverBudget ? const Color(0xFFE11D48) : const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Stops Tile
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.pin_drop_rounded, size: 12, color: Color(0xFF0284C7)),
                          SizedBox(width: 4),
                          Text(
                            'Điểm dừng',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_itinerary.stopCount} địa điểm',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_itinerary.backlogStops.length} trong kho',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFFD97706), fontWeight: FontWeight.w700),
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

  Widget _buildDayTabsBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. "Tất cả" Tab
          _buildDayTabItem(
            tabIndex: 0,
            label: 'Tất cả (${_itinerary.stopCount})',
            icon: Icons.dashboard_outlined,
            isSelected: _selectedDayTab == 0,
          ),
          const SizedBox(width: 6),

          // 2. Individual Day Tabs
          ..._itinerary.days.map((d) {
            final isSelected = _selectedDayTab == d.dayNumber;
            final badgeColor = _dayBadgeColors[(d.dayNumber - 1) % _dayBadgeColors.length];
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildDayTabItem(
                tabIndex: d.dayNumber,
                label: 'Ngày ${d.dayNumber}',
                subBadge: '${d.stops.length}',
                badgeColor: badgeColor,
                isSelected: isSelected,
              ),
            );
          }),

          // 3. Wishlist Tab
          _buildDayTabItem(
            tabIndex: -1,
            label: 'Kho lưu trữ',
            subBadge: '${_itinerary.backlogStops.length}',
            badgeColor: const Color(0xFFD97706),
            icon: Icons.bookmark_added_rounded,
            isSelected: _selectedDayTab == -1,
          ),
          const SizedBox(width: 6),

          // 4. Quick Add Day Button
          InkWell(
            onTap: _handleAddNewDay,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_rounded, size: 15, color: Color(0xFF059669)),
                  SizedBox(width: 4),
                  Text(
                    'Thêm ngày',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabItem({
    required int tabIndex,
    required String label,
    String? subBadge,
    Color? badgeColor,
    IconData? icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedDayTab = tabIndex),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (subBadge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (badgeColor != null ? badgeColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subBadge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Colors.white
                        : (badgeColor ?? const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Tìm địa điểm, món ăn, hoạt động...',
                hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
              onPressed: () => setState(() => _searchQuery = ''),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildDayTimelineCard(ItineraryDayModel day, int dIdx) {
    final badgeColor = _dayBadgeColors[dIdx % _dayBadgeColors.length];
    final dayCost = day.stops.fold(0.0, (acc, s) => acc + s.costEstimateNum);
    final isExpanded = !_expandedDayIndices.contains(dIdx);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Day Header Bar
          InkWell(
            onTap: () => _toggleDay(dIdx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  // Day Badge (N1, N2...)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'N${day.dayNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Day Title & Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                day.title,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _showEditDayDialog(dIdx),
                              child: const Icon(Icons.edit_rounded, size: 13, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${day.stops.length} điểm dừng${dayCost > 0 ? " · ${dayCost.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ" : ""}${day.date != null && day.date!.isNotEmpty ? " · ${day.date!}" : ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Actions: Add Stop, Delete Day, Chevron
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAddStopOptions(day.dayNumber),
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Thêm điểm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (_itinerary.days.length > 1) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Xóa ngày này',
                          onPressed: () => _handleDeleteDay(dIdx),
                        ),
                      ],
                      const SizedBox(width: 2),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Timeline Body
          if (isExpanded) ...[
            if (day.stops.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: InkWell(
                  onTap: () => _showAddStopOptions(day.dayNumber),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.add_location_alt_outlined, size: 28, color: Color(0xFF059669)),
                        const SizedBox(height: 6),
                        Text(
                          'Chưa có điểm dừng nào trong Ngày ${day.dayNumber}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Chạm để chọn địa điểm, món ngon hoặc tạo điểm dừng mới',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Column(
                  children: day.stops.asMap().entries.map((stopEntry) {
                    final sIdx = stopEntry.key;
                    final stop = stopEntry.value;
                    final isLast = sIdx == day.stops.length - 1;
                    return _buildTimelineStopItem(day, stop, sIdx, isLast);
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineStopItem(ItineraryDayModel day, ItineraryStopModel stop, int sIdx, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Timeline Axis with Node & Connector Line
          SizedBox(
            width: 30,
            child: Column(
              children: [
                // Node
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF059669), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${sIdx + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
                // Connector Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFCBD5E1),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right: Stop Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Chips: Time, Transport, Category, Context Menu
                  Row(
                    children: [
                      // Time Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 10, color: Color(0xFF059669)),
                            const SizedBox(width: 3),
                            Text(
                              '${stop.startTime} - ${stop.endTime}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),

                      // Transport Mode
                      if (stop.transportMode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            stop.transportMode,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                        ),

                      const Spacer(),

                      // Cost Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          stop.costEstimateNum > 0
                              ? '${stop.costEstimateNum.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ'
                              : (stop.costEstimate != null && stop.costEstimate!.isNotEmpty ? stop.costEstimate! : 'Miễn phí'),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // More Menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF94A3B8)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val == 'edit') {
                            ItineraryStopDetailSheet.show(
                              context,
                              stop: stop,
                              dayNumber: day.dayNumber,
                              onDelete: () => _handleDeleteStop(day.dayNumber, stop.id, stop.activity),
                            );
                          } else if (val == 'wishlist') {
                            _handleMoveStopToWishlist(day.dayNumber, stop);
                          } else if (val == 'delete') {
                            _handleDeleteStop(day.dayNumber, stop.id, stop.activity);
                          } else if (val.startsWith('move_')) {
                            final targetDayNum = int.tryParse(val.split('_')[1]);
                            if (targetDayNum != null) {
                              _handleMoveStopToDay(day.dayNumber, targetDayNum, stop);
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 15, color: Color(0xFF475569)),
                                SizedBox(width: 8),
                                Text('Chỉnh sửa chi tiết', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          ..._itinerary.days
                              .where((d) => d.dayNumber != day.dayNumber)
                              .map((d) => PopupMenuItem(
                                    value: 'move_${d.dayNumber}',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.drive_file_move_outline, size: 15, color: Color(0xFF475569)),
                                        const SizedBox(width: 8),
                                        Text('Chuyển sang Ngày ${d.dayNumber}', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  )),
                          const PopupMenuItem(
                            value: 'wishlist',
                            child: Row(
                              children: [
                                Icon(Icons.bookmark_add_outlined, size: 15, color: Color(0xFFD97706)),
                                SizedBox(width: 8),
                                Text('Chuyển vào Kho lưu trữ', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Xóa điểm dừng', style: TextStyle(fontSize: 12, color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Stop Title & Location (Tap to view detail)
                  InkWell(
                    onTap: () {
                      ItineraryStopDetailSheet.show(
                        context,
                        stop: stop,
                        dayNumber: day.dayNumber,
                        onDelete: () => _handleDeleteStop(day.dayNumber, stop.id, stop.activity),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.activity,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 11, color: Color(0xFF64748B)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                stop.location,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (stop.description != null && stop.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            stop.description!,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistSection({required bool isStandalone}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Wishlist Header
          InkWell(
            onTap: isStandalone ? null : () => setState(() => _isWishlistExpanded = !_isWishlistExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bookmark_added_rounded, size: 16, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kho lưu trữ & Chờ xếp lịch',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '${_itinerary.backlogStops.length} địa điểm đang chờ xếp vào các ngày',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!isStandalone)
                    Icon(
                      _isWishlistExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF64748B),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),

          // Wishlist Content
          if (isStandalone || _isWishlistExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // Quick add row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: _quickWishlistController,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Nhập nhanh tên địa điểm muốn lưu...',
                              hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onSubmitted: (_) => _handleQuickAddWishlist(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleQuickAddWishlist,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Lưu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => ItineraryPlacePickerSheet.show(
                          context,
                          tripId: _itinerary.id,
                          dayNumber: 0,
                          initialMode: 'knn_suggestions',
                          onSelectPlace: (stop) => _handleAddStop(0, stop),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF047857)),
                        label: const Text(
                          'Đề xuất theo gu đoàn',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (_itinerary.backlogStops.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Kho lưu trữ đang trống. Bạn có thể lưu các điểm đến yêu thích tại đây để xếp lịch sau.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    )
                  else
                    ..._itinerary.backlogStops.map((stop) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stop.activity,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${stop.category} · ${stop.location}',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<int>(
                              icon: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'Xếp vào ngày',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.arrow_drop_down_rounded, size: 14, color: Color(0xFF065F46)),
                                  ],
                                ),
                              ),
                              onSelected: (targetDayNum) => _handleMoveWishlistToDay(targetDayNum, stop),
                              itemBuilder: (context) => _itinerary.days
                                  .map((d) => PopupMenuItem<int>(
                                        value: d.dayNumber,
                                        child: Text('Xếp vào Ngày ${d.dayNumber}', style: const TextStyle(fontSize: 12)),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyTripPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_location_alt_rounded, size: 36, color: Color(0xFF065F46)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Lịch trình chưa có ngày hay địa điểm nào',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Hãy tạo ngày đầu tiên và thêm các địa điểm tham quan để bắt đầu thiết kế lịch trình theo ý bạn.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _handleAddNewDay,
                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                label: const Text('Thêm Ngày 1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showAddStopOptions(1),
                icon: const Icon(Icons.add_location_rounded, size: 14, color: Color(0xFF059669)),
                label: const Text('Thêm điểm dừng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF059669)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResultsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            'Không tìm thấy điểm dừng nào khớp với "$_searchQuery"',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceExplorerBanner() {
    final activeDayNum = _selectedDayTab > 0 ? _selectedDayTab : 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.explore_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Khám phá thêm địa điểm du lịch',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  'Tra cứu danh thắng, ẩm thực và thêm vào lịch trình chỉ với 1 chạm.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFD1FAE5)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => ItineraryPlacePickerSheet.show(
              context,
              tripId: _itinerary.id,
              dayNumber: activeDayNum,
              initialMode: 'knn_suggestions',
              onSelectPlace: (stop) => _handleAddStop(activeDayNum, stop),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF064E3B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            child: const Text('Mở thư viện', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final activeDayNum = _selectedDayTab > 0 ? _selectedDayTab : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Primary Add Stop Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAddStopOptions(activeDayNum),
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: Text(
                  _selectedDayTab > 0 ? 'Thêm điểm vào Ngày $activeDayNum' : 'Thêm điểm dừng',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // AI / Place Explorer Recommendation Button
            InkWell(
              onTap: () => ItineraryPlacePickerSheet.show(
                context,
                tripId: _itinerary.id,
                dayNumber: activeDayNum,
                initialMode: 'knn_suggestions',
                onSelectPlace: (stop) => _handleAddStop(activeDayNum, stop),
              ),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF059669)),
                    SizedBox(width: 4),
                    Text(
                      'Gợi ý',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
                      ),
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
}

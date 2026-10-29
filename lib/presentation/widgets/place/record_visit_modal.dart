import 'package:flutter/material.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../screens/auth/login_screen.dart';

class RecordVisitModal extends StatefulWidget {
  final PlaceModel place;
  final VoidCallback? onRecorded;

  const RecordVisitModal({
    super.key,
    required this.place,
    this.onRecorded,
  });

  static Future<bool?> show(
    BuildContext context, {
    required PlaceModel place,
    VoidCallback? onRecorded,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecordVisitModal(
        place: place,
        onRecorded: onRecorded,
      ),
    );
  }

  @override
  State<RecordVisitModal> createState() => _RecordVisitModalState();
}

class _RecordVisitModalState extends State<RecordVisitModal> {
  final UserProfileApiService _profileApiService = UserProfileApiService();
  final TextEditingController _noteController = TextEditingController();

  DateTime _visitedDate = DateTime.now();
  int _rating = 5;
  int _privacy = 1; // 1: Riêng tư, 0: Công khai
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingLog();
  }

  Future<void> _loadExistingLog() async {
    try {
      final res = await _profileApiService.getMyVisitLogs();
      if (res.success && res.data != null && mounted) {
        final matches = res.data!.where((v) => v.placeId == widget.place.id).toList();
        if (matches.isNotEmpty) {
          final existing = matches.first;
          setState(() {
            if (existing.note != null && existing.note!.isNotEmpty) {
              _noteController.text = existing.note!;
            }
            if (existing.rating != null && existing.rating! >= 1 && existing.rating! <= 5) {
              _rating = existing.rating!;
            }
            _privacy = existing.privacy;
            if (existing.visitedDate.isNotEmpty) {
              final parsed = DateTime.tryParse(existing.visitedDate);
              if (parsed != null) {
                _visitedDate = parsed;
              }
            }
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Tệ / Thất vọng';
      case 2:
        return 'Tạm được';
      case 3:
        return 'Bình thường / Hài lòng';
      case 4:
        return 'Rất tốt';
      case 5:
        return 'Tuyệt vời / Rất ấn tượng';
      default:
        return 'Đánh giá chuyến đi';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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

  Future<void> _handleSubmit() async {
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng đăng nhập để ghi nhận điểm đến.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }

    setState(() => _isSubmitting = true);

    final dateStr =
        '${_visitedDate.year}-${_visitedDate.month.toString().padLeft(2, '0')}-${_visitedDate.day.toString().padLeft(2, '0')}';

    final res = await _profileApiService.createVisitLog(
      placeId: widget.place.id,
      visitedDate: dateStr,
      privacy: _privacy,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      rating: _rating > 0 ? _rating : null,
      placeName: widget.place.name,
      province: widget.place.province.isNotEmpty ? widget.place.province : widget.place.location,
      category: widget.place.category.isNotEmpty ? widget.place.category : widget.place.type,
      coverImg: widget.place.img,
      lat: widget.place.latitude,
      lng: widget.place.longitude,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.success) {
      widget.onRecorded?.call();
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Đã ghi nhận điểm đến vào nhật ký hành trình!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty ? res.message : 'Không thể ghi nhận điểm đến.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );

      if (res.code == '401' || res.message.toLowerCase().contains('đăng nhập')) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header title & close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bookmark_add_rounded, color: Color(0xFF065F46), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Ghi nhận điểm đến',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Place info summary card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.place.img.isNotEmpty
                        ? Image.network(
                            widget.place.img,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 52,
                              height: 52,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.place_rounded, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.place_rounded, color: Color(0xFF94A3B8)),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.place.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.place.province.isNotEmpty
                              ? '${widget.place.province} · ${widget.place.category.isNotEmpty ? widget.place.category : 'Khám phá'}'
                              : (widget.place.location.isNotEmpty ? widget.place.location : 'Việt Nam'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
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

            const SizedBox(height: 18),

            // Visited Date Picker
            const Text(
              'Ngày ghé thăm *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF065F46)),
                        const SizedBox(width: 8),
                        Text(
                          '${_visitedDate.day.toString().padLeft(2, '0')}/${_visitedDate.month.toString().padLeft(2, '0')}/${_visitedDate.year}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Rating Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Đánh giá trải nghiệm',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                Text(
                  _getRatingText(_rating),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isSelected = starIndex <= _rating;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = starIndex),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        size: 34,
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Note / Cảm nghĩ chuyến đi
            const Text(
              'Ghi chú / Cảm nghĩ về chuyến đi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 500,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Nhập cảm nhận, mẹo du lịch hoặc kỷ niệm đáng nhớ của bạn...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF065F46), width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Privacy Toggle Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    _privacy == 1 ? Icons.lock_outline_rounded : Icons.public_rounded,
                    color: _privacy == 1 ? const Color(0xFF64748B) : const Color(0xFF059669),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _privacy == 1 ? 'Chỉ mình tôi (Riêng tư)' : 'Công khai với mọi người',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _privacy == 1
                              ? 'Chỉ bạn mới nhìn thấy ghi nhận này trong nhật ký'
                              : 'Hiển thị trên trang cá nhân của bạn',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _privacy == 1,
                    activeTrackColor: const Color(0xFF065F46).withValues(alpha: 0.5),
                    activeThumbColor: const Color(0xFF065F46),
                    onChanged: (val) {
                      setState(() => _privacy = val ? 1 : 0);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065F46),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Lưu ghi nhận',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

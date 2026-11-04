import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/itinerary_api_service.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/itineraries/itinerary_detail_screen.dart';

class AddPlaceToTripSheet extends StatefulWidget {
  final PlaceModel place;

  const AddPlaceToTripSheet({super.key, required this.place});

  static Future<bool?> show(BuildContext context, {required PlaceModel place}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPlaceToTripSheet(place: place),
    );
  }

  @override
  State<AddPlaceToTripSheet> createState() => _AddPlaceToTripSheetState();
}

class _AddPlaceToTripSheetState extends State<AddPlaceToTripSheet> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<ItineraryModel> _myTrips = [];
  ItineraryModel? _selectedTrip;
  int _selectedDayNumber = 1;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _newTripTitleController = TextEditingController();

  String _startTime = '08:30';
  String _endTime = '10:30';
  String _transportMode = 'Xe máy';
  bool _isCreatingNewTrip = false;

  final List<String> _transportModes = const [
    'Xe máy',
    'Ô tô',
    'Đi bộ',
    'Taxi / Grab',
    'Xe buýt',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserTrips();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _costController.dispose();
    _newTripTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadUserTrips() async {
    setState(() => _isLoading = true);
    try {
      final trips = await ItineraryApiService().getCustomItineraries();
      if (mounted) {
        setState(() {
          _myTrips = trips;
          if (trips.isNotEmpty) {
            _selectedTrip = trips.first;
            _selectedDayNumber = trips.first.days.isNotEmpty ? trips.first.days.first.dayNumber : 1;
          } else {
            _isCreatingNewTrip = true;
            _newTripTitleController.text = 'Chuyến đi khám phá ${widget.place.province.isNotEmpty ? widget.place.province : widget.place.name}';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSave() async {
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng đăng nhập để lưu vào lịch trình chuyến đi của bạn.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      ItineraryModel? targetTrip = _selectedTrip;

      // Nếu đang tạo chuyến đi mới
      if (_isCreatingNewTrip || targetTrip == null) {
        final title = _newTripTitleController.text.trim().isNotEmpty
            ? _newTripTitleController.text.trim()
            : 'Chuyến đi khám phá ${widget.place.province.isNotEmpty ? widget.place.province : widget.place.name}';

        final created = await ItineraryApiService().createNewTrip(
          title: title,
          destination: widget.place.province.isNotEmpty ? widget.place.province : 'Việt Nam',
          region: widget.place.region.isNotEmpty ? widget.place.region : 'Việt Nam',
        );

        if (created == null) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể tạo chuyến đi mới. Vui lòng thử lại.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
          return;
        }

        targetTrip = created;
        _selectedDayNumber = 1;
      }

      final costText = _costController.text.trim();
      double costNum = 0;
      if (costText.isNotEmpty) {
        costNum = double.tryParse(costText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }

      final success = await ItineraryApiService().addPlaceToTrip(
        tripId: targetTrip.id,
        dayNumber: _selectedDayNumber,
        placeName: widget.place.name,
        placeId: widget.place.id,
        location: widget.place.location.isNotEmpty ? widget.place.location : widget.place.province,
        category: widget.place.category.isNotEmpty ? widget.place.category : widget.place.type,
        coverUrl: widget.place.img,
        startTime: _startTime,
        endTime: _endTime,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        estimatedCost: costNum,
        transportMode: _transportMode,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã thêm "${widget.place.name}" vào Ngày $_selectedDayNumber của "${targetTrip.title}"',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Xem chuyến đi',
              textColor: const Color(0xFFFBBF24),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItineraryDetailScreen(itinerary: targetTrip!),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể thêm điểm đến vào chuyến đi. Vui lòng thử lại.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final parts = (isStart ? _startTime : _endTime).split(':');
    final initialHour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 8) : 8;
    final initialMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null && mounted) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        if (isStart) {
          _startTime = '$hourStr:$minuteStr';
        } else {
          _endTime = '$hourStr:$minuteStr';
        }
      });
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
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 250,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF047857)),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF047857), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thêm vào lịch trình',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                widget.place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF047857),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 16),

                  // Mode Switch: Existing trip or New trip
                  if (_myTrips.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isCreatingNewTrip = false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isCreatingNewTrip ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !_isCreatingNewTrip ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                                  width: !_isCreatingNewTrip ? 1.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Chuyến đi có sẵn (${_myTrips.length})',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: !_isCreatingNewTrip ? const Color(0xFF047857) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isCreatingNewTrip = true;
                                if (_newTripTitleController.text.isEmpty) {
                                  _newTripTitleController.text =
                                      'Chuyến đi khám phá ${widget.place.province.isNotEmpty ? widget.place.province : widget.place.name}';
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isCreatingNewTrip ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isCreatingNewTrip ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                                  width: _isCreatingNewTrip ? 1.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '+ Tạo chuyến đi mới',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _isCreatingNewTrip ? const Color(0xFF047857) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // If selecting existing trip
                  if (!_isCreatingNewTrip && _myTrips.isNotEmpty) ...[
                    const Text(
                      'Chọn chuyến đi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ItineraryModel>(
                          isExpanded: true,
                          value: _selectedTrip ?? _myTrips.first,
                          items: _myTrips.map((t) {
                            return DropdownMenuItem<ItineraryModel>(
                              value: t,
                              child: Row(
                                children: [
                                  const Icon(Icons.luggage_outlined, size: 18, color: Color(0xFF047857)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t.title,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '(${t.duration})',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedTrip = val;
                                _selectedDayNumber = val.days.isNotEmpty ? val.days.first.dayNumber : 1;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Day selection
                    const Text(
                      'Chọn ngày trong chuyến đi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          if (_selectedTrip != null && _selectedTrip!.days.isNotEmpty)
                            ..._selectedTrip!.days.map((d) {
                              final isSelected = _selectedDayNumber == d.dayNumber;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () => setState(() => _selectedDayNumber = d.dayNumber),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF047857) : const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Ngày ${d.dayNumber}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? Colors.white : const Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          InkWell(
                            onTap: () {
                              final nextDayNum = (_selectedTrip?.days.length ?? 0) + 1;
                              setState(() => _selectedDayNumber = nextDayNum);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFD1D5DB)),
                              ),
                              child: Text(
                                '+ Thêm ngày mới',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // New trip creation form
                    const Text(
                      'Tên chuyến đi mới',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newTripTitleController,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Khám phá Tây Nguyên 3N2Đ',
                        prefixIcon: const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF047857), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Time Selection Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Giờ ghé thăm',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _pickTime(isStart: true),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _startTime,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                    ),
                                    const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF6B7280)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Giờ rời đi',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _pickTime(isStart: false),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _endTime,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                    ),
                                    const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF6B7280)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Transport Mode & Estimated Cost
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phương tiện',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _transportMode,
                                  items: _transportModes.map((m) {
                                    return DropdownMenuItem<String>(
                                      value: m,
                                      child: Text(m, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _transportMode = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chi phí dự kiến',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _costController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Ví dụ: 50.000đ',
                                prefixIcon: const Icon(Icons.attach_money_rounded, size: 16, color: Color(0xFF047857)),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                                ),
                              ),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Note / Checklist item
                  const Text(
                    'Ghi chú / Hoạt động dự kiến',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Check-in chụp ảnh thác nước, mua vé tham quan và thưởng thức đặc sản...',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleSave,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                      label: Text(
                        _isSubmitting
                            ? 'Đang lưu vào lịch trình...'
                            : (_isCreatingNewTrip ? 'Tạo chuyến đi & Thêm điểm đến' : 'Thêm điểm đến vào chuyến đi'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF047857).withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

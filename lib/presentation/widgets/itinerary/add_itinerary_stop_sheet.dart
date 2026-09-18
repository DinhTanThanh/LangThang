import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';

class AddItineraryStopSheet extends StatefulWidget {
  final int dayNumber;
  final ValueChanged<ItineraryStopModel> onAddStop;

  const AddItineraryStopSheet({
    super.key,
    required this.dayNumber,
    required this.onAddStop,
  });

  static void show(
    BuildContext context, {
    required int dayNumber,
    required ValueChanged<ItineraryStopModel> onAddStop,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItineraryStopSheet(
        dayNumber: dayNumber,
        onAddStop: onAddStop,
      ),
    );
  }

  @override
  State<AddItineraryStopSheet> createState() => _AddItineraryStopSheetState();
}

class _AddItineraryStopSheetState extends State<AddItineraryStopSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tipsController = TextEditingController();

  String _startTime = '08:00';
  String _endTime = '09:30';
  String _category = 'Điểm tham quan';
  String _transportMode = 'Xe máy';

  final List<String> _categories = const [
    'Điểm tham quan',
    'Ẩm thực',
    'Check-in sống ảo',
    'Lưu trú',
    'Trải nghiệm văn hóa',
    'Mua sắm đặc sản',
  ];

  final List<String> _transports = const [
    'Xe máy',
    'Ô tô',
    'Đi bộ',
    'Taxi',
    'Tàu hỏa',
  ];

  @override
  void dispose() {
    _activityController.dispose();
    _locationController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
    _tipsController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final costText = _costController.text.trim();
    double costNum = 0;
    if (costText.isNotEmpty) {
      costNum = double.tryParse(costText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final newStop = ItineraryStopModel(
      id: 'custom-stop-${DateTime.now().microsecondsSinceEpoch}',
      time: _startTime,
      startTime: _startTime,
      endTime: _endTime,
      activity: _activityController.text.trim(),
      location: _locationController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      costEstimate: costNum > 0 ? '${costNum.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ' : 'Miễn phí',
      costEstimateNum: costNum,
      tips: _tipsController.text.trim().isNotEmpty ? _tipsController.text.trim() : null,
      transportMode: _transportMode,
      duration: '1.5 giờ',
    );

    widget.onAddStop(newStop);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_location_alt_rounded, color: Color(0xFF059669), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Thêm điểm dừng vào Ngày ${widget.dayNumber}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity Name
                    const Text('Tên địa điểm / Hoạt động *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _activityController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên địa điểm' : null,
                      decoration: InputDecoration(
                        hintText: 'VD: Check-in Cầu Rồng, Thưởng thức Phở Bát Đàn...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Location / Address
                    const Text('Địa chỉ / Khu vực *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _locationController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ' : null,
                      decoration: InputDecoration(
                        hintText: 'VD: 19 Trần Bình Trọng, Quận Hải Châu, Đà Nẵng',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF059669)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Time Range (Start & End)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Giờ bắt đầu', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: const TimeOfDay(hour: 8, minute: 0),
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _startTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_startTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF059669)),
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
                              const Text('Giờ kết thúc', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: const TimeOfDay(hour: 9, minute: 30),
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _endTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_endTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF059669)),
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

                    // Category & Transport
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Danh mục', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _category,
                                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _category = v);
                                },
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                              const Text('Phương tiện', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _transportMode,
                                items: _transports.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _transportMode = v);
                                },
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Cost Estimate
                    const Text('Chi phí dự kiến (VNĐ)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'VD: 150000 (để trống nếu miễn phí)',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF059669)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description / Note
                    const Text('Ghi chú hoạt động', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Mô tả ngắn về hoạt động trải nghiệm...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Local Tips
                    const Text('Mẹo thổ địa / Lưu ý đặc biệt', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _tipsController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'VD: Nên đặt bàn trước 1 ngày, đi giày thể thao...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFFD97706)),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Submit Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleSubmit,
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                label: const Text(
                  'Thêm điểm dừng vào lịch trình',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

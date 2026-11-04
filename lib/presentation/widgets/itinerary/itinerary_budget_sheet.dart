import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';

class ItineraryBudgetSheet extends StatefulWidget {
  final ItineraryModel itinerary;
  final ValueChanged<double>? onBudgetChanged;

  const ItineraryBudgetSheet({
    super.key,
    required this.itinerary,
    this.onBudgetChanged,
  });

  static void show(
    BuildContext context, {
    required ItineraryModel itinerary,
    ValueChanged<double>? onBudgetChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItineraryBudgetSheet(
        itinerary: itinerary,
        onBudgetChanged: onBudgetChanged,
      ),
    );
  }

  @override
  State<ItineraryBudgetSheet> createState() => _ItineraryBudgetSheetState();
}

class _ItineraryBudgetSheetState extends State<ItineraryBudgetSheet> {
  late double _budgetTarget;
  bool _isEditingBudget = false;
  late TextEditingController _customBudgetController;

  static const List<double> _budgetPresets = [
    3000000,
    5000000,
    8000000,
    10000000,
    15000000,
    20000000,
  ];

  @override
  void initState() {
    super.initState();
    final totalCost = widget.itinerary.calculatedTotalCost;
    _budgetTarget = widget.itinerary.budgetTarget ?? (totalCost > 0 ? totalCost * 1.15 : 5000000);
    _customBudgetController = TextEditingController(text: _budgetTarget.toInt().toString());
  }

  @override
  void dispose() {
    _customBudgetController.dispose();
    super.dispose();
  }

  void _applyBudget(double newBudget) {
    setState(() {
      _budgetTarget = newBudget;
      _isEditingBudget = false;
    });
    widget.onBudgetChanged?.call(newBudget);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã cập nhật mục tiêu ngân sách: ${(newBudget / 1000000).toStringAsFixed(1)} triệu đ!',
        ),
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itinerary = widget.itinerary;
    final totalCost = itinerary.calculatedTotalCost;
    final budgetTarget = _budgetTarget;
    final ratio = budgetTarget > 0 ? (totalCost / budgetTarget).clamp(0.0, 1.0) : 1.0;
    final percentUsed = budgetTarget > 0 ? ((totalCost / budgetTarget) * 100).round() : 0;
    final isOverBudget = totalCost > budgetTarget;

    // Calculate categories breakdown roughly
    double travelCost = 0;
    double foodCost = 0;
    double sightseeingCost = 0;
    double stayCost = 0;
    double otherCost = 0;

    for (var day in itinerary.days) {
      for (var stop in day.stops) {
        final cat = stop.category.toLowerCase();
        final cost = stop.costEstimateNum;
        if (cat.contains('ăn') || cat.contains('ẩm thực') || cat.contains('cà phê')) {
          foodCost += cost;
        } else if (cat.contains('lưu trú') || cat.contains('khách sạn') || cat.contains('resort')) {
          stayCost += cost;
        } else if (cat.contains('di chuyển') || cat.contains('vé tàu') || cat.contains('xe')) {
          travelCost += cost;
        } else if (cat.contains('tham quan') || cat.contains('di sản') || cat.contains('trải nghiệm') || cat.contains('cáp treo')) {
          sightseeingCost += cost;
        } else {
          otherCost += cost;
        }
      }
    }

    if (foodCost == 0 && sightseeingCost == 0 && totalCost > 0) {
      sightseeingCost = totalCost * 0.45;
      foodCost = totalCost * 0.35;
      travelCost = totalCost * 0.20;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  children: const [
                    Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Dự toán & Ngân sách Chuyến đi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
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

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Budget Target Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOverBudget
                            ? [const Color(0xFF991B1B), const Color(0xFFDC2626)]
                            : [const Color(0xFF064E3B), const Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isOverBudget ? const Color(0xFFDC2626) : const Color(0xFF047857)).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isOverBudget ? 'VƯỢT NGÂN SÁCH DỰ KIẾN' : 'TỔNG CHI PHÍ DỰ KIẾN',
                              style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$percentUsed% ngân sách',
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          totalCost > 0 ? '${totalCost.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ' : itinerary.estimatedCost,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(isOverBudget ? const Color(0xFFFCA5A5) : const Color(0xFF34D399)),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Đã lên chi tiết: ${itinerary.stopCount} điểm dừng',
                              style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 11),
                            ),
                            Text(
                              'Mục tiêu: ${budgetTarget.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ',
                              style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Preset Budget Selector matching Share_Locations
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Chọn mức ngân sách dự kiến',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() => _isEditingBudget = !_isEditingBudget);
                              },
                              child: Text(
                                _isEditingBudget ? 'Đóng nhập tay' : 'Nhập số tiền khác',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Preset buttons (3tr, 5tr, 8tr, 10tr, 15tr, 20tr)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _budgetPresets.map((preset) {
                            final isSelected = (_budgetTarget - preset).abs() < 1000;
                            final label = '${(preset / 1000000).toInt()} triệu';
                            return InkWell(
                              onTap: () => _applyBudget(preset),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF065F46) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF065F46) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        if (_isEditingBudget) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customBudgetController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Mục tiêu ngân sách (VNĐ)',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  final cleanText = _customBudgetController.text.replaceAll(RegExp(r'\D'), '');
                                  final parsed = double.tryParse(cleanText) ?? 5000000;
                                  _applyBudget(parsed);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF065F46),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                ),
                                child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Category Breakdown Section
                  const Text(
                    'Phân bổ chi phí theo danh mục',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 10),

                  _buildCategoryRow('Vé tham quan & Trải nghiệm', sightseeingCost, Icons.confirmation_number_outlined, const Color(0xFF10B981)),
                  _buildCategoryRow('Ăn uống & Đặc sản', foodCost, Icons.restaurant_rounded, const Color(0xFFF59E0B)),
                  _buildCategoryRow('Di chuyển & Xăng xe', travelCost, Icons.directions_bike_rounded, const Color(0xFF3B82F6)),
                  if (stayCost > 0)
                    _buildCategoryRow('Lưu trú & Khách sạn', stayCost, Icons.hotel_rounded, const Color(0xFF8B5CF6)),
                  if (otherCost > 0)
                    _buildCategoryRow('Chi phí phát sinh / Khác', otherCost, Icons.more_horiz_rounded, const Color(0xFF6B7280)),

                  const SizedBox(height: 20),

                  // Cost by Day
                  const Text(
                    'Chi phí theo từng ngày',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 10),

                  ...itinerary.days.map((day) {
                    final dayTotal = day.stops.fold(0.0, (acc, s) => acc + s.costEstimateNum);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF059669),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      day.dayNumber.toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Ngày ${day.dayNumber}: ${day.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dayTotal > 0
                                ? '${dayTotal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ'
                                : 'Linh hoạt',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String title, double cost, IconData icon, Color color) {
    final costText = cost > 0
        ? '${cost.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ'
        : 'Tự túc';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            costText,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }
}

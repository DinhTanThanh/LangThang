import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../screens/profile/user_profile_screen.dart';

class ItineraryQuickPreviewModal extends StatefulWidget {
  final ItineraryModel itinerary;
  final VoidCallback onApply;

  const ItineraryQuickPreviewModal({
    super.key,
    required this.itinerary,
    required this.onApply,
  });

  static void show(
    BuildContext context, {
    required ItineraryModel itinerary,
    required VoidCallback onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItineraryQuickPreviewModal(
        itinerary: itinerary,
        onApply: onApply,
      ),
    );
  }

  @override
  State<ItineraryQuickPreviewModal> createState() =>
      _ItineraryQuickPreviewModalState();
}

class _ItineraryQuickPreviewModalState extends State<ItineraryQuickPreviewModal> {
  final Set<int> _expandedDays = {1};

  @override
  void initState() {
    super.initState();
    // Default open all days if 3 or fewer days
    if (widget.itinerary.days.length <= 3) {
      _expandedDays.addAll(widget.itinerary.days.map((d) => d.dayNumber));
    }
  }

  @override
  Widget build(BuildContext context) {
    final itinerary = widget.itinerary;
    final totalStops = itinerary.stopCount;
    final authorInitial = itinerary.authorName.isNotEmpty
        ? itinerary.authorName[0].toUpperCase()
        : 'C';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Drag Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header: Author on left, Estimated Budget & Close button on right
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Author Profile
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      UserProfileScreen.navigate(
                        context,
                        userId: itinerary.id % 10 + 1,
                        userName: itinerary.authorName.isNotEmpty ? itinerary.authorName : 'Tác giả',
                        userAvatar: itinerary.authorAvatar.isNotEmpty ? itinerary.authorAvatar : null,
                        userRank: itinerary.author.rank.isNotEmpty ? itinerary.author.rank : 'Thổ địa',
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        if (itinerary.authorAvatar.isNotEmpty)
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: const Color(0xFFE2E8F0),
                            backgroundImage: NetworkImage(itinerary.authorAvatar),
                          )
                        else
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: const Color(0xFF064E3B),
                            child: Text(
                              authorInitial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      itinerary.authorName.isNotEmpty
                                          ? itinerary.authorName
                                          : 'Cộng đồng',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Color(0xFF10B981),
                                  ),
                                ],
                              ),
                              Text(
                                itinerary.author.rank,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Budget & Close
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'DỰ TOÁN TRỌN GÓI',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          itinerary.estimatedCost.isNotEmpty
                              ? itinerary.estimatedCost
                              : 'Linh hoạt',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF064E3B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    itinerary.title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Overview / Summary Section
                  const Text(
                    'TÓM TẮT LỊCH TRÌNH',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    itinerary.overview != null && itinerary.overview!.isNotEmpty
                        ? itinerary.overview!
                        : 'Lịch trình du lịch đề xuất tối ưu thời gian và chi phí, kèm điểm tham quan và ẩm thực đặc trưng.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),

                  // Tags
                  if (itinerary.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: itinerary.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Timeline Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.explore_rounded,
                            color: Color(0xFF065F46),
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LỘ TRÌNH ${itinerary.days.length} NGÀY ($totalStops ĐIỂM DỪNG)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      if (itinerary.destination.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: Color(0xFF065F46),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              itinerary.destination,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Days List
                  if (itinerary.days.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text(
                          'Chưa có điểm dừng nào được chỉ định.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    ...itinerary.days.map((day) {
                      final isExpanded = _expandedDays.contains(day.dayNumber);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isExpanded
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Day Header Toggle
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedDays.remove(day.dayNumber);
                                  } else {
                                    _expandedDays.add(day.dayNumber);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Ngày ${day.dayNumber}: ${day.title.replaceAll(RegExp(r'^Ngày\s*\d+\s*:\s*', caseSensitive: false), '').trim()}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          '${day.stops.length} địa điểm',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Stops list
                            if (isExpanded) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              if (day.stops.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Chưa có điểm dừng cho ngày này.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF94A3B8),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: day.stops.asMap().entries.map((entry) {
                                      final sIdx = entry.key;
                                      final stop = entry.value;

                                      return Container(
                                        margin: EdgeInsets.only(
                                            bottom: sIdx < day.stops.length - 1
                                                ? 8
                                                : 0),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          children: [
                                            // Sequence Circle
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD1FAE5),
                                                borderRadius:
                                                    BorderRadius.circular(6),
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
                                            const SizedBox(width: 10),

                                            // Stop Information
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    stop.activity,
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${stop.time.isNotEmpty ? stop.time : stop.startTime} • ${stop.category}${stop.location.isNotEmpty ? ' • ${stop.location}' : ''}',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            // Cost Estimate
                                            Text(
                                              stop.costEstimateNum > 0
                                                  ? '${stop.costEstimateNum.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ'
                                                  : (stop.costEstimate != null &&
                                                          stop.costEstimate!
                                                              .isNotEmpty
                                                      ? stop.costEstimate!
                                                      : 'Miễn phí'),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF065F46),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                // Đóng
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF334155),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Áp dụng chuyến đi này
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onApply();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Áp dụng chuyến đi này',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065F46),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

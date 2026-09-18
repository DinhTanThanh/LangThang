import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';

class ItineraryQuickPreviewModal extends StatefulWidget {
  final ItineraryModel itinerary;
  final VoidCallback onApply;

  const ItineraryQuickPreviewModal({
    super.key,
    required this.itinerary,
    required this.onApply,
  });

  static void show(BuildContext context, {required ItineraryModel itinerary, required VoidCallback onApply}) {
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
  State<ItineraryQuickPreviewModal> createState() => _ItineraryQuickPreviewModalState();
}

class _ItineraryQuickPreviewModalState extends State<ItineraryQuickPreviewModal> {
  final Set<int> _expandedDays = {1};

  @override
  Widget build(BuildContext context) {
    final itinerary = widget.itinerary;

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
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Modal Header with Cover
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(itinerary.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),

              // Close Button
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),

              // Title & Author on Cover
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF047857),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            itinerary.duration,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            itinerary.destination,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      itinerary.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author & Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF059669),
                            backgroundImage: itinerary.authorAvatar.isNotEmpty
                                ? NetworkImage(itinerary.authorAvatar)
                                : null,
                            child: itinerary.authorAvatar.isEmpty
                                ? Text(
                                    itinerary.authorName.isNotEmpty ? itinerary.authorName[0].toUpperCase() : 'L',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itinerary.authorName,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                              ),
                              Text(
                                itinerary.author.rank,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              itinerary.estimatedCost,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Overview Text
                  if (itinerary.overview != null && itinerary.overview!.isNotEmpty) ...[
                    Text(
                      itinerary.overview!,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563), height: 1.5),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Quick Stats Grid
                  Row(
                    children: [
                      _buildStatBox(Icons.calendar_today_rounded, '${itinerary.daysCount} Ngày', 'Thời lượng'),
                      const SizedBox(width: 8),
                      _buildStatBox(Icons.pin_drop_rounded, '${itinerary.stopCount} Điểm', 'Điểm dừng'),
                      const SizedBox(width: 8),
                      _buildStatBox(Icons.star_rounded, '${itinerary.rating} ★', '${itinerary.reviewCount} đánh giá'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Day-by-Day Timeline Preview Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lộ trình chi tiết từng ngày',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_expandedDays.length == itinerary.days.length) {
                              _expandedDays.clear();
                            } else {
                              _expandedDays.addAll(itinerary.days.map((d) => d.dayNumber));
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _expandedDays.length == itinerary.days.length ? 'Thu gọn tất cả' : 'Mở rộng tất cả',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Days Accordion List
                  ...itinerary.days.map((day) {
                    final isExpanded = _expandedDays.contains(day.dayNumber);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isExpanded ? const Color(0xFF10B981) : const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
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
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isExpanded ? const Color(0xFF059669) : const Color(0xFFF3F4F6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        day.dayNumber.toString(),
                                        style: TextStyle(
                                          color: isExpanded ? Colors.white : const Color(0xFF374151),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Ngày ${day.dayNumber}: ${day.title}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isExpanded ? const Color(0xFF065F46) : const Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${day.stops.length} điểm',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (isExpanded) ...[
                            const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: day.stops.map((stop) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD1FAE5),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            stop.time,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stop.activity,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                              ),
                                              Text(
                                                stop.location,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (stop.costEstimate != null && stop.costEstimate!.isNotEmpty)
                                          Text(
                                            stop.costEstimate!,
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onApply();
                    },
                    icon: const Icon(Icons.explore_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Xem chi tiết & Lên kế hoạch',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF059669)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

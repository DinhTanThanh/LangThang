import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';

class ItineraryWishlistSheet extends StatelessWidget {
  final List<ItineraryStopModel> backlogStops;
  final List<ItineraryDayModel> days;
  final Function(ItineraryStopModel stop, int targetDayNumber) onAddStopToDay;

  const ItineraryWishlistSheet({
    super.key,
    required this.backlogStops,
    required this.days,
    required this.onAddStopToDay,
  });

  static void show(
    BuildContext context, {
    required List<ItineraryStopModel> backlogStops,
    required List<ItineraryDayModel> days,
    required Function(ItineraryStopModel stop, int targetDayNumber) onAddStopToDay,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItineraryWishlistSheet(
        backlogStops: backlogStops,
        days: days,
        onAddStopToDay: onAddStopToDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                    Icon(Icons.bookmark_added_rounded, color: Color(0xFF059669), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Điểm đến dự phòng (Wishlist)',
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
            child: backlogStops.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.favorite_border_rounded, size: 40, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 10),
                          Text(
                            'Chưa có điểm dự phòng nào.',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Các địa điểm chưa kịp ghé thăm có thể lưu tại đây.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: backlogStops.map((stop) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      stop.activity,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                    ),
                                  ),
                                  if (stop.costEstimate != null && stop.costEstimate!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD1FAE5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        stop.costEstimate!,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                                      ),
                                    ),
                                ],
                              ),
                              if (stop.location.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF059669)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        stop.location,
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (stop.description != null && stop.description!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  stop.description!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Add to Day Action Buttons
                              Row(
                                children: [
                                  const Text(
                                    'Thêm vào:',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: days.map((d) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: InkWell(
                                              onTap: () {
                                                Navigator.pop(context);
                                                onAddStopToDay(stop, d.dayNumber);
                                              },
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF059669),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Ngày ${d.dayNumber}',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

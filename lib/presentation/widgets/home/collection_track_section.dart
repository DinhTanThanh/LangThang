import 'package:flutter/material.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/models/place_model.dart';
import 'place_card_in_collection.dart';

class CollectionTrackSection extends StatefulWidget {
  final CollectionDto collection;
  final Function(PlaceModel place)? onPlaceTap;

  const CollectionTrackSection({
    super.key,
    required this.collection,
    this.onPlaceTap,
  });

  @override
  State<CollectionTrackSection> createState() => _CollectionTrackSectionState();
}

class _CollectionTrackSectionState extends State<CollectionTrackSection> {
  final ScrollController _scrollController = ScrollController();

  void _scroll(int direction) {
    const scrollAmount = 280.0;
    final targetOffset = (_scrollController.offset + direction * scrollAmount)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMatchBadge(String label, String? reason) {
    Color textColor = const Color(0xFF475569);
    Color bgColor = const Color(0xFFF8FAFC);
    Color borderColor = const Color(0xFFE2E8F0);

    final r = reason?.toLowerCase() ?? '';
    if (r == 'near') {
      textColor = const Color(0xFF047857);
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFFA7F3D0);
    } else if (r == 'intent') {
      textColor = const Color(0xFF0369A1);
      bgColor = const Color(0xFFF0F9FF);
      borderColor = const Color(0xFFBAE6FD);
    } else if (r == 'category') {
      textColor = const Color(0xFFB45309);
      bgColor = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.collection.places;
    if (places.isEmpty) return const SizedBox.shrink();

    final matchLabel = widget.collection.matchLabel;
    final matchReason = widget.collection.matchReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with collection title and scroll buttons (Matching HomeFeaturedInterleaved.tsx)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (matchLabel != null && matchLabel.isNotEmpty)
                      _buildMatchBadge(matchLabel, matchReason),
                    Text(
                      widget.collection.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (widget.collection.description != null &&
                        widget.collection.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.collection.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Prev & Next navigation buttons
              Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _scroll(-1),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 15,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _scroll(1),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal List of Place Cards in Collection
        SizedBox(
          height: 365,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: places.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final place = places[index];
              return PlaceCardInCollection(
                place: place,
                onTap: () => widget.onPlaceTap?.call(place),
              );
            },
          ),
        ),
      ],
    );
  }
}

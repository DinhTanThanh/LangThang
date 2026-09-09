import 'package:flutter/material.dart';
import '../../data/models/place_model.dart';

class PlaceCardList extends StatefulWidget {
  final PlaceModel place;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleSave;

  const PlaceCardList({
    super.key,
    required this.place,
    this.onTap,
    this.onToggleSave,
  });

  @override
  State<PlaceCardList> createState() => _PlaceCardListState();
}

class _PlaceCardListState extends State<PlaceCardList> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.place.isSaved;
  }

  @override
  void didUpdateWidget(covariant PlaceCardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.isSaved != widget.place.isSaved) {
      _isSaved = widget.place.isSaved;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationText = widget.place.province.isNotEmpty
        ? (widget.place.region.isNotEmpty && widget.place.region != widget.place.province
            ? '${widget.place.province}, ${widget.place.region}'
            : widget.place.province)
        : (widget.place.location.isNotEmpty ? widget.place.location : 'Việt Nam');

    final tags = [
      widget.place.category,
      widget.place.type,
      widget.place.province,
    ].where((s) => s.trim().isNotEmpty).take(3).toList();

    final priceDisplay = widget.place.price.trim().isNotEmpty
        ? widget.place.price
        : 'Miễn phí';

    final hoursDisplay = widget.place.hours.trim().isNotEmpty
        ? widget.place.hours
        : '08:00 – 17:00';

    final descText = widget.place.desc.trim().isNotEmpty
        ? widget.place.desc
        : widget.place.location;

    final categoryBadge = widget.place.category.trim().isNotEmpty
        ? widget.place.category
        : (widget.place.type.trim().isNotEmpty ? widget.place.type : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Image (Thumbnail with Category Badge)
                SizedBox(
                  width: 108,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.place.img,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(
                            Icons.location_on_outlined,
                            size: 28,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      if (categoryBadge.isNotEmpty)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              categoryBadge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Right Content Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Location, Rating, Save Button
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 11.5,
                                        color: Color(0xFF047857),
                                      ),
                                      const SizedBox(width: 2.5),
                                      Expanded(
                                        child: Text(
                                          locationText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 1.5),
                                    Text(
                                      widget.place.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      ' (${widget.place.reviews})',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.normal,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _isSaved = !_isSaved);
                                    widget.onToggleSave?.call(_isSaved);
                                  },
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: _isSaved
                                          ? const Color(0xFFF43F5E)
                                          : const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isSaved ? Icons.favorite : Icons.favorite_border,
                                      color: _isSaved ? Colors.white : const Color(0xFF64748B),
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),

                            // Place Name
                            Text(
                              widget.place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),

                            // Description
                            if (descText.isNotEmpty)
                              Text(
                                descText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.normal,
                                  color: Color(0xFF64748B),
                                  height: 1.25,
                                ),
                              ),

                            // Tags
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 3,
                                runSpacing: 3,
                                children: tags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),

                        // Footer: Divider + Clock / Hours + Price
                        Column(
                          children: [
                            const SizedBox(height: 6),
                            const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          hoursDisplay,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.normal,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  priceDisplay,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/place_model.dart';

class PlaceCardGrid extends StatefulWidget {
  final PlaceModel place;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleSave;

  const PlaceCardGrid({
    super.key,
    required this.place,
    this.onTap,
    this.onToggleSave,
  });

  @override
  State<PlaceCardGrid> createState() => _PlaceCardGridState();
}

class _PlaceCardGridState extends State<PlaceCardGrid> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.place.isSaved;
  }

  @override
  void didUpdateWidget(covariant PlaceCardGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.isSaved != widget.place.isSaved) {
      _isSaved = widget.place.isSaved;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.place.status == 'Đang mở' || widget.place.status == 'Đang hoạt động';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section (Aspect Ratio 16/10)
              AspectRatio(
                aspectRatio: 1.6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      widget.place.img,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.photo_outlined, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    // Top Left Badges (Category + Status)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 48,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          if (widget.place.category.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.place.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? const Color(0xFF059669).withValues(alpha: 0.9)
                                  : const Color(0xFFE11D48).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isOpen ? 'Đang mở' : 'Tạm đóng',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Floating Heart Button on Top Right
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _isSaved = !_isSaved);
                          widget.onToggleSave?.call(_isSaved);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _isSaved ? const Color(0xFFF43F5E) : Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isSaved ? Icons.favorite : Icons.favorite_border,
                            color: _isSaved ? Colors.white : const Color(0xFF475569),
                            size: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Details Body
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
                          // Location & Rating Row
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  widget.place.province.isNotEmpty
                                      ? '${widget.place.province}, ${widget.place.region}'
                                      : widget.place.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, size: 12, color: Color(0xFFFBBF24)),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.place.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    ' (${widget.place.reviews})',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Place Title
                          Text(
                            widget.place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),

                          // Description
                          Text(
                            widget.place.desc.isNotEmpty ? widget.place.desc : widget.place.location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Tags
                          if (widget.place.tags.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: widget.place.tags.take(3).map((t) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      '#$t',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),

                      // Bottom opening hours & Price
                      Container(
                        padding: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time, size: 11, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      widget.place.hours.isNotEmpty ? widget.place.hours : '08:00 – 17:00',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.place.price,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

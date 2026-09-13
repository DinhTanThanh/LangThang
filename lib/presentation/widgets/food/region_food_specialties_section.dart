import 'package:flutter/material.dart';
import '../../../data/models/food_model.dart';
import 'food_specialty_card.dart';

class RegionFoodSpecialtiesSection extends StatefulWidget {
  final String regionName;
  final List<FoodModel> foods;
  final Function(FoodModel food)? onFoodTap;
  final Function(FoodSuggestedPlace place)? onPlaceTap;

  const RegionFoodSpecialtiesSection({
    super.key,
    required this.regionName,
    required this.foods,
    this.onFoodTap,
    this.onPlaceTap,
  });

  @override
  State<RegionFoodSpecialtiesSection> createState() => _RegionFoodSpecialtiesSectionState();
}

class _RegionFoodSpecialtiesSectionState extends State<RegionFoodSpecialtiesSection> {
  final ScrollController _scrollController = ScrollController();

  void _scroll(int direction) {
    const scrollAmount = 310.0;
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

  @override
  Widget build(BuildContext context) {
    if (widget.foods.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header (Matching RegionFoodSpecialties.tsx)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tinh Hoa Ẩm Thực ${widget.regionName}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.foods.length} món ngon đặc sản & quán ăn nức tiếng',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // Left & Right Scroll Buttons
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
                              color: Colors.black.withValues(alpha: 0.04),
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
                              color: Colors.black.withValues(alpha: 0.04),
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

        // Horizontal List of FoodSpecialtyCards
        SizedBox(
          height: 590,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: widget.foods.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final food = widget.foods[index];
              return FoodSpecialtyCard(
                food: food,
                regionName: widget.regionName,
                onTap: () => widget.onFoodTap?.call(food),
                onPlaceTap: widget.onPlaceTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

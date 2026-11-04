import 'package:flutter/material.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/place_api_service.dart';
import '../../screens/destinations/place_detail_screen.dart';
import '../place_card_grid.dart';
import '../place_card_list.dart';

class ProvincePlaceSection extends StatefulWidget {
  final List<PlaceModel> places;
  final String provinceName;
  final List<LookupItemDto> categories;
  final int? selectedCategoryId;
  final Function(int? categoryId)? onSelectCategory;
  final String sortBy;
  final Function(String sort)? onSortChange;
  final bool loading;

  const ProvincePlaceSection({
    super.key,
    required this.places,
    required this.provinceName,
    required this.categories,
    this.selectedCategoryId,
    this.onSelectCategory,
    this.sortBy = 'rating',
    this.onSortChange,
    this.loading = false,
  });

  @override
  State<ProvincePlaceSection> createState() => _ProvincePlaceSectionState();
}

class _ProvincePlaceSectionState extends State<ProvincePlaceSection> {
  final bool _isGrid = true;
  int _visibleCount = 12;

  @override
  void didUpdateWidget(covariant ProvincePlaceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId ||
        oldWidget.sortBy != widget.sortBy ||
        oldWidget.provinceName != widget.provinceName) {
      setState(() {
        _visibleCount = 12;
      });
    }
  }

  void _handleLoadMore() {
    setState(() {
      _visibleCount += 12;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayedPlaces = widget.places.take(_visibleCount).toList();
    final hasMore = widget.places.length > _visibleCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header with Title & Sort / ViewMode controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Địa Điểm Nổi Bật Tại ${widget.provinceName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sort dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.sortBy,
                        isDense: true,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                        items: const [
                          DropdownMenuItem(value: 'rating', child: Text('Đánh giá cao nhất')),
                          DropdownMenuItem(value: 'price_asc', child: Text('Giá: Thấp đến cao')),
                          DropdownMenuItem(value: 'price_desc', child: Text('Giá: Cao đến thấp')),
                        ],
                        onChanged: (val) {
                          if (val != null) widget.onSortChange?.call(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Categories Horizontal Filter Pills
        if (widget.categories.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.categories.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = widget.selectedCategoryId == null;
                  return _buildCategoryChip(
                    label: 'Tất cả danh mục',
                    isSelected: isSelected,
                    onTap: () => widget.onSelectCategory?.call(null),
                  );
                }
                final cat = widget.categories[index - 1];
                final isSelected = widget.selectedCategoryId == cat.id;
                return _buildCategoryChip(
                  label: cat.name,
                  isSelected: isSelected,
                  onTap: () => widget.onSelectCategory?.call(isSelected ? null : cat.id),
                );
              },
            ),
          ),
        const SizedBox(height: 12),

        // 3. Places content
        if (widget.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF004F32),
              ),
            ),
          )
        else if (widget.places.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_off_outlined, color: Color(0xFF94A3B8), size: 24),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chưa có địa điểm nào phù hợp',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Không tìm thấy địa điểm phù hợp với bộ lọc hiện tại ở ${widget.provinceName}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => widget.onSelectCategory?.call(null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Đặt lại bộ lọc', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        else if (_isGrid)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: displayedPlaces.length,
              itemBuilder: (context, index) {
                final place = displayedPlaces[index];
                return PlaceCardGrid(
                  place: place,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaceDetailScreen(place: place),
                      ),
                    );
                  },
                  onToggleSave: (saved) {
                    if (saved) {
                      PlaceApiService().savePlace(place.id, place: place);
                    } else {
                      PlaceApiService().unsavePlace(place.id);
                    }
                  },
                );
              },
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayedPlaces.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final place = displayedPlaces[index];
              return PlaceCardList(
                place: place,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaceDetailScreen(place: place),
                    ),
                  );
                },
                onToggleSave: (saved) {
                  if (saved) {
                    PlaceApiService().savePlace(place.id, place: place);
                  } else {
                    PlaceApiService().unsavePlace(place.id);
                  }
                },
              );
            },
          ),

        // 4. Load more button (Batch 12)
        if (hasMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _handleLoadMore,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF004F32)),
                label: Text(
                  'Xem thêm địa điểm (${displayedPlaces.length}/${widget.places.length})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF004F32) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF004F32) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF004F32).withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

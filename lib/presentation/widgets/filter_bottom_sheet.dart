import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/place_filter_dto.dart';

class FilterCriteria {
  int? categoryId;
  String? category;
  List<int> regionIds;
  List<String> regions;
  List<int> provinceIds;
  List<String> provinces;
  int priceTier; // 0: Tất cả, 1: Miễn phí, 2: <100k, 3: 100k-500k, 4: >500k
  double minRating; // 0, 3.5, 4.0, 4.5

  FilterCriteria({
    this.categoryId,
    this.category,
    List<int>? regionIds,
    List<String>? regions,
    List<int>? provinceIds,
    List<String>? provinces,
    this.priceTier = 0,
    this.minRating = 0,
  })  : regionIds = regionIds ?? [],
        regions = regions ?? [],
        provinceIds = provinceIds ?? [],
        provinces = provinces ?? [];

  FilterCriteria copyWith({
    int? categoryId,
    String? category,
    bool clearCategory = false,
    List<int>? regionIds,
    List<String>? regions,
    List<int>? provinceIds,
    List<String>? provinces,
    int? priceTier,
    double? minRating,
  }) {
    return FilterCriteria(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      category: clearCategory ? null : (category ?? this.category),
      regionIds: regionIds ?? List.from(this.regionIds),
      regions: regions ?? List.from(this.regions),
      provinceIds: provinceIds ?? List.from(this.provinceIds),
      provinces: provinces ?? List.from(this.provinces),
      priceTier: priceTier ?? this.priceTier,
      minRating: minRating ?? this.minRating,
    );
  }

  int get activeCount {
    int count = 0;
    if (category != null && category!.isNotEmpty && category != 'Tất cả danh mục') count++;
    count += regions.length;
    count += provinces.length;
    if (priceTier > 0) count++;
    if (minRating > 0) count++;
    return count;
  }

  void reset() {
    categoryId = null;
    category = null;
    regionIds.clear();
    regions.clear();
    provinceIds.clear();
    provinces.clear();
    priceTier = 0;
    minRating = 0;
  }
}

class FilterBottomSheet extends StatefulWidget {
  final FilterCriteria initialCriteria;
  final PlaceFilterOptionsDto? filterOptions;
  final ValueChanged<FilterCriteria> onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialCriteria,
    this.filterOptions,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late FilterCriteria _criteria;
  final Map<String, bool> _openAccordions = {
    'Miền Bắc': true,
    'Miền Trung': false,
    'Miền Nam': false,
  };

  late List<LookupItemDto> _categories;
  late List<RegionLookupDto> _regions;

  final List<Map<String, dynamic>> _priceTiers = [
    {'label': 'Tất cả mức giá', 'min': 0, 'max': 0},
    {'label': 'Miễn phí', 'min': 0, 'max': 0, 'exactFree': true},
    {'label': 'Tiết kiệm (< 100k)', 'min': 1, 'max': 100000},
    {'label': 'Vừa phải (100k - 500k)', 'min': 100000, 'max': 500000},
    {'label': 'Cao cấp (> 500k)', 'min': 500000, 'max': 50000000},
  ];

  @override
  void initState() {
    super.initState();
    _criteria = widget.initialCriteria.copyWith();

    if (widget.filterOptions != null && widget.filterOptions!.categories.isNotEmpty) {
      _categories = [
        const LookupItemDto(id: 0, name: 'Tất cả danh mục'),
        ...widget.filterOptions!.categories,
      ];
      _regions = widget.filterOptions!.regions;
    } else {
      _categories = const [
        LookupItemDto(id: 0, name: 'Tất cả danh mục'),
        LookupItemDto(id: 1, name: 'Thiên nhiên & Cảnh quan'),
        LookupItemDto(id: 2, name: 'Di tích & Lịch sử'),
        LookupItemDto(id: 3, name: 'Ẩm thực & Cafe'),
        LookupItemDto(id: 4, name: 'Vui chơi & Giải trí'),
        LookupItemDto(id: 5, name: 'Văn hóa & Nghệ thuật'),
        LookupItemDto(id: 6, name: 'Nghỉ dưỡng & Resort'),
      ];
      _regions = const [
        RegionLookupDto(
          id: 1,
          name: 'Miền Bắc',
          provinces: [
            LookupItemDto(id: 1, name: 'Hà Nội'),
            LookupItemDto(id: 2, name: 'Hải Phòng'),
            LookupItemDto(id: 3, name: 'Quảng Ninh'),
            LookupItemDto(id: 4, name: 'Ninh Bình'),
            LookupItemDto(id: 5, name: 'Lào Cai / Sa Pa'),
            LookupItemDto(id: 6, name: 'Hà Giang'),
            LookupItemDto(id: 7, name: 'Cao Bằng'),
          ],
        ),
        RegionLookupDto(
          id: 2,
          name: 'Miền Trung',
          provinces: [
            LookupItemDto(id: 8, name: 'Đà Nẵng'),
            LookupItemDto(id: 9, name: 'Thừa Thiên Huế'),
            LookupItemDto(id: 10, name: 'Quảng Nam / Hội An'),
            LookupItemDto(id: 11, name: 'Khánh Hòa / Nha Trang'),
            LookupItemDto(id: 12, name: 'Lâm Đồng / Đà Lạt'),
            LookupItemDto(id: 13, name: 'Bình Định / Quy Nhơn'),
            LookupItemDto(id: 14, name: 'Quảng Bình'),
          ],
        ),
        RegionLookupDto(
          id: 3,
          name: 'Miền Nam',
          provinces: [
            LookupItemDto(id: 15, name: 'TP. Hồ Chí Minh'),
            LookupItemDto(id: 16, name: 'Kiên Giang / Phú Quốc'),
            LookupItemDto(id: 17, name: 'Bà Rịa - Vũng Tàu'),
            LookupItemDto(id: 18, name: 'Cần Thơ'),
            LookupItemDto(id: 19, name: 'Tây Ninh'),
            LookupItemDto(id: 20, name: 'An Giang'),
          ],
        ),
      ];
    }
  }

  void _toggleRegion(RegionLookupDto region) {
    setState(() {
      if (_criteria.regionIds.contains(region.id) || _criteria.regions.contains(region.name)) {
        _criteria.regionIds.remove(region.id);
        _criteria.regions.remove(region.name);
        // Also remove all provinces in this region
        final provIds = region.provinces.map((p) => p.id).toList();
        final provNames = region.provinces.map((p) => p.name).toList();
        _criteria.provinceIds.removeWhere((id) => provIds.contains(id));
        _criteria.provinces.removeWhere((name) => provNames.contains(name));
      } else {
        _criteria.regionIds.add(region.id);
        _criteria.regions.add(region.name);
      }
    });
  }

  void _toggleProvince(LookupItemDto province) {
    setState(() {
      if (_criteria.provinceIds.contains(province.id) || _criteria.provinces.contains(province.name)) {
        _criteria.provinceIds.remove(province.id);
        _criteria.provinces.remove(province.name);
      } else {
        _criteria.provinceIds.add(province.id);
        _criteria.provinces.add(province.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune, size: 18, color: Color(0xFF047857)),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Bộ lọc tìm kiếm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (_criteria.activeCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_criteria.activeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Filter Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. DANH MỤC TRẢI NGHIỆM
                  _buildSectionHeader('DANH MỤC TRẢI NGHIỆM'),
                  const SizedBox(height: 10),
                  ..._categories.map((cat) {
                    final isSelected = (_criteria.category == null && (cat.id == 0 || cat.name == 'Tất cả danh mục')) ||
                        (_criteria.categoryId != null && _criteria.categoryId == cat.id) ||
                        (_criteria.category == cat.name);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (cat.id == 0 || cat.name == 'Tất cả danh mục') {
                            _criteria.categoryId = null;
                            _criteria.category = null;
                          } else {
                            _criteria.categoryId = cat.id;
                            _criteria.category = cat.name;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFA7F3D0) : const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF065F46) : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // 2. VÙNG MIỀN & TỈNH THÀNH
                  _buildSectionHeader('VÙNG MIỀN & TỈNH THÀNH'),
                  const SizedBox(height: 10),
                  ..._regions.map((region) {
                    final isRegionChecked = _criteria.regionIds.contains(region.id) ||
                        _criteria.regions.contains(region.name);
                    final isAccordionOpen = _openAccordions[region.name] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isRegionChecked,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  onChanged: (_) => _toggleRegion(region),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _toggleRegion(region),
                                    child: Text(
                                      region.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isAccordionOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: const Color(0xFF64748B),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _openAccordions[region.name] = !isAccordionOpen;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (isAccordionOpen)
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: region.provinces.map((prov) {
                                  final isProvSelected = _criteria.provinceIds.contains(prov.id) ||
                                      _criteria.provinces.contains(prov.name);
                                  return FilterChip(
                                    selected: isProvSelected,
                                    label: Text(
                                      prov.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isProvSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isProvSelected ? const Color(0xFF065F46) : const Color(0xFF475569),
                                      ),
                                    ),
                                    backgroundColor: Colors.white,
                                    selectedColor: const Color(0xFFD1FAE5),
                                    checkmarkColor: const Color(0xFF047857),
                                    side: BorderSide(
                                      color: isProvSelected ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0),
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    onSelected: (_) => _toggleProvince(prov),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // 3. KHOẢNG GIÁ & NGÂN SÁCH
                  _buildSectionHeader('KHOẢNG GIÁ & NGÂN SÁCH'),
                  const SizedBox(height: 10),
                  ..._priceTiers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final tier = entry.value;
                    final isSelected = _criteria.priceTier == idx;

                    return InkWell(
                      onTap: () {
                        setState(() => _criteria.priceTier = idx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFA7F3D0) : const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              tier['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF065F46) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // 4. ĐÁNH GIÁ TỐI THIỂU
                  _buildSectionHeader('ĐÁNH GIÁ TỐI THIỂU'),
                  const SizedBox(height: 10),
                  Row(
                    children: [0.0, 4.5, 4.0, 3.5].map((rating) {
                      final isSelected = _criteria.minRating == rating;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () {
                              setState(() => _criteria.minRating = rating);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (rating > 0) ...[
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color: isSelected ? Colors.white : const Color(0xFFFBBF24),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$rating+',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ] else
                                    Text(
                                      'Tất cả',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Footer Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _criteria.reset());
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'Thiết lập lại',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      widget.onApply(_criteria);
                      Navigator.pop(context);
                    },
                    child: Text(
                      _criteria.activeCount > 0
                          ? 'Áp dụng (${_criteria.activeCount})'
                          : 'Áp dụng bộ lọc',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.5,
      ),
    );
  }
}

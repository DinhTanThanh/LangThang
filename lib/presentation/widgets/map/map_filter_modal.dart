import 'package:flutter/material.dart';
import '../../../data/models/place_filter_dto.dart';

/// Modal bottom sheet for map filters matching Share_Locations MapFilterSidebar.tsx
class MapFilterModal extends StatefulWidget {
  final int selectedCategoryId;
  final int selectedProvinceId;
  final List<LookupItemDto> categories;
  final List<RegionLookupDto> regions;
  final Function(int categoryId, int provinceId) onApply;
  final VoidCallback? onReset;

  const MapFilterModal({
    super.key,
    required this.selectedCategoryId,
    required this.selectedProvinceId,
    required this.categories,
    required this.regions,
    required this.onApply,
    this.onReset,
  });

  static Future<void> show(
    BuildContext context, {
    required int selectedCategoryId,
    required int selectedProvinceId,
    required List<LookupItemDto> categories,
    required List<RegionLookupDto> regions,
    required Function(int categoryId, int provinceId) onApply,
    VoidCallback? onReset,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MapFilterModal(
        selectedCategoryId: selectedCategoryId,
        selectedProvinceId: selectedProvinceId,
        categories: categories,
        regions: regions,
        onApply: onApply,
        onReset: onReset,
      ),
    );
  }

  @override
  State<MapFilterModal> createState() => _MapFilterModalState();
}

class _MapFilterModalState extends State<MapFilterModal> {
  late int _tempCategoryId;
  late int _tempProvinceId;
  final Map<String, bool> _openRegionAccordion = {
    'Miền Bắc': true,
    'Miền Trung': true,
    'Miền Nam': true,
  };

  @override
  void initState() {
    super.initState();
    _tempCategoryId = widget.selectedCategoryId;
    _tempProvinceId = widget.selectedProvinceId;

    for (final region in widget.regions) {
      if (!_openRegionAccordion.containsKey(region.name)) {
        _openRegionAccordion[region.name] = true;
      }
    }
  }

  int get _tempActiveCount =>
      (_tempCategoryId > 0 ? 1 : 0) + (_tempProvinceId > 0 ? 1 : 0);

  void _toggleRegion(String regionName) {
    setState(() {
      _openRegionAccordion[regionName] =
          !(_openRegionAccordion[regionName] ?? true);
    });
  }

  void _resetLocalFilters() {
    setState(() {
      _tempCategoryId = 0;
      _tempProvinceId = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          _buildHeader(),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Categories
                  _buildCategoriesSection(),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), thickness: 1.2),
                  const SizedBox(height: 12),

                  // Section 2: Regions & Provinces
                  _buildRegionsSection(),
                ],
              ),
            ),
          ),

          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 18,
              color: Color(0xFF065F46),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Bộ lọc tìm kiếm',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          if (_tempActiveCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_tempActiveCount',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF065F46),
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF64748B),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  // ==================== SECTION 1: CATEGORIES ====================
  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'DANH MỤC TRẢI NGHIỆM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            if (_tempCategoryId > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Text(
                  '1 đã chọn',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Grid of Category Options (2-Column clean tiles)
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 6) / 2;
            final allCats = [
              const LookupItemDto(id: 0, name: 'Tất cả danh mục'),
              ...widget.categories,
            ];

            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allCats.map((cat) {
                final isSelected = _tempCategoryId == cat.id;
                return SizedBox(
                  width: itemWidth,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _tempCategoryId = isSelected ? 0 : cat.id;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFCBD5E1),
                                width: 1.3,
                              ),
                              color: isSelected ? const Color(0xFF059669) : Colors.white,
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              cat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Color(0xFF059669),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ==================== SECTION 2: REGIONS & PROVINCES ====================
  Widget _buildRegionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'VÙNG MIỀN & TỈNH THÀNH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            if (_tempProvinceId > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Text(
                  '1 tỉnh đã chọn',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // "Tất cả tỉnh thành" Option
        InkWell(
          onTap: () {
            setState(() => _tempProvinceId = 0);
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _tempProvinceId == 0 ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _tempProvinceId == 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _tempProvinceId == 0
                          ? const Color(0xFF059669)
                          : const Color(0xFFCBD5E1),
                      width: 1.3,
                    ),
                    color: _tempProvinceId == 0 ? const Color(0xFF059669) : Colors.white,
                  ),
                  child: _tempProvinceId == 0
                      ? Center(
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Tất cả tỉnh thành',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
                if (_tempProvinceId == 0)
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Color(0xFF059669),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Accordion for each Region
        for (final region in widget.regions) ...[
          _buildRegionAccordion(region),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildRegionAccordion(RegionLookupDto region) {
    final isOpen = _openRegionAccordion[region.name] ?? true;
    final regionProvinces = region.provinces;
    final hasSelectedInRegion =
        regionProvinces.any((p) => p.id == _tempProvinceId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSelectedInRegion
              ? const Color(0xFFA7F3D0)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          InkWell(
            onTap: () => _toggleRegion(region.name),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: isOpen ? Radius.zero : const Radius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: isOpen ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    region.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasSelectedInRegion
                          ? const Color(0xFF065F46)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  if (hasSelectedInRegion) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible 2-Column Grid
          if (isOpen && regionProvinces.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 6) / 2;

                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: regionProvinces.map((prov) {
                      final isSelected = _tempProvinceId == prov.id;

                      return SizedBox(
                        width: itemWidth,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _tempProvinceId = isSelected ? 0 : prov.id;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFCBD5E1),
                                      width: 1.2,
                                    ),
                                    color: isSelected
                                        ? const Color(0xFF059669)
                                        : Colors.white,
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 3.5,
                                            height: 3.5,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    prov.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 13,
                                    color: Color(0xFF059669),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== FOOTER ACTIONS ====================
  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Reset Button
          TextButton.icon(
            onPressed: _tempActiveCount > 0 ? _resetLocalFilters : null,
            icon: Icon(
              Icons.restart_alt_rounded,
              size: 16,
              color: _tempActiveCount > 0
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF94A3B8),
            ),
            label: Text(
              'Xóa bộ lọc',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _tempActiveCount > 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF94A3B8),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const Spacer(),

          // Apply Button
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onApply(_tempCategoryId, _tempProvinceId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065F46),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Áp dụng',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../data/models/region_landing_model.dart';

class RegionSearchBar extends StatefulWidget {
  final RegionLandingModel data;
  final Function(String query, String? province)? onSearch;
  final Function(String? province)? onOpenMap;

  const RegionSearchBar({
    super.key,
    required this.data,
    this.onSearch,
    this.onOpenMap,
  });

  @override
  State<RegionSearchBar> createState() => _RegionSearchBarState();
}

class _RegionSearchBarState extends State<RegionSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedProvince;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    widget.onSearch?.call(_searchController.text.trim(), _selectedProvince);
  }

  void _handleOpenMap() {
    widget.onOpenMap?.call(_selectedProvince);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Search text field
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7E5E4)),
            ),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _handleSearch(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1C1917)),
              decoration: InputDecoration(
                hintText: 'Tìm địa điểm, quán ăn tại ${data.name}...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFA8A29E)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFA8A29E), size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF78716C)),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Province dropdown selector
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7E5E4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFFA8A29E), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedProvince,
                      isExpanded: true,
                      hint: Text(
                        'Tất cả tỉnh thành ${data.name}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF292524),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF78716C)),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Tất cả tỉnh thành ${data.name}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF292524),
                            ),
                          ),
                        ),
                        ...data.provinces.map((prov) => DropdownMenuItem<String?>(
                              value: prov,
                              child: Text(
                                prov,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF292524),
                                ),
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedProvince = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Action Buttons Row
          Row(
            children: [
              // Button 1: Khám phá ngay
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: _handleSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC0392B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Khám phá ngay',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Button 2: Mở bản đồ vùng
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _handleOpenMap,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F4),
                    foregroundColor: const Color(0xFF44403C),
                    side: const BorderSide(color: Color(0xFFE7E5E4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2D6A4F)),
                  label: const Text(
                    'Bản đồ vùng',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

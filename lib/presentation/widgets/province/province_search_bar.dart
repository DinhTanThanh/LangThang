import 'package:flutter/material.dart';
import '../../../data/models/province_landing_model.dart';

class ProvinceSearchBar extends StatefulWidget {
  final ProvinceInfoDto province;
  final Function(String query)? onSearch;
  final VoidCallback? onOpenMap;

  const ProvinceSearchBar({
    super.key,
    required this.province,
    this.onSearch,
    this.onOpenMap,
  });

  @override
  State<ProvinceSearchBar> createState() => _ProvinceSearchBarState();
}

class _ProvinceSearchBarState extends State<ProvinceSearchBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    widget.onSearch?.call(_searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
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
                hintText: 'Tìm địa điểm, quán ăn, check-in tại ${widget.province.name}...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFA8A29E)),
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
          const SizedBox(height: 10),

          // 2. Action Buttons Row
          Row(
            children: [
              // Button 1: Khám phá ngay
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _handleSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC0392B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.explore_outlined, size: 16),
                  label: const Text(
                    'Khám phá ngay',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Button 2: Mở bản đồ tỉnh
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenMap,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F4),
                    foregroundColor: const Color(0xFF292524),
                    side: const BorderSide(color: Color(0xFFE7E5E4)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2D6A4F)),
                  label: const Text(
                    'Bản đồ tỉnh',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
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

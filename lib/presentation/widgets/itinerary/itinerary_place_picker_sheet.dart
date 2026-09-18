import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/services/place_api_service.dart';

class ItineraryPlacePickerSheet extends StatefulWidget {
  final int dayNumber;
  final ValueChanged<ItineraryStopModel> onSelectPlace;

  const ItineraryPlacePickerSheet({
    super.key,
    required this.dayNumber,
    required this.onSelectPlace,
  });

  static void show(
    BuildContext context, {
    required int dayNumber,
    required ValueChanged<ItineraryStopModel> onSelectPlace,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItineraryPlacePickerSheet(
        dayNumber: dayNumber,
        onSelectPlace: onSelectPlace,
      ),
    );
  }

  @override
  State<ItineraryPlacePickerSheet> createState() => _ItineraryPlacePickerSheetState();
}

class _ItineraryPlacePickerSheetState extends State<ItineraryPlacePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final PlaceApiService _placeApiService = PlaceApiService();
  Timer? _debounce;

  List<PlaceModel> _places = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tất cả';

  final List<String> _categories = [
    'Tất cả',
    'Danh lam thắng cảnh',
    'Ẩm thực & Quán ăn',
    'Di tích lịch sử',
    'Check-in & Sống ảo',
    'Nghỉ dưỡng & Resort',
    'Văn hóa & Nghệ thuật',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadPlaces();
    });
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);

    try {
      final res = await _placeApiService.searchPlaces(
        PlaceFilterParams(
          keyword: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
          pageSize: 50,
        ),
      );

      if (mounted) {
        List<PlaceModel> list = (res.success && res.data != null) ? res.data! : [];
        if (_selectedCategory != 'Tất cả') {
          list = list.where((p) => p.category.toLowerCase().contains(_selectedCategory.toLowerCase())).toList();
        }
        setState(() {
          _places = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePickPlace(PlaceModel place) {
    final stop = ItineraryStopModel(
      id: 'place-stop-${DateTime.now().microsecondsSinceEpoch}',
      placeId: place.id,
      time: '09:00',
      startTime: '09:00',
      endTime: '10:30',
      activity: place.name,
      location: place.address.isNotEmpty ? place.address : place.location,
      category: place.category.isNotEmpty ? place.category : 'Điểm tham quan',
      description: place.desc.isNotEmpty ? place.desc : null,
      costEstimate: place.priceRange.isNotEmpty ? place.priceRange : 'Miễn phí',
      costEstimateNum: place.priceRange.contains('đ')
          ? (double.tryParse(place.priceRange.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          : 0,
      transportMode: 'Xe máy',
      duration: '1.5 giờ',
      img: place.img,
      lat: place.latitude,
      lng: place.longitude,
      rating: place.rating,
    );

    widget.onSelectPlace(stop);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm "${place.name}" vào Ngày ${widget.dayNumber}!'),
        backgroundColor: const Color(0xFF047857),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.travel_explore_rounded, color: Color(0xFF059669), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Chọn địa điểm vào Ngày ${widget.dayNumber}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
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

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm địa điểm, thắng cảnh, quán ăn...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF059669), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9CA3AF)),
                          onPressed: () {
                            _searchController.clear();
                            _loadPlaces();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      _loadPlaces();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF059669) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Places List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF059669)),
                  )
                : _places.isEmpty
                    ? const Center(
                        child: Text(
                          'Không tìm thấy địa điểm phù hợp.',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _places.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final place = _places[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Row(
                              children: [
                                // Thumbnail
                                SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Image.network(
                                    place.img,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: const Color(0xFFE5E7EB),
                                      child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9CA3AF)),
                                    ),
                                  ),
                                ),

                                // Info
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD1FAE5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                place.category,
                                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                                                const SizedBox(width: 2),
                                                Text(
                                                  place.rating.toStringAsFixed(1),
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),

                                        Text(
                                          place.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                        ),

                                        Text(
                                          place.address.isNotEmpty ? place.address : place.location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                        ),

                                        const SizedBox(height: 6),

                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              place.priceRange.isNotEmpty ? place.priceRange : 'Miễn phí',
                                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => _handlePickPlace(place),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF059669),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              child: const Text('Thêm vào', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

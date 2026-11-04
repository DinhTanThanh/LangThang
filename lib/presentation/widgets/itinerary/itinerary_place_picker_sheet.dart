import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/recommendation_api_service.dart';

class ItineraryPlacePickerSheet extends StatefulWidget {
  final int? tripId;
  final int dayNumber;
  final String initialMode;
  final ValueChanged<ItineraryStopModel> onSelectPlace;

  const ItineraryPlacePickerSheet({
    super.key,
    this.tripId,
    required this.dayNumber,
    this.initialMode = 'search',
    required this.onSelectPlace,
  });

  static void show(
    BuildContext context, {
    int? tripId,
    required int dayNumber,
    String initialMode = 'search',
    required ValueChanged<ItineraryStopModel> onSelectPlace,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItineraryPlacePickerSheet(
        tripId: tripId,
        dayNumber: dayNumber,
        initialMode: initialMode,
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
  final RecommendationApiService _recommendationApiService = RecommendationApiService();
  Timer? _debounce;

  late String _activeMode; // 'search' | 'knn_suggestions'
  List<PlaceModel> _places = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tất cả';

  List<PlaceModel> _suggestedPlaces = [];
  bool _isSuggestLoading = false;
  final Set<int> _justAddedPlaceIds = {};

  final List<String> _categories = [
    'Tất cả',
    'Danh lam thắng cảnh',
    'Ẩm thực & Quán ăn',
    'Di tích lịch sử',
    'Check-in & Sống ảo',
    'Nghỉ dưỡng & Resort',
    'Văn hóa & Nghệ thuật',
  ];

  String get _targetDayLabel => widget.dayNumber <= 0 ? 'Kho lưu trữ' : 'Ngày ${widget.dayNumber}';

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialMode;
    _loadPlaces();
    _loadTripSuggestions();
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

  Future<void> _loadTripSuggestions() async {
    setState(() => _isSuggestLoading = true);
    try {
      final tripId = widget.tripId ?? 1;
      final results = await _recommendationApiService.getTripPlaceSuggestions(tripId, topK: 12);
      if (mounted) {
        setState(() {
          _suggestedPlaces = results;
          _isSuggestLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSuggestLoading = false);
    }
  }

  void _handlePickPlace(PlaceModel place, {bool autoPop = false}) {
    final stop = ItineraryStopModel(
      id: 'place-stop-${DateTime.now().microsecondsSinceEpoch}',
      placeId: place.id,
      time: '09:00',
      startTime: '09:00',
      endTime: '10:30',
      activity: place.name,
      location: place.address.isNotEmpty ? place.address : place.location,
      category: place.category.isNotEmpty ? place.category : 'Điểm tham quan',
      description: (place.explainReason?.isNotEmpty ?? false)
          ? place.explainReason
          : (place.desc.isNotEmpty ? place.desc : null),
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

    setState(() {
      _justAddedPlaceIds.add(place.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm "${place.name}" vào $_targetDayLabel!'),
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _justAddedPlaceIds.remove(place.id);
        });
      }
    });

    if (autoPop) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
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
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.travel_explore_rounded, color: Color(0xFF059669), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Thêm vào $_targetDayLabel',
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

          // Top Mode Switcher Tabs (Matching ItineraryPlacePickerDrawer.tsx & Screenshot)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                // Tab 1: Tra cứu & Lọc địa điểm
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeMode = 'search'),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _activeMode == 'search' ? const Color(0xFF064E3B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _activeMode == 'search' ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: _activeMode == 'search'
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF064E3B).withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 15,
                            color: _activeMode == 'search' ? Colors.white : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tra cứu & Lọc địa điểm',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _activeMode == 'search' ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Tab 2: Đề xuất theo gu đoàn
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _activeMode = 'knn_suggestions');
                      if (_suggestedPlaces.isEmpty && !_isSuggestLoading) {
                        _loadTripSuggestions();
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _activeMode == 'knn_suggestions' ? const Color(0xFF047857) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _activeMode == 'knn_suggestions' ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
                        ),
                        boxShadow: _activeMode == 'knn_suggestions'
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF047857).withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: _activeMode == 'knn_suggestions' ? Colors.white : const Color(0xFF065F46),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Đề xuất theo gu đoàn',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _activeMode == 'knn_suggestions' ? Colors.white : const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Content based on active mode
          Expanded(
            child: _activeMode == 'knn_suggestions' ? _buildKnnSuggestionsView() : _buildSearchView(),
          ),
        ],
      ),
    );
  }

  // Chế độ 1: Tra cứu & Lọc địa điểm thông thường
  Widget _buildSearchView() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        final isJustAdded = _justAddedPlaceIds.contains(place.id);
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
                                              backgroundColor: isJustAdded ? const Color(0xFF047857) : const Color(0xFF059669),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              minimumSize: Size.zero,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(isJustAdded ? Icons.check_rounded : Icons.add_rounded, size: 13),
                                                const SizedBox(width: 3),
                                                Text(
                                                  isJustAdded ? 'Đã thêm' : 'Thêm vào',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                                ),
                                              ],
                                            ),
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
    );
  }

  // Chế độ 2: Đề xuất theo gu đoàn (KNN) - Matching ItineraryPlacePickerDrawer.tsx & Screenshot
  Widget _buildKnnSuggestionsView() {
    if (_isSuggestLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF047857),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đang tính toán địa điểm hợp gu cả đoàn...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_suggestedPlaces.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.explore_off_outlined, size: 40, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Không tìm thấy địa điểm gợi ý phù hợp',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bạn có thể chuyển sang tab tra cứu thông thường để tìm thêm địa điểm mong muốn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _activeMode = 'search'),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Chuyển sang Tra cứu'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF065F46),
                  side: const BorderSide(color: Color(0xFF065F46)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: _suggestedPlaces.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final place = _suggestedPlaces[index];
        final isJustAdded = _justAddedPlaceIds.contains(place.id);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image (4:3 aspect ratio)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      place.img,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 11, color: Color(0xFF6EE7B7)),
                            const SizedBox(width: 4),
                            const Text(
                              'Hợp gu đoàn',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Card Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location & Rating row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF059669)),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  place.province.isNotEmpty
                                      ? (place.region.isNotEmpty ? '${place.province}, ${place.region}' : place.province)
                                      : (place.location.isNotEmpty ? place.location : 'Việt Nam'),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (place.rating > 0)
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 2),
                              Text(
                                place.rating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              if (place.reviews > 0) ...[
                                const SizedBox(width: 2),
                                Text(
                                  '(${place.reviews})',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Title
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Description / explainReason
                    Text(
                      (place.explainReason?.isNotEmpty ?? false)
                          ? place.explainReason!
                          : (place.desc.isNotEmpty
                              ? place.desc
                              : 'Phù hợp để thêm vào lịch trình (${place.category} tại ${place.province})'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Hours & Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              place.hours.isNotEmpty ? place.hours : '07:30 – 17:00',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Text(
                          place.price.isNotEmpty ? place.price : 'Miễn phí',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Add Button (Matching Screenshot)
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => _handlePickPlace(place),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isJustAdded ? const Color(0xFF047857) : const Color(0xFF064E3B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isJustAdded ? Icons.check_rounded : Icons.add_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              isJustAdded ? 'Đã thêm vào $_targetDayLabel' : 'Thêm vào $_targetDayLabel',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

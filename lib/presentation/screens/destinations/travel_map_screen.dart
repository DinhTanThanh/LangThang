import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/services/place_api_service.dart';
import '../../widgets/mapbox_interactive_map.dart';
import 'place_detail_screen.dart';
import 'map_directions_screen.dart';

class TravelMapScreen extends StatefulWidget {
  final PlaceModel? initialPlace;

  const TravelMapScreen({
    super.key,
    this.initialPlace,
  });

  @override
  State<TravelMapScreen> createState() => _TravelMapScreenState();
}

class _TravelMapScreenState extends State<TravelMapScreen>
    with SingleTickerProviderStateMixin {
  // State & Data
  List<PlaceModel> _places = [];
  List<PlaceModel> _filteredPlaces = [];
  bool _loading = true;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _selectedCategory = 0;
  String _selectedRegion = 'all';
  PlaceModel? _activePlace;
  String _mobileView = 'map'; // 'map' | 'list'

  // Map Controls
  final GlobalKey<MapboxInteractiveMapState> _mapKey =
      GlobalKey<MapboxInteractiveMapState>();
  String _currentStyle = 'mapbox/streets-v12';
  late AnimationController _pulseController;

  final List<Map<String, String>> _mapStyles = [
    {'id': 'mapbox/streets-v12', 'name': 'Đường phố', 'icon': 'map'},
    {'id': 'mapbox/satellite-streets-v12', 'name': 'Vệ tinh', 'icon': 'satellite'},
    {'id': 'mapbox/outdoors-v12', 'name': 'Ngoài trời', 'icon': 'terrain'},
    {'id': 'mapbox/dark-v11', 'name': 'Tối', 'icon': 'dark_mode'},
  ];

  // Categories matching Share_Locations MapSidebar.tsx
  final List<Map<String, dynamic>> _categories = [
    {'id': 0, 'name': 'Tất cả', 'icon': Icons.layers_outlined},
    {'id': 1, 'name': 'Thắng cảnh', 'icon': Icons.park_outlined},
    {'id': 2, 'name': 'Di tích', 'icon': Icons.account_balance_outlined},
    {'id': 3, 'name': 'Ẩm thực', 'icon': Icons.restaurant_outlined},
    {'id': 4, 'name': 'Bãi biển', 'icon': Icons.beach_access_outlined},
    {'id': 5, 'name': 'Cà phê', 'icon': Icons.local_cafe_outlined},
    {'id': 6, 'name': 'Vui chơi', 'icon': Icons.attractions_outlined},
  ];

  // Regions matching Share_Locations MapSidebar.tsx
  final List<Map<String, String>> _regions = [
    {'id': 'all', 'label': 'Tất cả'},
    {'id': 'north', 'label': 'Bắc'},
    {'id': 'central', 'label': 'Trung'},
    {'id': 'south', 'label': 'Nam'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fetchMapPlaces();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchMapPlaces() async {
    setState(() => _loading = true);

    List<PlaceModel> loadedPlaces = [];

    try {
      final response = await PlaceApiService().searchPlaces(
        const PlaceFilterParams(page: 1, pageSize: 50),
      );
      if (response.success && response.data != null && response.data!.isNotEmpty) {
        loadedPlaces = response.data!;
      }
    } catch (_) {}

    if (loadedPlaces.isEmpty) {
      loadedPlaces = List.from(MockData.places);
    }

    if (widget.initialPlace != null) {
      final exists = loadedPlaces.any((p) => p.id == widget.initialPlace!.id);
      if (!exists) {
        loadedPlaces.insert(0, widget.initialPlace!);
      }
      _activePlace = widget.initialPlace;
    } else if (loadedPlaces.isNotEmpty) {
      _activePlace = loadedPlaces.first;
    }

    if (mounted) {
      setState(() {
        _places = loadedPlaces;
        _loading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    List<PlaceModel> result = List.from(_places);

    // Search keyword
    if (_searchKeyword.trim().isNotEmpty) {
      final kw = _searchKeyword.trim().toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(kw) ||
            p.location.toLowerCase().contains(kw) ||
            p.province.toLowerCase().contains(kw) ||
            p.category.toLowerCase().contains(kw);
      }).toList();
    }

    // Category filter
    if (_selectedCategory > 0) {
      result = result.where((p) {
        final placeCat = p.category.toLowerCase();
        final placeType = p.type.toLowerCase();
        if (_selectedCategory == 1) {
          return placeCat.contains('thắng cảnh') ||
              placeCat.contains('thiên nhiên') ||
              placeType.contains('du lịch');
        } else if (_selectedCategory == 2) {
          return placeCat.contains('di tích') ||
              placeCat.contains('lịch sử') ||
              placeCat.contains('văn hóa') ||
              placeCat.contains('chùa');
        } else if (_selectedCategory == 3) {
          return placeCat.contains('ẩm thực') ||
              placeCat.contains('quán ăn') ||
              placeCat.contains('nhà hàng') ||
              placeCat.contains('bánh') ||
              placeType.contains('ăn uống');
        } else if (_selectedCategory == 4) {
          return placeCat.contains('bãi biển') ||
              placeCat.contains('biển') ||
              placeCat.contains('vịnh');
        } else if (_selectedCategory == 5) {
          return placeCat.contains('cà phê') ||
              placeCat.contains('cafe') ||
              placeCat.contains('coffee');
        } else if (_selectedCategory == 6) {
          return placeCat.contains('vui chơi') ||
              placeCat.contains('giải trí') ||
              placeCat.contains('khu vui chơi') ||
              placeType.contains('vui chơi');
        }
        return true;
      }).toList();
    }

    // Region filter
    if (_selectedRegion != 'all') {
      String regKeyword = '';
      if (_selectedRegion == 'north') regKeyword = 'bắc';
      if (_selectedRegion == 'central') regKeyword = 'trung';
      if (_selectedRegion == 'south') regKeyword = 'nam';

      result = result.where((p) {
        return p.region.toLowerCase().contains(regKeyword);
      }).toList();
    }

    setState(() {
      _filteredPlaces = result;
      if (_activePlace != null &&
          !_filteredPlaces.any((p) => p.id == _activePlace!.id) &&
          _filteredPlaces.isNotEmpty) {
        _activePlace = _filteredPlaces.first;
      }
    });
  }

  Future<void> _performSearch() async {
    final kw = _searchController.text.trim();
    setState(() {
      _searchKeyword = kw;
    });
    _applyFilters();

    if (_filteredPlaces.isNotEmpty) {
      _handleSelectPlace(_filteredPlaces.first);
      return;
    }

    if (kw.isNotEmpty) {
      try {
        final res = await PlaceApiService().searchPlaces(
          PlaceFilterParams(keyword: kw, page: 1, pageSize: 50),
        );
        if (res.success && res.data != null && res.data!.isNotEmpty && mounted) {
          final newPlaces = res.data!;
          final existingIds = _places.map((p) => p.id).toSet();
          final uniqueNew = newPlaces.where((p) => !existingIds.contains(p.id)).toList();
          setState(() {
            _places.addAll(uniqueNew);
            _applyFilters();
          });
          if (_filteredPlaces.isNotEmpty) {
            _handleSelectPlace(_filteredPlaces.first);
          }
        }
      } catch (_) {}
    }
  }

  void _handleSelectPlace(PlaceModel place) {
    setState(() {
      _activePlace = place;
      _mobileView = 'map';
    });
    if (place.latitude != 0.0 && place.longitude != 0.0) {
      _mapKey.currentState?.setCenter(place.latitude, place.longitude, 13.5);
    }
  }

  void _showMapStyleModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chọn kiểu hiển thị bản đồ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: _mapStyles.map((style) {
                final isSel = _currentStyle == style['id'];
                IconData iconData = Icons.map_rounded;
                if (style['icon'] == 'satellite') iconData = Icons.satellite_alt_rounded;
                if (style['icon'] == 'terrain') iconData = Icons.terrain_rounded;
                if (style['icon'] == 'dark_mode') iconData = Icons.dark_mode_rounded;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() => _currentStyle = style['id']!);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconData,
                              size: 20,
                              color: isSel ? const Color(0xFF059669) : const Color(0xFF6B7280),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              style['name']!,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                color: isSel ? const Color(0xFF065F46) : const Color(0xFF374151),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOP HEADER (Matching Share_Locations MapPage.tsx)
            _buildHeader(),

            // 2. SEARCH & FILTER BAR (Matching Share_Locations MapSidebar.tsx)
            _buildMapSidebarFilter(),

            // 3. MAIN MAP & DRAWER / LIST VIEW
            Expanded(
              child: _mobileView == 'map'
                  ? _buildMapContent()
                  : _buildListViewContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 1. TOP HEADER ====================
  // (Matching Share_Locations MapPage.tsx header)
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          if (Navigator.canPop(context)) ...[
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Compass Icon (w-9 h-9 rounded-lg bg-emerald-100 text-emerald-700)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.explore_rounded,
              size: 20,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(width: 10),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Bản Đồ Du Lịch Việt Nam',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Khám phá hơn 63 tỉnh thành & tọa độ nổi tiếng theo thời gian thực',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // View Toggle: [ Bản đồ ] / [ Danh sách (N) ]
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  label: 'Bản đồ',
                  icon: Icons.map_outlined,
                  isSelected: _mobileView == 'map',
                  onTap: () => setState(() => _mobileView = 'map'),
                ),
                _buildToggleButton(
                  label: 'Danh sách (${_filteredPlaces.length})',
                  icon: Icons.format_list_bulleted_rounded,
                  isSelected: _mobileView == 'list',
                  onTap: () => setState(() => _mobileView = 'list'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFF047857) : const Color(0xFF4B5563),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF047857) : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 2. SEARCH & FILTER BAR ====================
  // (Matching Share_Locations MapSidebar.tsx)
  Widget _buildMapSidebarFilter() {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input (Single clean modern search bar matching Share_Locations)
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: _performSearch,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.search, size: 19, color: Color(0xFF059669)),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    autocorrect: true,
                    enableSuggestions: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      _debounceTimer?.cancel();
                      _performSearch();
                    },
                    onChanged: (val) {
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
                        if (mounted) {
                          _searchKeyword = val;
                          _applyFilters();
                        }
                      });
                    },
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Tìm địa điểm, tỉnh thành...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                if (_searchKeyword.isNotEmpty || _searchController.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchKeyword = '';
                        _applyFilters();
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Categories horizontal scroll (Matching MapSidebar.tsx)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final cat in _categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat['id'] as int;
                          _applyFilters();
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _selectedCategory == cat['id']
                              ? const Color(0xFF059669)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedCategory == cat['id']
                                ? const Color(0xFF059669)
                                : const Color(0xFFE5E7EB),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              size: 13,
                              color: _selectedCategory == cat['id']
                                  ? Colors.white
                                  : const Color(0xFF4B5563),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cat['name'] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: _selectedCategory == cat['id']
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _selectedCategory == cat['id']
                                    ? Colors.white
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 7),

          // Regions row (Tất cả, Bắc, Trung, Nam)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Vùng miền: ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 4),
                  for (final reg in _regions) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedRegion = reg['id']!;
                            _applyFilters();
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _selectedRegion == reg['id']
                                ? const Color(0xFFECFDF5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _selectedRegion == reg['id']
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Text(
                            reg['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _selectedRegion == reg['id']
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: _selectedRegion == reg['id']
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_outlined, size: 13, color: Color(0xFF059669)),
                  const SizedBox(width: 3),
                  Text(
                    'Hiển thị: ${_filteredPlaces.length} địa điểm',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 3. INTERACTIVE MAP SECTION ====================
  List<MapboxCustomMarker> _buildCustomMarkers() {
    return _filteredPlaces
        .where((p) => p.latitude != 0.0 && p.longitude != 0.0)
        .map((place) {
      final isSelected = _activePlace?.id == place.id;
      return MapboxCustomMarker(
        id: place.id.toString(),
        latitude: place.latitude,
        longitude: place.longitude,
        alignmentOffset: const Offset(-0.5, -0.5),
        onTap: () => _handleSelectPlace(place),
        child: _buildShareLocationsMarker(place, isSelected),
      );
    }).toList();
  }

  Widget _buildMapContent() {
    final initialLat = _activePlace?.latitude != null && _activePlace!.latitude != 0.0
        ? _activePlace!.latitude
        : 16.0544;
    final initialLng = _activePlace?.longitude != null && _activePlace!.longitude != 0.0
        ? _activePlace!.longitude
        : 108.2022;

    return Stack(
      children: [
        // Real Mapbox Interactive Vector / Raster Tile Map
        Positioned.fill(
          child: ClipRect(
            child: MapboxInteractiveMap(
              key: _mapKey,
              initialLat: initialLat,
              initialLng: initialLng,
              initialZoom: _activePlace != null && _activePlace!.latitude != 0.0 ? 11.5 : 5.8,
              styleId: _currentStyle,
              customMarkers: _buildCustomMarkers(),
            ),
          ),
        ),

        // Map Controls (Top Right)
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              // Zoom In
              _buildMapControlBtn(
                icon: Icons.add,
                tooltip: 'Phóng to',
                onTap: () => _mapKey.currentState?.zoomIn(),
              ),
              const SizedBox(height: 6),

              // Zoom Out
              _buildMapControlBtn(
                icon: Icons.remove,
                tooltip: 'Thu nhỏ',
                onTap: () => _mapKey.currentState?.zoomOut(),
              ),
              const SizedBox(height: 6),

              // Style Toggle (Standard / Satellite / Outdoors / Dark)
              _buildMapControlBtn(
                icon: Icons.layers_outlined,
                tooltip: 'Đổi kiểu bản đồ',
                onTap: _showMapStyleModal,
              ),
              const SizedBox(height: 6),

              // Reset Center
              _buildMapControlBtn(
                icon: Icons.my_location_rounded,
                tooltip: 'Tâm điểm Việt Nam',
                onTap: () {
                  if (_activePlace != null &&
                      _activePlace!.latitude != 0.0 &&
                      _activePlace!.longitude != 0.0) {
                    _mapKey.currentState?.setCenter(
                      _activePlace!.latitude,
                      _activePlace!.longitude,
                      13.5,
                    );
                  } else {
                    _mapKey.currentState?.setCenter(16.0544, 108.2022, 5.8);
                  }
                },
              ),
            ],
          ),
        ),

        // Quick Place Scroll (Above Drawer)
        if (_filteredPlaces.isNotEmpty && _activePlace != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 172,
            child: SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _filteredPlaces.length,
                itemBuilder: (context, index) {
                  final place = _filteredPlaces[index];
                  final isSelected = _activePlace?.id == place.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _handleSelectPlace(place),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF059669)
                              : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF059669)
                                : const Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 13,
                              color: isSelected ? Colors.white : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              place.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // FLOATING PLACE DRAWER (Matching Share_Locations MapPlaceDrawer.tsx)
        if (_activePlace != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildShareLocationsDrawer(_activePlace!),
          ),
      ],
    );
  }

  // Marker matching: w-8 h-8 rounded-full bg-emerald-600 border-2 border-white shadow-lg flex items-center justify-center text-white
  Widget _buildShareLocationsMarker(PlaceModel place, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selected Label Badge
        if (isSelected)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                Text(
                  place.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

        // Pin (Matching Share_Locations MapPage)
        Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 44 + (_pulseController.value * 14),
                    height: 44 + (_pulseController.value * 14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981)
                          .withValues(alpha: 0.3 - (_pulseController.value * 0.2)),
                    ),
                  );
                },
              ),
            Container(
              width: isSelected ? 36 : 28,
              height: isSelected ? 36 : 28,
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: isSelected ? 2.5 : 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.location_on,
                size: isSelected ? 20 : 15,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF1F2937)),
      ),
    );
  }

  // ==================== 4. MAP PLACE DRAWER ====================
  // (Matching Share_Locations MapPlaceDrawer.tsx)
  Widget _buildShareLocationsDrawer(PlaceModel place) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Close button (-top-3 -right-3 w-7 h-7 bg-white rounded-full shadow-md border)
          Positioned(
            top: -22,
            right: -22,
            child: InkWell(
              onTap: () => setState(() => _activePlace = null),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, size: 15, color: Color(0xFF4B5563)),
              ),
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Thumbnail (w-24 h-24 rounded-lg object-cover)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 92,
                  height: 96,
                  child: Image.network(
                    place.img,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Center(
                        child: Icon(Icons.photo_outlined, color: Color(0xFF9CA3AF), size: 28),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Place Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category & Rating Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            place.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 2),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Name
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Address with MapPin icon
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            place.location.isNotEmpty ? place.location : place.province,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Action buttons: "Chỉ đường" & "Xem chi tiết"
                    Row(
                      children: [
                        // Chỉ đường
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapDirectionsScreen(place: place),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Chỉ đường',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.open_in_new, size: 12, color: Color(0xFF059669)),
                            ],
                          ),
                        ),
                        const Spacer(),

                        // Xem chi tiết button (Matching Share_Locations Link)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlaceDetailScreen(place: place),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Xem chi tiết',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 5. LIST VIEW SECTION ====================
  // (Matching Share_Locations MapSidebar.tsx places list)
  Widget _buildListViewContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF059669)),
      );
    }

    if (_filteredPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'Không tìm thấy địa điểm phù hợp',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(14),
      itemCount: _filteredPlaces.length,
      itemBuilder: (context, index) {
        final place = _filteredPlaces[index];
        final isSelected = _activePlace?.id == place.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _handleSelectPlace(place),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: Image.network(
                        place.img,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.photo_outlined, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                place.category.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF3730A3),
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 2),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          place.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                place.location.isNotEmpty ? place.location : place.province,
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          place.price,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Map icon indicator
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF059669) : const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.map_rounded,
                      size: 14,
                      color: isSelected ? Colors.white : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


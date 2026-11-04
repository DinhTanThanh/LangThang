import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/mapbox_service.dart';
import '../../widgets/mapbox_interactive_map.dart';
import '../../widgets/map/map_filter_modal.dart';
import 'place_detail_screen.dart';

enum TravelMode { car, motorcycle, walk }

class TravelMapScreen extends StatefulWidget {
  final PlaceModel? initialPlace;
  final String? initialSearchQuery;
  final String? initialRegion;
  final String? initialProvince;
  final bool autoStartDirections;

  const TravelMapScreen({
    super.key,
    this.initialPlace,
    this.initialSearchQuery,
    this.initialRegion,
    this.initialProvince,
    this.autoStartDirections = false,
  });

  @override
  State<TravelMapScreen> createState() => _TravelMapScreenState();
}

class _TravelMapScreenState extends State<TravelMapScreen> {
  // State & Data
  List<PlaceModel> _places = [];
  List<PlaceModel> _filteredPlaces = [];
  bool _loading = true;
  bool _isFirstLoad = true;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  // Filter State matching Web Map
  int _selectedCategoryId = 0;
  int _selectedProvinceId = 0;
  List<LookupItemDto> _filterCategories = [];
  List<RegionLookupDto> _filterRegions = [];

  PlaceModel? _activePlace;
  String _mobileView = 'map'; // 'map' | 'list'

  // Directions Navigation State (Google Maps Style)
  bool _isDirectionsMode = false;
  bool _isLoadingRoute = false;
  bool _isTopDirectionsCollapsed = false;
  bool _isBottomPlaceCardCollapsed = false;
  MapboxRouteResult? _currentRoute;
  TravelMode _selectedTravelMode = TravelMode.car;
  double? _originLat;
  double? _originLng;
  String _originName = 'Vị trí hiện tại của bạn';
  double? _destLat;
  double? _destLng;

  // Map Controls
  final GlobalKey<MapboxInteractiveMapState> _mapKey =
      GlobalKey<MapboxInteractiveMapState>();
  String _currentStyle = 'mapbox/streets-v12';

  final List<Map<String, String>> _mapStyles = [
    {'id': 'mapbox/streets-v12', 'name': 'Đường phố', 'icon': 'map'},
    {'id': 'mapbox/satellite-streets-v12', 'name': 'Vệ tinh', 'icon': 'satellite'},
    {'id': 'mapbox/outdoors-v12', 'name': 'Ngoài trời', 'icon': 'terrain'},
    {'id': 'mapbox/dark-v11', 'name': 'Tối', 'icon': 'dark_mode'},
  ];

  // Default Categories matching Web Map Screenshot
  static const List<LookupItemDto> _defaultCategoriesLookup = [
    LookupItemDto(id: 1, name: 'Bar / Pub / Club'),
    LookupItemDto(id: 2, name: 'Cà phê & Tráng miệng'),
    LookupItemDto(id: 3, name: 'Chợ & Phố đi bộ'),
    LookupItemDto(id: 4, name: 'Danh lam thắng cảnh'),
    LookupItemDto(id: 5, name: 'Khách sạn & Resort'),
    LookupItemDto(id: 6, name: 'Khu vui chơi giải trí'),
    LookupItemDto(id: 7, name: 'Villa & Hostel'),
    LookupItemDto(id: 8, name: 'Ẩm thực & Quán ăn'),
    LookupItemDto(id: 9, name: 'Di tích & Lịch sử'),
    LookupItemDto(id: 10, name: 'Bãi biển & Vịnh'),
  ];

  // Default Regions & Provinces Fallback
  static const List<RegionLookupDto> _defaultRegionsLookup = [
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

  List<LookupItemDto> get _categories =>
      _filterCategories.isNotEmpty ? _filterCategories : _defaultCategoriesLookup;

  List<RegionLookupDto> get _regions =>
      _filterRegions.isNotEmpty ? _filterRegions : _defaultRegionsLookup;

  int get _activeFilterCount =>
      (_selectedCategoryId > 0 ? 1 : 0) + (_selectedProvinceId > 0 ? 1 : 0);

  LookupItemDto? get _activeCategory {
    if (_selectedCategoryId <= 0) return null;
    try {
      return _categories.firstWhere((c) => c.id == _selectedCategoryId);
    } catch (_) {
      return null;
    }
  }

  List<LookupItemDto> get _allProvinces =>
      _regions.expand((r) => r.provinces).toList();

  LookupItemDto? get _activeProvince {
    if (_selectedProvinceId <= 0) return null;
    try {
      return _allProvinces.firstWhere((p) => p.id == _selectedProvinceId);
    } catch (_) {
      return null;
    }
  }

  String _normalizeVietnamese(String str) {
    var result = str.toLowerCase();
    result = result.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    result = result.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    result = result.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    result = result.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    result = result.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    result = result.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    result = result.replaceAll(RegExp(r'[đ]'), 'd');
    return result;
  }

  @override
  void initState() {
    super.initState();
    final initialKw = widget.initialSearchQuery ?? widget.initialPlace?.name;
    if (initialKw != null && initialKw.isNotEmpty) {
      _searchKeyword = initialKw;
      _searchController.text = initialKw;
    }
    if (widget.initialProvince != null && widget.initialProvince!.isNotEmpty) {
      final initProvNorm = _normalizeVietnamese(widget.initialProvince!);
      for (final p in _defaultRegionsLookup.expand((r) => r.provinces)) {
        if (_normalizeVietnamese(p.name).contains(initProvNorm) ||
            initProvNorm.contains(_normalizeVietnamese(p.name))) {
          _selectedProvinceId = p.id;
          break;
        }
      }
    }

    _fetchFilterOptions();
    _fetchMapPlaces();

    if (widget.autoStartDirections && widget.initialPlace != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDirectionsTo(widget.initialPlace!);
      });
    }
  }

  List<double> _resolvePlaceCoords(PlaceModel p) {
    if (p.latitude >= 8.0 && p.latitude <= 24.0 && p.longitude >= 102.0 && p.longitude <= 110.0) {
      return [p.latitude, p.longitude];
    }
    final query = _normalizeVietnamese('${p.name} ${p.location} ${p.province}');
    if (query.contains('dong da bac') || query.contains('da bac') || query.contains('phu tho')) {
      return [21.3228, 105.2280];
    }
    if (query.contains('thac bo') || query.contains('den thac bo')) return [20.7600, 105.2800];
    if (query.contains('hoa binh')) return [20.8143, 105.3384];
    if (query.contains('ha noi') || query.contains('hoan kiem') || query.contains('ho guom')) return [21.0285, 105.8542];
    if (query.contains('ho chi minh') || query.contains('sai gon') || query.contains('ben thanh')) return [10.7769, 106.7009];
    if (query.contains('da nang') || query.contains('ba na') || query.contains('son tra')) return [16.0544, 108.2022];
    if (query.contains('nha trang') || query.contains('khanh hoa')) return [12.2388, 109.1967];
    if (query.contains('da lat') || query.contains('lam dong')) return [11.9404, 108.4583];
    if (query.contains('phu quoc') || query.contains('kien giang')) return [10.2899, 103.9840];
    if (query.contains('quang ninh') || query.contains('ha long')) return [20.9505, 107.0734];
    if (query.contains('ninh binh') || query.contains('trang an')) return [20.2506, 105.9745];
    if (query.contains('sapa') || query.contains('sa pa') || query.contains('lao cai')) return [22.3364, 103.8438];
    if (query.contains('hue') || query.contains('thua thien')) return [16.4637, 107.5909];
    if (query.contains('hoi an') || query.contains('quang nam')) return [15.8801, 108.3380];
    if (query.contains('vung tau') || query.contains('ba ria')) return [10.3460, 107.0843];
    if (query.contains('can tho')) return [10.0452, 105.7469];
    if (query.contains('hai phong')) return [20.8449, 106.6881];
    if (query.contains('ha giang')) return [22.8233, 104.9839];
    return [21.0285, 105.8542];
  }

  MapboxRouteResult _generateFastEstimatedRoute(
    double oLat,
    double oLng,
    double dLat,
    double dLng,
    TravelMode mode,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 - math.cos((dLat - oLat) * p) / 2 +
        math.cos(oLat * p) * math.cos(dLat * p) *
        (1 - math.cos((dLng - oLng) * p)) / 2;
    final distanceKm = (12742 * math.asin(math.sqrt(a > 0 ? a : 0.0001))).clamp(0.1, 3000.0);
    final distanceMeters = distanceKm * 1000 * 1.35;

    double durationSeconds;
    switch (mode) {
      case TravelMode.car:
        durationSeconds = (distanceKm / 55.0) * 3600;
        break;
      case TravelMode.motorcycle:
        durationSeconds = (distanceKm / 45.0) * 3600;
        break;
      case TravelMode.walk:
        durationSeconds = (distanceKm / 4.5) * 3600;
        break;
    }

    final List<List<double>> fastCoords = [];
    for (int i = 0; i <= 6; i++) {
      final t = i / 6.0;
      final lat = oLat + (dLat - oLat) * t;
      final lng = oLng + (dLng - oLng) * t;
      fastCoords.add([lng, lat]);
    }

    return MapboxRouteResult(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      coordinates: fastCoords,
      steps: const [],
    );
  }

  Future<void> _startDirectionsTo(PlaceModel place) async {
    final destCoords = _resolvePlaceCoords(place);
    final targetDestLat = destCoords[0];
    final targetDestLng = destCoords[1];

    setState(() {
      _activePlace = place;
      _isDirectionsMode = true;
      _isLoadingRoute = true;
      _mobileView = 'map';
      _isTopDirectionsCollapsed = false;
      _isBottomPlaceCardCollapsed = false;
      _destLat = targetDestLat;
      _destLng = targetDestLng;
      _originLat ??= 10.7769; // Khởi tạo ban đầu vị trí Miền Nam nếu chưa có GPS
      _originLng ??= 106.7009;
    });

    // 1. Quét nhanh vị trí GPS hiện tại từ thiết bị
    try {
      final cachedPos = await Geolocator.getLastKnownPosition();
      if (cachedPos != null && mounted) {
        if (cachedPos.latitude >= 8.0 && cachedPos.latitude <= 24.0) {
          _originLat = cachedPos.latitude;
          _originLng = cachedPos.longitude;
          _originName = 'Vị trí hiện tại của bạn';
        }
      }

      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (isEnabled) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 8),
              ),
            );
          } catch (_) {}

          final currentPos = pos;
          if (currentPos != null && mounted) {
            _originLat = currentPos.latitude;
            _originLng = currentPos.longitude;
            _originName = 'Vị trí hiện tại của bạn';
          }
        }
      }
    } catch (_) {}

    await _fetchRouteAndFitBounds();
  }

  Future<void> _fetchRouteAndFitBounds() async {
    if (_originLat == null || _destLat == null) return;

    setState(() => _isLoadingRoute = true);

    final profile = _selectedTravelMode == TravelMode.walk ? 'walking' : 'driving';
    final result = await MapboxService.getDirections(
      originLat: _originLat!,
      originLng: _originLng!,
      destLat: _destLat!,
      destLng: _destLng!,
      profile: profile,
    );

    if (mounted) {
      setState(() {
        _currentRoute = result ?? _generateFastEstimatedRoute(
          _originLat!,
          _originLng!,
          _destLat!,
          _destLng!,
          _selectedTravelMode,
        );
        _isLoadingRoute = false;
      });

      _fitRouteBounds();
    }
  }

  void _fitRouteBounds() {
    if (_originLat == null || _destLat == null) return;
    final minLat = math.min(_originLat!, _destLat!);
    final maxLat = math.max(_originLat!, _destLat!);
    final minLng = math.min(_originLng!, _destLng!);
    final maxLng = math.max(_originLng!, _destLng!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapKey.currentState?.fitBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        screenSize: MediaQuery.of(context).size,
      );
    });
  }

  void _clearDirections() {
    setState(() {
      _isDirectionsMode = false;
      _currentRoute = null;
      _isTopDirectionsCollapsed = false;
      _isBottomPlaceCardCollapsed = false;
    });
  }

  Future<void> _openGoogleMapsNavigation() async {
    if (_destLat == null || _destLng == null) return;
    final originParam = (_originLat != null && _originLng != null) ? '&origin=$_originLat,$_originLng' : '';
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1$originParam&destination=$_destLat,$_destLng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở ứng dụng Google Maps.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchFilterOptions() async {
    try {
      final res = await PlaceApiService().getFilterOptions();
      if (res.success && res.data != null) {
        if (mounted) {
          setState(() {
            _filterCategories = res.data!.categories;
            _filterRegions = res.data!.regions;
            if (_selectedProvinceId == 0 &&
                widget.initialProvince != null &&
                widget.initialProvince!.isNotEmpty) {
              final initProvNorm = _normalizeVietnamese(widget.initialProvince!);
              for (final p in _allProvinces) {
                if (_normalizeVietnamese(p.name).contains(initProvNorm) ||
                    initProvNorm.contains(_normalizeVietnamese(p.name))) {
                  _selectedProvinceId = p.id;
                  break;
                }
              }
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchMapPlaces({bool autoFly = true}) async {
    setState(() => _loading = true);

    List<PlaceModel> loadedPlaces = [];

    try {
      final response = await PlaceApiService().getPlacesMap(
        keyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
        categoryId: _selectedCategoryId > 0 ? _selectedCategoryId : null,
        provinceId: _selectedProvinceId > 0 ? _selectedProvinceId : null,
      );
      if (response.success && response.data != null && response.data!.isNotEmpty) {
        loadedPlaces = response.data!;
      }
    } catch (_) {}

    if (loadedPlaces.isEmpty) {
      try {
        final fallbackRes = await PlaceApiService().searchPlaces(
          PlaceFilterParams(
            keyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
            categoryId: _selectedCategoryId > 0 ? _selectedCategoryId : null,
            provinceId: _selectedProvinceId > 0 ? _selectedProvinceId : null,
            page: 1,
            pageSize: 50,
          ),
        );
        if (fallbackRes.success && fallbackRes.data != null && fallbackRes.data!.isNotEmpty) {
          loadedPlaces = fallbackRes.data!;
        }
      } catch (_) {}
    }

    if (loadedPlaces.isEmpty) {
      loadedPlaces = List.from(MockData.places);
    }

    if (_isFirstLoad && widget.initialPlace != null) {
      final exists = loadedPlaces.any((p) => p.id == widget.initialPlace!.id);
      if (!exists) {
        loadedPlaces.insert(0, widget.initialPlace!);
      }
      _activePlace = widget.initialPlace;
      _isFirstLoad = false;
    }

    if (mounted) {
      setState(() {
        _places = loadedPlaces;
        _loading = false;
        _applyFilters(autoFly: autoFly);
      });
    }
  }

  void _applyFilters({bool autoFly = false}) {
    List<PlaceModel> result = List.from(_places);

    // 1. Search keyword with intelligent Vietnamese normalization
    if (_searchKeyword.trim().isNotEmpty) {
      final rawKw = _searchKeyword.trim().toLowerCase();
      final normKw = _normalizeVietnamese(rawKw);

      result = result.where((p) {
        final nameNorm = _normalizeVietnamese(p.name);
        final locNorm = _normalizeVietnamese(p.location);
        final provNorm = _normalizeVietnamese(p.province);
        final catNorm = _normalizeVietnamese(p.category);
        final regNorm = _normalizeVietnamese(p.region);
        final descNorm = _normalizeVietnamese(p.desc);

        return nameNorm.contains(normKw) ||
            p.name.toLowerCase().contains(rawKw) ||
            locNorm.contains(normKw) ||
            p.location.toLowerCase().contains(rawKw) ||
            provNorm.contains(normKw) ||
            p.province.toLowerCase().contains(rawKw) ||
            catNorm.contains(normKw) ||
            regNorm.contains(normKw) ||
            descNorm.contains(normKw);
      }).toList();
    }

    // 2. Category filter matching web categories & keywords
    if (_selectedCategoryId > 0) {
      final activeCat = _activeCategory;
      final targetCatName = activeCat != null && activeCat.name.isNotEmpty
          ? _normalizeVietnamese(activeCat.name)
          : '';

      result = result.where((p) {
        final placeCat = _normalizeVietnamese(p.category);
        final placeType = _normalizeVietnamese(p.type);
        final placeTags = p.tags.map((t) => _normalizeVietnamese(t)).join(' ');
        final placeDesc = _normalizeVietnamese(p.desc);
        final placeName = _normalizeVietnamese(p.name);
        final allText = '$placeCat $placeType $placeTags $placeDesc $placeName';

        if (targetCatName.isNotEmpty &&
            (placeCat.contains(targetCatName) ||
                placeType.contains(targetCatName) ||
                allText.contains(targetCatName))) {
          return true;
        }

        if (targetCatName.contains('thang canh') || targetCatName.contains('thien nhien')) {
          return allText.contains('thang canh') ||
              allText.contains('thien nhien') ||
              allText.contains('canh quan') ||
              allText.contains('du lich') ||
              allText.contains('cau') ||
              allText.contains('ho') ||
              allText.contains('ban');
        } else if (targetCatName.contains('bar') ||
            targetCatName.contains('pub') ||
            targetCatName.contains('club')) {
          return allText.contains('bar') ||
              allText.contains('pub') ||
              allText.contains('club') ||
              allText.contains('lounge') ||
              allText.contains('bia');
        } else if (targetCatName.contains('ca phe') ||
            targetCatName.contains('cafe') ||
            targetCatName.contains('trang mieng')) {
          return allText.contains('ca phe') ||
              allText.contains('cafe') ||
              allText.contains('coffee') ||
              allText.contains('trang mieng') ||
              allText.contains('tra sua');
        } else if (targetCatName.contains('cho') || targetCatName.contains('pho di bo')) {
          return allText.contains('cho') ||
              allText.contains('pho di bo') ||
              allText.contains('mua sam') ||
              allText.contains('night market');
        } else if (targetCatName.contains('khach san') || targetCatName.contains('resort')) {
          return allText.contains('khach san') ||
              allText.contains('resort') ||
              allText.contains('hotel') ||
              allText.contains('nghi duong');
        } else if (targetCatName.contains('vui choi') || targetCatName.contains('giai tri')) {
          return allText.contains('vui choi') ||
              allText.contains('giai tri') ||
              allText.contains('cong vien') ||
              allText.contains('sun world') ||
              allText.contains('amusement');
        } else if (targetCatName.contains('villa') || targetCatName.contains('hostel')) {
          return allText.contains('villa') ||
              allText.contains('hostel') ||
              allText.contains('homestay') ||
              allText.contains('can ho');
        } else if (targetCatName.contains('am thuc') || targetCatName.contains('quan an')) {
          return allText.contains('am thuc') ||
              allText.contains('quan an') ||
              allText.contains('nha hang') ||
              allText.contains('an uong') ||
              allText.contains('banh') ||
              allText.contains('pho');
        } else if (targetCatName.contains('di tich') || targetCatName.contains('lich su')) {
          return allText.contains('di tich') ||
              allText.contains('lich su') ||
              allText.contains('van hoa') ||
              allText.contains('chua') ||
              allText.contains('den') ||
              allText.contains('bao tang');
        } else if (targetCatName.contains('bien') || targetCatName.contains('vinh')) {
          return allText.contains('bai bien') ||
              allText.contains('bien') ||
              allText.contains('vinh') ||
              allText.contains('dao') ||
              allText.contains('lang chai');
        }

        return placeCat.isNotEmpty;
      }).toList();
    }

    // 3. Province filter
    if (_selectedProvinceId > 0 && _activeProvince != null && _activeProvince!.name.isNotEmpty) {
      final provNameNorm = _normalizeVietnamese(_activeProvince!.name);
      final parts = provNameNorm
          .split(RegExp(r'[/,-]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      result = result.where((p) {
        final pProvNorm = _normalizeVietnamese(p.province);
        final pLocNorm = _normalizeVietnamese(p.location);

        for (final part in parts) {
          if (pProvNorm.contains(part) || pLocNorm.contains(part)) {
            return true;
          }
        }
        return pProvNorm.contains(provNameNorm) || pLocNorm.contains(provNameNorm);
      }).toList();
    }

    setState(() {
      _filteredPlaces = result;
      if (_filteredPlaces.isNotEmpty) {
        if (_activePlace == null ||
            !_filteredPlaces.any((p) => p.id == _activePlace!.id)) {
          _activePlace = _filteredPlaces.first;
        }
      } else {
        _activePlace = null;
      }
    });

    if (autoFly) {
      if (_activePlace != null && _activePlace!.latitude != 0.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapKey.currentState?.flyTo(
            _activePlace!.latitude,
            _activePlace!.longitude,
            _selectedProvinceId > 0 ? 12.0 : 13.5,
            600,
          );
        });
      } else if (_selectedProvinceId > 0 && _activeProvince != null) {
        final provCoords = _getProvinceCenterCoords(_activeProvince!.name);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapKey.currentState?.flyTo(
            provCoords[0],
            provCoords[1],
            11.5,
            600,
          );
        });
      }
    }
  }

  List<double> _getProvinceCenterCoords(String provName) {
    final text = _normalizeVietnamese(provName);
    if (text.contains('ha noi')) return [21.0285, 105.8542];
    if (text.contains('ho chi minh') || text.contains('sai gon')) return [10.7769, 106.7009];
    if (text.contains('da nang')) return [16.0544, 108.2022];
    if (text.contains('hue') || text.contains('thua thien')) return [16.4637, 107.5909];
    if (text.contains('quang nam') || text.contains('hoi an')) return [15.8801, 108.3380];
    if (text.contains('lam dong') || text.contains('da lat')) return [11.9404, 108.4380];
    if (text.contains('khanh hoa') || text.contains('nha trang')) return [12.2388, 109.1967];
    if (text.contains('lao cai') || text.contains('sa pa') || text.contains('sapa')) return [22.3364, 103.8438];
    if (text.contains('ha giang')) return [22.8233, 104.9836];
    if (text.contains('quang ninh') || text.contains('ha long')) return [20.9515, 107.0736];
    if (text.contains('ninh binh')) return [20.2506, 105.9744];
    if (text.contains('hai phong')) return [20.8449, 106.6881];
    if (text.contains('can tho')) return [10.0452, 105.7469];
    if (text.contains('kien giang') || text.contains('phu quoc')) return [10.2899, 103.9840];
    if (text.contains('vung tau') || text.contains('ba ria')) return [10.3460, 107.0843];
    if (text.contains('binh dinh') || text.contains('quy nhon')) return [13.7830, 109.2197];
    if (text.contains('quang binh')) return [17.4760, 106.6000];
    if (text.contains('tay ninh')) return [11.3100, 106.0988];
    if (text.contains('an giang')) return [10.5216, 105.1259];
    if (text.contains('cao bang')) return [22.6657, 106.2625];
    return [16.0544, 108.2022];
  }

  Future<void> _performSearch() async {
    _isFirstLoad = false;
    final kw = _searchController.text.trim();
    _searchFocusNode.unfocus();
    setState(() {
      _searchKeyword = kw;
    });
    _applyFilters(autoFly: true);
    _fetchMapPlaces(autoFly: true);
  }

  void _openFilterModal() {
    MapFilterModal.show(
      context,
      selectedCategoryId: _selectedCategoryId,
      selectedProvinceId: _selectedProvinceId,
      categories: _categories,
      regions: _regions,
      onApply: (catId, provId) {
        setState(() {
          _selectedCategoryId = catId;
          _selectedProvinceId = provId;
        });
        _fetchMapPlaces(autoFly: true);
      },
      onReset: _handleResetFilters,
    );
  }

  void _handleCategoryChange(int catId) {
    setState(() {
      _selectedCategoryId = catId;
    });
    _fetchMapPlaces(autoFly: false);
  }

  void _handleProvinceChange(int provId) {
    setState(() {
      _selectedProvinceId = provId;
    });
    _fetchMapPlaces(autoFly: true);
  }

  void _handleResetFilters() {
    setState(() {
      _selectedCategoryId = 0;
      _selectedProvinceId = 0;
      _searchKeyword = '';
      _searchController.clear();
    });
    _fetchMapPlaces(autoFly: false);
  }

  void _handleSelectPlace(PlaceModel place) {
    _isFirstLoad = false;
    setState(() {
      _activePlace = place;
      _mobileView = 'map';
    });
    if (place.latitude != 0.0 && place.longitude != 0.0) {
      _mapKey.currentState?.flyTo(place.latitude, place.longitude, 14.5, 550);
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
            RepaintBoundary(child: _buildHeader()),

            // 2. SEARCH & FILTER BAR (Matching Screenshot & Share_Locations MapSidebar.tsx)
            RepaintBoundary(child: _buildMapSidebarFilter()),

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
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Compass Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.explore_rounded,
              size: 18,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(width: 8),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Bản Đồ Du Lịch Việt Nam',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.5),
                Text(
                  'Khám phá hơn 63 tỉnh thành & tọa độ nổi tiếng',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // View Toggle: [ Bản đồ ] / [ Danh sách (N) ]
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
              size: 12,
              color: isSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 3.5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 2. SEARCH & FILTER BAR ====================
  // (Matching Screenshot & Share_Locations MapSidebar.tsx)
  Widget _buildMapSidebarFilter() {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input & Filter Button Row
          Row(
            children: [
              // Search input box matching screenshot
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
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
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.search, size: 18, color: Color(0xFF059669)),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
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
                            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                              if (mounted) {
                                setState(() {
                                  _searchKeyword = val;
                                });
                                _applyFilters(autoFly: false);
                              }
                            });
                          },
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Tìm địa điểm, tỉnh thành...',
                            hintStyle: TextStyle(
                              fontSize: 12,
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
                            contentPadding: EdgeInsets.symmetric(vertical: 9),
                          ),
                        ),
                      ),
                      if (_searchKeyword.isNotEmpty || _searchController.text.isNotEmpty)
                        InkWell(
                          onTap: () {
                            _searchController.clear();
                            _searchFocusNode.unfocus();
                            setState(() {
                              _searchKeyword = '';
                              _applyFilters(autoFly: false);
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Icon(Icons.close, size: 15, color: Color(0xFF94A3B8)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Filter Trigger Button (Matching Screenshot Grid/Filter icon)
              InkWell(
                onTap: _openFilterModal,
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _activeFilterCount > 0
                            ? const Color(0xFF047857)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _activeFilterCount > 0
                              ? const Color(0xFF047857)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.grid_view_rounded,
                        size: 18,
                        color: _activeFilterCount > 0
                            ? Colors.white
                            : const Color(0xFF334155),
                      ),
                    ),
                    if (_activeFilterCount > 0)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF43F5E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              '$_activeFilterCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Search Results Quick Suggestion Bar
          if (_searchKeyword.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            if (_filteredPlaces.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Text(
                    'Tìm thấy ${_filteredPlaces.length} kết quả cho "${_searchKeyword.trim()}":',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 28,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredPlaces.length,
                  itemBuilder: (context, index) {
                    final p = _filteredPlaces[index];
                    final isSel = _activePlace?.id == p.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: InkWell(
                        onTap: () => _handleSelectPlace(p),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF059669) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSel ? const Color(0xFF059669) : const Color(0xFF6EE7B7),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.near_me_rounded,
                                size: 10,
                                color: isSel ? Colors.white : const Color(0xFF059669),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                  color: isSel ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              if (p.province.isNotEmpty) ...[
                                const SizedBox(width: 2.5),
                                Text(
                                  '(${p.province})',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                                    color: isSel ? Colors.white70 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 12, color: Color(0xFFDC2626)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Không tìm thấy địa điểm nào khớp với "${_searchKeyword.trim()}"',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB91C1C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 8),

          // Categories Horizontal Quick Pill Scroll (EXACT Match to Web Screenshot)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // "Tất cả" Pill Chip
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _handleCategoryChange(0),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: _selectedCategoryId == 0
                            ? const Color(0xFF047857)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedCategoryId == 0
                              ? const Color(0xFF047857)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          if (_selectedCategoryId == 0)
                            BoxShadow(
                              color: const Color(0xFF047857).withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                        ],
                      ),
                      child: Text(
                        'Tất cả',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: _selectedCategoryId == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _selectedCategoryId == 0
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),

                // Category items from list matching screenshot
                for (final cat in _categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        _handleCategoryChange(
                          _selectedCategoryId == cat.id ? 0 : cat.id,
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                        decoration: BoxDecoration(
                          color: _selectedCategoryId == cat.id
                              ? const Color(0xFF047857)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedCategoryId == cat.id
                                ? const Color(0xFF047857)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            if (_selectedCategoryId == cat.id)
                              BoxShadow(
                                color: const Color(0xFF047857).withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                          ],
                        ),
                        child: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _selectedCategoryId == cat.id
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selectedCategoryId == cat.id
                                ? Colors.white
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Active Filter Chips (Province / Category)
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'Đang lọc:',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Category Chip
                        if (_selectedCategoryId > 0 && _activeCategory != null) ...[
                          Container(
                            padding: const EdgeInsets.fromLTRB(7, 2.5, 3, 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _activeCategory!.name,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                InkWell(
                                  onTap: () => _handleCategoryChange(0),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(1.5),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 12,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],

                        // Province Chip
                        if (_selectedProvinceId > 0 && _activeProvince != null) ...[
                          Container(
                            padding: const EdgeInsets.fromLTRB(6, 2.5, 3, 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 11,
                                  color: Color(0xFF047857),
                                ),
                                const SizedBox(width: 2.5),
                                Text(
                                  _activeProvince!.name,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                InkWell(
                                  onTap: () => _handleProvinceChange(0),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(1.5),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 12,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],

                        // Reset link
                        InkWell(
                          onTap: _handleResetFilters,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Xóa tất cả',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers_outlined, size: 11, color: Color(0xFF059669)),
                    const SizedBox(width: 2.5),
                    Text(
                      '${_filteredPlaces.length}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
        alignmentOffset: const Offset(-0.5, -0.9),
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
        // Real Mapbox Interactive Vector / Raster Tile Map with Route Polyline
        Positioned.fill(
          child: ClipRect(
            child: MapboxInteractiveMap(
              key: _mapKey,
              initialLat: initialLat,
              initialLng: initialLng,
              initialZoom: _activePlace != null && _activePlace!.latitude != 0.0 ? 11.5 : 5.8,
              styleId: _currentStyle,
              customMarkers: _isDirectionsMode ? const [] : _buildCustomMarkers(),
              routeCoordinates: _isDirectionsMode ? _currentRoute?.coordinates : null,
              originLat: _isDirectionsMode ? _originLat : null,
              originLng: _isDirectionsMode ? _originLng : null,
              destLat: _isDirectionsMode ? _destLat : null,
              destLng: _isDirectionsMode ? _destLng : null,
              startTitle: _originName,
              destTitle: _activePlace?.name ?? 'Điểm đến',
            ),
          ),
        ),

        // 1. Google Maps style Floating Directions Overlay (Top of Map)
        if (_isDirectionsMode)
          _buildDirectionsFloatingOverlay(),

        // Map Controls (Top Right)
        Positioned(
          top: _isDirectionsMode ? (_isTopDirectionsCollapsed ? 65 : 220) : 12,
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
                tooltip: _isDirectionsMode ? 'Căn giữa lộ trình' : 'Tâm điểm Việt Nam',
                onTap: () {
                  if (_isDirectionsMode) {
                    _fitRouteBounds();
                  } else if (_activePlace != null &&
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
        if (!_isDirectionsMode && _filteredPlaces.isNotEmpty && _activePlace != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 168,
            child: SizedBox(
              height: 36,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF059669)
                              : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF059669)
                                : const Color(0xFFE5E7EB),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 5,
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

        // FLOATING PLACE CARD DRAWER (Matching Web Screenshot Card)
        if (_activePlace != null)
          _buildBottomPlaceCardOverlay(),
      ],
    );
  }

  Widget _buildBottomPlaceCardOverlay() {
    if (_activePlace == null) return const SizedBox.shrink();

    if (_isBottomPlaceCardCollapsed) {
      // Collapsed Floating Pill at Bottom
      return Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: GestureDetector(
          onTap: () => setState(() => _isBottomPlaceCardCollapsed = false),
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -80) {
              setState(() => _isBottomPlaceCardCollapsed = false);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Color(0xFF059669)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _activePlace!.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // Expand button
                InkWell(
                  onTap: () => setState(() => _isBottomPlaceCardCollapsed = false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.keyboard_arrow_up, size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 2),
                        Text(
                          'Mở rộng',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Close button
                InkWell(
                  onTap: () {
                    if (_isDirectionsMode) {
                      _clearDirections();
                    }
                    setState(() => _activePlace = null);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Expanded Place Card with Drag Hint & Actions
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 80) {
            setState(() => _isBottomPlaceCardCollapsed = true);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Action Toolbar (Floating Above Card - Never overlaps rating or text)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  // Drag Handle Bar (Minimalist without text)
                  InkWell(
                    onTap: () => setState(() => _isBottomPlaceCardCollapsed = true),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Container(
                        width: 28,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Nút Thu gọn (Collapse Button)
                  InkWell(
                    onTap: () => setState(() => _isBottomPlaceCardCollapsed = true),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        children: const [
                          Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF334155)),
                          SizedBox(width: 2),
                          Text(
                            'Thu gọn',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Nút Đóng (Close Button)
                  InkWell(
                    onTap: () {
                      if (_isDirectionsMode) {
                        _clearDirections();
                      }
                      setState(() => _activePlace = null);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close, size: 15, color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),

            // The Place Card
            _buildWebStylePlaceCard(
              _activePlace!,
              true,
              showActions: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaceDetailScreen(place: _activePlace!),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionsFloatingOverlay() {
    if (!_isDirectionsMode || _activePlace == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 500;

    if (_isTopDirectionsCollapsed) {
      return Positioned(
        top: 10,
        left: 12,
        right: isCompact ? 12 : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompact ? screenWidth - 24 : 380,
          ),
          child: GestureDetector(
            onTap: () => setState(() => _isTopDirectionsCollapsed = false),
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 80) {
                setState(() => _isTopDirectionsCollapsed = false);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1FAE5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.near_me_rounded, size: 13, color: Color(0xFF15803D)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Đang chỉ đường',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _selectedTravelMode == TravelMode.car
                                  ? Icons.directions_car
                                  : (_selectedTravelMode == TravelMode.motorcycle
                                      ? Icons.two_wheeler
                                      : Icons.directions_walk),
                              size: 12,
                              color: const Color(0xFF4B5563),
                            ),
                          ],
                        ),
                        if (_currentRoute != null)
                          Text(
                            '${_currentRoute!.formattedDuration} (${_currentRoute!.formattedDistance})',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            _activePlace!.name,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Button to expand
                  InkWell(
                    onTap: () => setState(() => _isTopDirectionsCollapsed = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.keyboard_arrow_down, size: 15, color: Color(0xFF374151)),
                          SizedBox(width: 2),
                          Text(
                            'Mở rộng',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Dedicated exit directions button
                  InkWell(
                    onTap: _clearDirections,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.close, size: 11, color: Color(0xFFDC2626)),
                          SizedBox(width: 2),
                          Text(
                            'Thoát',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      top: 10,
      left: 12,
      right: isCompact ? 12 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isCompact ? screenWidth - 24 : 380,
        ),
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -80) {
              setState(() => _isTopDirectionsCollapsed = true);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Exit button / Mode Indicator / Collapse / Brand
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.near_me_rounded, size: 11, color: Color(0xFF15803D)),
                          SizedBox(width: 3.5),
                          Text(
                            'Chỉ đường trực tiếp',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Collapse button
                    InkWell(
                      onTap: () => setState(() => _isTopDirectionsCollapsed = true),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.keyboard_arrow_up, size: 14, color: Color(0xFF4B5563)),
                            SizedBox(width: 2),
                            Text(
                              'Thu gọn',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Thoát chỉ đường button in header
                    InkWell(
                      onTap: _clearDirections,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.close, size: 12, color: Color(0xFFDC2626)),
                            SizedBox(width: 3),
                            Text(
                              'Thoát chỉ đường',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Origin & Destination Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF2563EB)),
                        Container(
                          width: 1.5,
                          height: 14,
                          color: const Color(0xFFCBD5E1),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                        ),
                        const Icon(Icons.location_on, size: 16, color: Color(0xFFE11D48)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _originName,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _activePlace!.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Travel Mode Selectors
                Row(
                  children: [
                    _buildTravelModePill(TravelMode.car, Icons.directions_car, 'Ô tô'),
                    const SizedBox(width: 6),
                    _buildTravelModePill(TravelMode.motorcycle, Icons.two_wheeler, 'Xe máy'),
                    const SizedBox(width: 6),
                    _buildTravelModePill(TravelMode.walk, Icons.directions_walk, 'Đi bộ'),
                  ],
                ),
                const SizedBox(height: 8),

                // Summary Info: Duration & Distance
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_isLoadingRoute)
                        const Row(
                          children: [
                            SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Đang tính lộ trình...',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                            ),
                          ],
                        )
                      else if (_currentRoute != null)
                        Row(
                          children: [
                            Text(
                              _currentRoute!.formattedDuration,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '(${_currentRoute!.formattedDistance})',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        )
                      else
                        const Text(
                          'Đã định tuyến',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),

                      // Google Maps link
                      InkWell(
                        onTap: _openGoogleMapsNavigation,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Mở Maps',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151),
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.open_in_new, size: 10.5, color: Color(0xFF374151)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Drag indicator handle at bottom of card
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTravelModePill(TravelMode mode, IconData icon, String label) {
    final isSelected = _selectedTravelMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedTravelMode = mode);
          _fetchRouteAndFitBounds();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? const Color(0xFF059669) : const Color(0xFF4B5563),
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF059669) : const Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ),
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

        // Isolated Pulsing Pin (Smooth GPU rendering without screen rebuilds)
        _PulsingMarkerPin(isSelected: isSelected),
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

  // ==================== 4. WEB-STYLE PLACE CARD (EXACT MATCH TO SCREENSHOT) ====================
  Widget _buildWebStylePlaceCard(
    PlaceModel place,
    bool isSelected, {
    VoidCallback? onTap,
    bool showActions = false,
  }) {
    final catName = place.category.isNotEmpty
        ? place.category.toUpperCase()
        : (place.type.isNotEmpty ? place.type.toUpperCase() : 'DANH LAM THẮNG CẢNH');

    final ratingStr = place.rating > 0
        ? (place.rating == place.rating.roundToDouble()
            ? place.rating.toInt().toString()
            : place.rating.toStringAsFixed(1))
        : '5';

    final reviewsCount = place.reviews > 0
        ? place.reviews
        : ((place.id * 3 % 7) + 3);

    final addressStr = place.location.isNotEmpty ? place.location : place.province;
    final priceStr = place.price.isNotEmpty ? place.price : 'Miễn phí';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF059669).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => _handleSelectPlace(place),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Image Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 82,
                        height: 82,
                        child: Image.network(
                          place.img,
                          fit: BoxFit.cover,
                          cacheWidth: 220,
                          cacheHeight: 220,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFF3F4F6),
                            child: const Center(
                              child: Icon(Icons.photo_outlined, color: Color(0xFF9CA3AF), size: 28),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Right Details Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Category tag (green uppercase) + Star Rating (yellow star)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  catName,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF059669),
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 1.5),
                                  Text(
                                    ratingStr,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Place Name (Bold dark)
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),

                          // Location / Address Row with Pin Icon
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  addressStr,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Bottom Row: Price (green bold) + Review count (gray)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  priceStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$reviewsCount đánh giá',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Optional Action buttons inside card (e.g. for Drawer)
                if (showActions) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_isDirectionsMode && _activePlace?.id == place.id)
                        InkWell(
                          onTap: _clearDirections,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.close, size: 13, color: Color(0xFFDC2626)),
                                SizedBox(width: 4),
                                Text(
                                  'Thoát chỉ đường',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: () => _startDirectionsTo(place),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.near_me_rounded, size: 13, color: Color(0xFF059669)),
                                SizedBox(width: 4),
                                Text(
                                  'Chỉ đường',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 5. LIST VIEW SECTION ====================
  // (Matching Screenshot & Share_Locations MapSidebar.tsx places list)
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _filteredPlaces.length,
      itemBuilder: (context, index) {
        final place = _filteredPlaces[index];
        final isSelected = _activePlace?.id == place.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildWebStylePlaceCard(
            place,
            isSelected,
            onTap: () => _handleSelectPlace(place),
          ),
        );
      },
    );
  }
}

/// Isolated Marker Pin that animates only when selected, with its own internal Ticker
class _PulsingMarkerPin extends StatefulWidget {
  final bool isSelected;

  const _PulsingMarkerPin({
    required this.isSelected,
  });

  @override
  State<_PulsingMarkerPin> createState() => _PulsingMarkerPinState();
}

class _PulsingMarkerPinState extends State<_PulsingMarkerPin>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.isSelected) {
      _startPulse();
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingMarkerPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _startPulse();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _stopPulse();
    }
  }

  void _startPulse() {
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _controller!.repeat(reverse: true);
  }

  void _stopPulse() {
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isSelected && _controller != null)
            AnimatedBuilder(
              animation: _controller!,
              builder: (context, child) {
                final val = _controller!.value;
                return Container(
                  width: 44 + (val * 14),
                  height: 44 + (val * 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981)
                        .withValues(alpha: 0.3 - (val * 0.2)),
                  ),
                );
              },
            ),
          Container(
            width: widget.isSelected ? 36 : 28,
            height: widget.isSelected ? 36 : 28,
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: widget.isSelected ? 2.5 : 2.0,
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
              size: widget.isSelected ? 20 : 15,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

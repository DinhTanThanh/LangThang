import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/models/user_profile_data_models.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../widgets/mapbox_interactive_map.dart';

class ContributePlaceScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialProvince;
  final ProposalItemModel? proposal;
  final bool isViewMode;

  const ContributePlaceScreen({
    super.key,
    this.initialCategory,
    this.initialProvince,
    this.proposal,
    this.isViewMode = false,
  });

  @override
  State<ContributePlaceScreen> createState() => _ContributePlaceScreenState();
}

class _ContributePlaceScreenState extends State<ContributePlaceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<MapboxInteractiveMapState> _mapKey = GlobalKey<MapboxInteractiveMapState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _addressKey = GlobalKey();
  final GlobalKey _descKey = GlobalKey();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();
  final FocusNode _descFocusNode = FocusNode();

  // Authentication State
  bool _isAuthLoading = true;
  bool _isAuthenticated = true;

  // Form State values matching ProposePlacePage.tsx
  String _name = '';
  String _selectedCategory = 'Ẩm thực & Đồ uống';
  String _selectedProvince = 'TP Hà Nội';
  String _address = '';
  String _phone = '';
  String _website = '';

  String _lat = '21.028500';
  String _lng = '105.854200';
  bool _isLocating = false;

  bool _is24Hours = false;
  String _openTime = '07:30';
  String _closeTime = '22:00';

  bool _isFree = false;
  String _minPrice = '35.000';
  String _maxPrice = '120.000';

  String _description = '';
  final List<XFile> _selectedImages = [];
  List<String> _networkImages = [];
  int _activePreviewImgIndex = 0;

  bool get _isViewMode => widget.isViewMode || widget.proposal != null;

  bool _isSubmitting = false;
  bool _isSubmittedSuccess = false;
  String _errorMsg = '';

  // Live duplicate suggestion state
  bool _showSuggestions = false;
  List<PlaceModel> _suggestions = [];
  Timer? _debounceTimer;

  // Live address autocomplete state (Google Map style)
  bool _showAddressSuggestions = false;
  bool _isLoadingAddressSuggestions = false;
  List<AddressSuggestion> _addressSuggestions = [];
  Timer? _addressDebounceTimer;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Ẩm thực & Đồ uống',
    'Danh lam & Thắng cảnh',
    'Di tích & Lịch sử',
    'Bãi biển & Nghỉ dưỡng',
    'Cà phê & Trà',
    'Vui chơi & Giải trí',
    'Khách sạn & Homestay',
    'Trải nghiệm bản địa',
    'Khác',
  ];

  final List<String> _allProvinces = [
    'TP Hà Nội',
    'TP Hồ Chí Minh',
    'Đà Nẵng',
    'Hải Phòng',
    'Cần Thơ',
    'An Giang',
    'Bà Rịa - Vũng Tàu',
    'Bắc Giang',
    'Bắc Kạn',
    'Bạc Liêu',
    'Bắc Ninh',
    'Bến Tre',
    'Bình Định',
    'Bình Dương',
    'Bình Phước',
    'Bình Thuận',
    'Cà Mau',
    'Cao Bằng',
    'Đắk Lắk',
    'Đắk Nông',
    'Điện Biên',
    'Đồng Nai',
    'Đồng Tháp',
    'Gia Lai',
    'Hà Giang',
    'Hà Nam',
    'Hà Tĩnh',
    'Hải Dương',
    'Hậu Giang',
    'Hòa Bình',
    'Hưng Yên',
    'Khánh Hòa',
    'Kiên Giang',
    'Kon Tum',
    'Lai Châu',
    'Lâm Đồng',
    'Lạng Sơn',
    'Lào Cai',
    'Long An',
    'Nam Định',
    'Nghệ An',
    'Ninh Bình',
    'Ninh Thuận',
    'Phú Thọ',
    'Phú Yên',
    'Quảng Bình',
    'Quảng Nam',
    'Quảng Ngãi',
    'Quảng Ninh',
    'Quảng Trị',
    'Sóc Trăng',
    'Sơn La',
    'Tây Ninh',
    'Thái Bình',
    'Thái Nguyên',
    'Thanh Hóa',
    'Thừa Thiên Huế',
    'Tiền Giang',
    'Trà Vinh',
    'Tuyên Quang',
    'Vĩnh Long',
    'Vĩnh Phúc',
    'Yên Bái',
  ];

  static const Map<String, List<double>> _provinceCoordinates = {
    'TP Hà Nội': [21.0285, 105.8542],
    'Hà Nội': [21.0285, 105.8542],
    'TP Hồ Chí Minh': [10.7769, 106.7009],
    'Hồ Chí Minh': [10.7769, 106.7009],
    'Đà Nẵng': [16.0544, 108.2022],
    'Hải Phòng': [20.8449, 106.6881],
    'Cần Thơ': [10.0452, 105.7469],
    'An Giang': [10.3759, 105.4185],
    'Bà Rịa - Vũng Tàu': [10.3460, 107.0843],
    'Bắc Giang': [21.2731, 106.1946],
    'Bắc Kạn': [22.1470, 105.8348],
    'Bạc Liêu': [9.2941, 105.7278],
    'Bắc Ninh': [21.1861, 106.0763],
    'Bến Tre': [10.2415, 106.3759],
    'Bình Định': [13.7830, 109.2197],
    'Bình Dương': [10.9805, 106.6519],
    'Bình Phước': [11.5333, 106.8833],
    'Bình Thuận': [10.9804, 108.2615],
    'Cà Mau': [9.1769, 105.1524],
    'Cao Bằng': [22.6667, 106.2500],
    'Đắk Lắk': [12.6667, 108.0500],
    'Đắk Nông': [12.0000, 107.7000],
    'Điện Biên': [21.3833, 103.0167],
    'Đồng Nai': [10.9574, 106.8427],
    'Đồng Tháp': [10.4578, 105.6325],
    'Gia Lai': [13.9833, 108.0000],
    'Hà Giang': [22.8233, 104.9839],
    'Hà Nam': [20.5833, 105.9167],
    'Hà Tĩnh': [18.3333, 105.9000],
    'Hải Dương': [20.9333, 106.3167],
    'Hậu Giang': [9.7833, 105.4667],
    'Hòa Bình': [20.8167, 105.3333],
    'Hưng Yên': [20.6500, 106.0500],
    'Khánh Hòa': [12.2388, 109.1967],
    'Kiên Giang': [10.0139, 105.0809],
    'Kon Tum': [14.3500, 108.0000],
    'Lai Châu': [22.3833, 103.4667],
    'Lâm Đồng': [11.9404, 108.4583],
    'Lạng Sơn': [21.8500, 106.7500],
    'Lào Cai': [22.4833, 103.9667],
    'Long An': [10.5333, 106.4000],
    'Nam Định': [20.4167, 106.1667],
    'Nghệ An': [18.6667, 105.6667],
    'Ninh Bình': [20.2500, 105.9744],
    'Ninh Thuận': [11.5667, 108.9833],
    'Phú Thọ': [21.3167, 105.2167],
    'Phú Yên': [13.0833, 109.3000],
    'Quảng Bình': [17.4833, 106.6000],
    'Quảng Nam': [15.5667, 108.4833],
    'Quảng Ngãi': [15.1167, 108.8000],
    'Quảng Ninh': [20.9500, 107.0833],
    'Quảng Trị': [16.8167, 107.1000],
    'Sóc Trăng': [9.6000, 105.9667],
    'Sơn La': [21.3167, 103.9000],
    'Tây Ninh': [11.3000, 106.1000],
    'Thái Bình': [20.4500, 106.3333],
    'Thái Nguyên': [21.5833, 105.8333],
    'Thanh Hóa': [19.8000, 105.7667],
    'Thừa Thiên Huế': [16.4637, 107.5909],
    'Tiền Giang': [10.3500, 106.3500],
    'Trà Vinh': [9.9333, 106.3333],
    'Tuyên Quang': [21.8167, 105.2167],
    'Vĩnh Long': [10.2500, 105.9667],
    'Vĩnh Phúc': [21.3000, 105.6000],
    'Yên Bái': [21.7000, 104.8667],
  };

  List<double>? _getProvinceCoordinates(String provName) {
    final clean = provName.toLowerCase().replaceAll('tp ', '').replaceAll('thành phố ', '').replaceAll('tỉnh ', '').trim();
    for (final entry in _provinceCoordinates.entries) {
      final entryClean = entry.key.toLowerCase().replaceAll('tp ', '').replaceAll('thành phố ', '').replaceAll('tỉnh ', '').trim();
      if (clean == entryClean || clean.contains(entryClean) || entryClean.contains(clean)) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();

    final p = widget.proposal;
    if (p != null) {
      _name = p.name;
      _nameController.text = p.name;
      _address = p.address;
      _addressController.text = p.address;
      _phone = p.phone;
      _phoneController.text = p.phone;
      _website = p.website;
      _websiteController.text = p.website;
      _description = p.description;
      _descController.text = p.description;
      if (p.category.isNotEmpty) {
        final matchedCat = _categories.firstWhere(
          (c) => c.toLowerCase() == p.category.toLowerCase() || p.category.toLowerCase().contains(c.toLowerCase()) || c.toLowerCase().contains(p.category.toLowerCase()),
          orElse: () => _categories.first,
        );
        _selectedCategory = matchedCat;
      }
      if (p.province.isNotEmpty) {
        final targetProv = p.province.toLowerCase();
        final matchedProv = _allProvinces.firstWhere(
          (prov) => prov.toLowerCase().contains(targetProv) || targetProv.contains(prov.toLowerCase().replaceAll('tp ', '')),
          orElse: () => _allProvinces.first,
        );
        _selectedProvince = matchedProv;
      }
      if (p.latitude != null && p.latitude != 0) {
        _lat = p.latitude!.toStringAsFixed(6);
      }
      if (p.longitude != null && p.longitude != 0) {
        _lng = p.longitude!.toStringAsFixed(6);
      }
      if (p.openingHours.isNotEmpty) {
        _is24Hours = p.openingHours.contains('24/7') || p.openingHours.contains('24h') || p.openingHours.contains('cả ngày');
        final times = RegExp(r'(\d{1,2}:\d{2})').allMatches(p.openingHours).map((m) => m.group(0)!).toList();
        if (times.isNotEmpty) _openTime = times[0];
        if (times.length > 1) _closeTime = times[1];
      }
      if (p.minPrice > 0 || p.maxPrice > 0) {
        _isFree = false;
        _minPrice = p.minPrice.toInt().toString();
        _maxPrice = p.maxPrice.toInt().toString();
      } else {
        _isFree = true;
      }
      if (p.mediaUrls.isNotEmpty) {
        _networkImages = List<String>.from(p.mediaUrls);
      } else if (p.coverImg.isNotEmpty) {
        _networkImages = [p.coverImg];
      }
    } else {
      if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
        final matchedCat = _categories.firstWhere(
          (c) => c.toLowerCase() == widget.initialCategory!.toLowerCase() || widget.initialCategory!.toLowerCase().contains(c.toLowerCase()) || c.toLowerCase().contains(widget.initialCategory!.toLowerCase()),
          orElse: () => _categories.first,
        );
        _selectedCategory = matchedCat;
      }
      if (widget.initialProvince != null && widget.initialProvince!.isNotEmpty) {
        final targetProv = widget.initialProvince!.toLowerCase();
        final matchedProv = _allProvinces.firstWhere(
          (prov) => prov.toLowerCase().contains(targetProv) || targetProv.contains(prov.toLowerCase().replaceAll('tp ', '')),
          orElse: () => _allProvinces.first,
        );
        _selectedProvince = matchedProv;
      }
    }

    _latController.text = _lat;
    _lngController.text = _lng;
    _minPriceController.text = _formatPriceNumber(_minPrice);
    _maxPriceController.text = _formatPriceNumber(_maxPrice);

    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus && _address.trim().length >= 2) {
        _locateAddressOnMap(_address);
      }
    });
  }

  Future<void> _checkAuth() async {
    try {
      final loggedIn = await AuthService().isLoggedIn();
      if (mounted) {
        setState(() {
          _isAuthenticated = loggedIn;
          _isAuthLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true; // Fallback to avoid blocking offline usage
          _isAuthLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressDebounceTimer?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _descController.dispose();
    _nameFocusNode.dispose();
    _addressFocusNode.dispose();
    _descFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    setState(() {
      _name = val;
    });

    _debounceTimer?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final res = await PlaceApiService().searchPlaces(
          PlaceFilterParams(keyword: val.trim(), pageSize: 4),
        );
        if (mounted) {
          setState(() {
            if (res.success && res.data != null && res.data!.isNotEmpty) {
              _suggestions = res.data!;
              _showSuggestions = true;
            } else {
              _suggestions = [];
              _showSuggestions = false;
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _showSuggestions = false;
          });
        }
      }
    });
  }

  void _onAddressChanged(String val) {
    setState(() {
      _address = val;
    });

    _addressDebounceTimer?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _addressSuggestions = [];
        _showAddressSuggestions = false;
        _isLoadingAddressSuggestions = false;
      });
      return;
    }

    _addressDebounceTimer = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      setState(() => _isLoadingAddressSuggestions = true);

      final suggestions = await _searchAddressSuggestions(val.trim());
      if (mounted) {
        setState(() {
          _isLoadingAddressSuggestions = false;
          _addressSuggestions = suggestions;
          _showAddressSuggestions = suggestions.isNotEmpty;
        });

        // Tự động load bản đồ đến vị trí địa chỉ phù hợp nhất ngay khi đang gõ
        if (suggestions.isNotEmpty && suggestions.first.latitude != 0 && suggestions.first.longitude != 0) {
          final top = suggestions.first;
          setState(() {
            _lat = top.latitude.toStringAsFixed(6);
            _lng = top.longitude.toStringAsFixed(6);
            _latController.text = _lat;
            _lngController.text = _lng;
            if (top.province.isNotEmpty) {
              for (final prov in _allProvinces) {
                final cleanProv = prov.toLowerCase().replaceAll('tp ', '').replaceAll('tỉnh ', '').trim();
                final cleanCity = top.province.toLowerCase().replaceAll('tp ', '').replaceAll('thành phố ', '').replaceAll('tỉnh ', '').trim();
                if (cleanCity.contains(cleanProv) || cleanProv.contains(cleanCity)) {
                  _selectedProvince = prov;
                  break;
                }
              }
            }
          });
          _mapKey.currentState?.flyTo(top.latitude, top.longitude, 16.0, 500);
        }
      }
    });
  }

  Future<void> _locateAddressOnMap(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    final suggestions = await _searchAddressSuggestions(trimmed);
    if (suggestions.isNotEmpty && mounted) {
      final best = suggestions.first;
      _selectAddressSuggestion(best);
    }
  }

  Future<List<AddressSuggestion>> _searchAddressSuggestions(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return [];

    final currentLat = double.tryParse(_lat) ?? 10.7769;
    final currentLng = double.tryParse(_lng) ?? 106.7009;
    final cleanProvince = _selectedProvince.replaceAll('TP ', '').replaceAll('Tỉnh ', '').trim();

    // 1. Tách số nhà nếu người dùng có gõ số ở đầu chuỗi (ví dụ: "100 Bình Thới", "123/4 Lê Lợi", "Số 50 Phan Huy Ích")
    final numMatch = RegExp(r'^(số\s+|hẻm\s+|ngõ\s+)?(\d+[\w\/\-]*)\s+(.*)', caseSensitive: false).firstMatch(trimmedQuery);
    String? detectedHouseNumber;
    String searchStreetQuery = trimmedQuery;

    if (numMatch != null) {
      final prefix = numMatch.group(1) ?? '';
      final number = numMatch.group(2) ?? '';
      final remainder = numMatch.group(3) ?? '';
      if (remainder.trim().isNotEmpty) {
        detectedHouseNumber = '$prefix$number'.trim();
        searchStreetQuery = remainder.trim();
      }
    }

    // 2. Chạy đồng thời tất cả các API định vị (Mapbox Geocoding, Database Places, Photon, Nominatim)
    final List<Future<List<AddressSuggestion>>> apiFutures = [
      // Nguồn 1: Mapbox Geocoding API siêu tốc và chính xác cao tại Việt Nam
      _fetchMapboxAddress(trimmedQuery, limit: 12),

      // Nguồn 2: Mapbox Geocoding theo tên đường/địa điểm (nếu có tách số nhà)
      if (searchStreetQuery != trimmedQuery)
        _fetchMapboxAddress(searchStreetQuery, limit: 10),

      // Nguồn 3: Mapbox Geocoding theo tên đường/địa điểm kèm Tỉnh/Thành
      if (cleanProvince.isNotEmpty)
        _fetchMapboxAddress('$trimmedQuery, $cleanProvince', limit: 10),

      // Nguồn 4: Tìm trong cơ sở dữ liệu địa điểm du lịch của LangThang
      _fetchDatabasePlacesAddress(trimmedQuery, limit: 6),

      // Nguồn 5: Photon tìm theo chuỗi + GPS hiện tại
      _fetchPhotonAddress(trimmedQuery, currentLat, currentLng, limit: 10),

      // Nguồn 6: Photon kèm Tỉnh/Thành
      if (cleanProvince.isNotEmpty)
        _fetchPhotonAddress('$trimmedQuery $cleanProvince', currentLat, currentLng, limit: 10),

      // Nguồn 7: OpenStreetMap Nominatim toàn quốc
      _fetchNominatimAddress('$trimmedQuery, Việt Nam', limit: 10),
    ];

    final List<List<AddressSuggestion>> apiResponses = await Future.wait(apiFutures);

    // 3. Tổng hợp, bổ sung số nhà thông minh và lọc trùng
    final List<AddressSuggestion> combined = [];
    final Set<String> seenAddresses = {};

    for (final list in apiResponses) {
      for (final item in list) {
        String finalTitle = item.title;
        String finalFull = item.fullAddress;

        // Nếu người dùng có nhập số nhà mà kết quả API trả về chỉ có tên đường -> tự động ghép số nhà chính xác
        if (detectedHouseNumber != null) {
          final titleLower = finalTitle.toLowerCase();
          final fullLower = finalFull.toLowerCase();
          final numLower = detectedHouseNumber.toLowerCase();

          if (!titleLower.startsWith(numLower) && !titleLower.contains(' $numLower ') && !fullLower.startsWith(numLower)) {
            finalTitle = '$detectedHouseNumber $finalTitle';
            finalFull = '$detectedHouseNumber $finalFull';
          }
        }

        final normalizedKey = finalFull.toLowerCase().replaceAll(RegExp(r'[\s,\.\-]+'), ' ').trim();
        if (!seenAddresses.contains(normalizedKey) && item.latitude != 0 && item.longitude != 0) {
          seenAddresses.add(normalizedKey);
          combined.add(AddressSuggestion(
            title: finalTitle,
            fullAddress: finalFull,
            latitude: item.latitude,
            longitude: item.longitude,
            province: item.province,
            isHistory: item.isHistory,
          ));
        }
      }
    }

    // 4. Nếu chưa tìm thấy kết quả chi tiết, fallback tọa độ trung tâm của Tỉnh/Thành phố
    if (combined.isEmpty) {
      final provCoords = _getProvinceCoordinates(trimmedQuery) ?? _getProvinceCoordinates(cleanProvince);
      if (provCoords != null) {
        combined.add(AddressSuggestion(
          title: trimmedQuery,
          fullAddress: '$trimmedQuery, $cleanProvince',
          latitude: provCoords[0],
          longitude: provCoords[1],
          province: cleanProvince,
        ));
      }
    }

    // 5. Ưu tiên các kết quả thuộc đúng Tỉnh/Thành phố hoặc gần tọa độ hiện tại
    combined.sort((a, b) {
      final aInProv = cleanProvince.isNotEmpty && a.fullAddress.toLowerCase().contains(cleanProvince.toLowerCase()) ? 0 : 1;
      final bInProv = cleanProvince.isNotEmpty && b.fullAddress.toLowerCase().contains(cleanProvince.toLowerCase()) ? 0 : 1;
      if (aInProv != bInProv) return aInProv.compareTo(bInProv);

      final aHasNum = detectedHouseNumber != null && a.fullAddress.startsWith(detectedHouseNumber) ? 0 : 1;
      final bHasNum = detectedHouseNumber != null && b.fullAddress.startsWith(detectedHouseNumber) ? 0 : 1;
      return aHasNum.compareTo(bHasNum);
    });

    return combined.take(15).toList();
  }

  Future<List<AddressSuggestion>> _fetchMapboxAddress(String q, {int limit = 10}) async {
    final List<AddressSuggestion> list = [];
    try {
      const token = 'pk.eyJ1IjoiZGluaHRhbnRoYW5oMTkiLCJhIjoiY210bnNsZ2V2MG14NzJ5cHN1ZjhzMjU3MiJ9.qM8oAp0Hb9ThJlBzvn0Qtw';
      final encodedQ = Uri.encodeComponent(q);
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQ.json?access_token=$token&country=VN&language=vi&limit=$limit',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        for (final f in features) {
          final text = f['text'] as String? ?? '';
          final placeName = f['place_name'] as String? ?? '';
          final center = f['center'] as List<dynamic>? ?? [];
          final contextList = f['context'] as List<dynamic>? ?? [];

          String province = '';
          for (final c in contextList) {
            final id = c['id'] as String? ?? '';
            if (id.startsWith('region') || id.startsWith('place')) {
              province = c['text'] as String? ?? '';
            }
          }

          if (center.length >= 2) {
            final lng = (center[0] as num).toDouble();
            final lat = (center[1] as num).toDouble();
            list.add(AddressSuggestion(
              title: text.isNotEmpty ? text : placeName,
              fullAddress: placeName.isNotEmpty ? placeName : text,
              latitude: lat,
              longitude: lng,
              province: province,
            ));
          }
        }
      }
    } catch (_) {}
    return list;
  }

  Future<List<AddressSuggestion>> _fetchDatabasePlacesAddress(String q, {int limit = 5}) async {
    final List<AddressSuggestion> list = [];
    try {
      final res = await PlaceApiService().searchPlaces(
        PlaceFilterParams(keyword: q, pageSize: limit),
      );
      if (res.success && res.data != null) {
        for (final p in res.data!) {
          if (p.latitude != 0 && p.longitude != 0) {
            list.add(AddressSuggestion(
              title: p.name,
              fullAddress: p.location.isNotEmpty ? p.location : (p.province.isNotEmpty ? '${p.name}, ${p.province}' : p.name),
              latitude: p.latitude,
              longitude: p.longitude,
              province: p.province,
            ));
          }
        }
      }
    } catch (_) {}
    return list;
  }

  Future<List<AddressSuggestion>> _fetchPhotonAddress(String q, double lat, double lng, {int limit = 10}) async {
    final List<AddressSuggestion> list = [];
    try {
      final encodedQ = Uri.encodeComponent(q);
      final uri = Uri.parse('https://photon.komoot.io/api/?q=$encodedQ&lat=$lat&lon=$lng&limit=$limit');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        for (final f in features) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final geom = f['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geom['coordinates'] as List<dynamic>? ?? [];

          final name = props['name'] as String? ?? '';
          final street = props['street'] as String? ?? '';
          final housenumber = props['housenumber'] as String? ?? '';
          final locality = props['locality'] as String? ?? '';
          final district = props['district'] as String? ?? '';
          final city = props['city'] as String? ?? props['state'] ?? '';

          final titlePart = [housenumber, name.isNotEmpty ? name : street].where((s) => s.trim().isNotEmpty).join(' ');
          final finalTitle = titlePart.isNotEmpty ? titlePart : (name.isNotEmpty ? name : street);

          final addressParts = [
            finalTitle,
            locality,
            district,
            city,
          ].where((s) => s.trim().isNotEmpty).toSet().toList();

          final fullAddr = addressParts.join(', ');
          final lonVal = coords.isNotEmpty ? (coords[0] as num).toDouble() : 0.0;
          final latVal = coords.length > 1 ? (coords[1] as num).toDouble() : 0.0;

          if (fullAddr.isNotEmpty) {
            list.add(AddressSuggestion(
              title: finalTitle.isNotEmpty ? finalTitle : fullAddr,
              fullAddress: fullAddr,
              latitude: latVal,
              longitude: lonVal,
              province: city,
            ));
          }
        }
      }
    } catch (_) {}
    return list;
  }

  Future<List<AddressSuggestion>> _fetchNominatimAddress(String q, {int limit = 10}) async {
    final List<AddressSuggestion> list = [];
    try {
      final encodedQ = Uri.encodeComponent(q);
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQ&format=json&addressdetails=1&limit=$limit&countrycodes=vn');
      final res = await http.get(uri, headers: {
        'User-Agent': 'LangThangTravelApp/1.0',
        'Accept-Language': 'vi-VN,vi;q=0.9',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final rawList = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>? ?? [];
        for (final item in rawList) {
          final addr = item['address'] as Map<String, dynamic>? ?? {};
          final displayName = item['display_name'] as String? ?? '';
          final road = addr['road'] ?? addr['street'] ?? addr['pedestrian'] ?? '';
          final suburb = addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? '';
          final district = addr['district'] ?? addr['city_district'] ?? addr['county'] ?? '';
          final city = addr['city'] ?? addr['state'] ?? addr['province'] ?? '';
          final houseNum = addr['house_number'] ?? '';

          final title = [houseNum, road].where((s) => s.isNotEmpty).join(' ');
          final parts = [title.isNotEmpty ? title : (item['name'] ?? ''), suburb, district, city]
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
          final fullAddr = parts.isNotEmpty ? parts.join(', ') : displayName;

          final latVal = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final lonVal = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;

          list.add(AddressSuggestion(
            title: title.isNotEmpty ? title : fullAddr,
            fullAddress: fullAddr,
            latitude: latVal,
            longitude: lonVal,
            province: city,
          ));
        }
      }
    } catch (_) {}
    return list;
  }

  void _selectAddressSuggestion(AddressSuggestion item) {
    setState(() {
      _address = item.fullAddress;
      _addressController.text = item.fullAddress;
      _showAddressSuggestions = false;

      // Khớp tự động tỉnh thành
      if (item.province.isNotEmpty) {
        for (final prov in _allProvinces) {
          final cleanProv = prov.toLowerCase().replaceAll('tp ', '').replaceAll('tỉnh ', '').trim();
          final cleanCity = item.province.toLowerCase().replaceAll('tp ', '').replaceAll('thành phố ', '').replaceAll('tỉnh ', '').trim();
          if (cleanCity.contains(cleanProv) || cleanProv.contains(cleanCity)) {
            _selectedProvince = prov;
            break;
          }
        }
      }

      // Cập nhật tọa độ và bay bản đồ tới địa chỉ
      if (item.latitude != 0 && item.longitude != 0) {
        _lat = item.latitude.toStringAsFixed(6);
        _lng = item.longitude.toStringAsFixed(6);
        _latController.text = _lat;
        _lngController.text = _lng;
      }
    });

    if (item.latitude != 0 && item.longitude != 0) {
      _mapKey.currentState?.flyTo(item.latitude, item.longitude, 16.0, 500);
    }
  }

  void _selectSuggestion(PlaceModel place) {
    setState(() {
      _name = place.name;
      _nameController.text = place.name;
      _address = place.location.isNotEmpty ? place.location : place.province;
      _addressController.text = _address;
      if (place.category.isNotEmpty && _categories.contains(place.category)) {
        _selectedCategory = place.category;
      }
      if (place.latitude != 0 && place.longitude != 0) {
        _lat = place.latitude.toStringAsFixed(6);
        _lng = place.longitude.toStringAsFixed(6);
        _latController.text = _lat;
        _lngController.text = _lng;
        _mapKey.currentState?.flyTo(place.latitude, place.longitude, 15.5, 450);
      }
      _showSuggestions = false;
    });
  }

  void _onMapTapped(double lat, double lng) {
    final latStr = lat.toStringAsFixed(6);
    final lngStr = lng.toStringAsFixed(6);
    setState(() {
      _lat = latStr;
      _lng = lngStr;
      _latController.text = latStr;
      _lngController.text = lngStr;
    });

    _reverseGeocode(lat, lng, updateAddressField: _address.trim().isEmpty);
  }

  void _onManualCoordinateChanged() {
    final latNum = double.tryParse(_latController.text);
    final lngNum = double.tryParse(_lngController.text);
    if (latNum != null && lngNum != null) {
      setState(() {
        _lat = _latController.text;
        _lng = _lngController.text;
      });
      _mapKey.currentState?.flyTo(latNum, lngNum, null, 350);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng, {bool updateAddressField = false}) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'LangThangTravelApp/1.0',
        'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.8',
      }).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final addressObj = data['address'] as Map<String, dynamic>?;
        final displayName = data['display_name'] as String? ?? '';

        final road = addressObj?['road'] ?? addressObj?['pedestrian'] ?? addressObj?['street'] ?? '';
        final suburb = addressObj?['suburb'] ?? addressObj?['neighbourhood'] ?? addressObj?['quarter'] ?? '';
        final district = addressObj?['city_district'] ?? addressObj?['county'] ?? addressObj?['district'] ?? '';
        final city = addressObj?['city'] ?? addressObj?['province'] ?? addressObj?['state'] ?? '';

        if (city.isNotEmpty) {
          for (final prov in _allProvinces) {
            final cleanProv = prov.toLowerCase().replaceAll('tp ', '').replaceAll('tỉnh ', '').trim();
            final cleanCity = city.toLowerCase().replaceAll('tp ', '').replaceAll('thành phố ', '').replaceAll('tỉnh ', '').trim();
            if (cleanCity.contains(cleanProv) || cleanProv.contains(cleanCity)) {
              if (mounted) {
                setState(() {
                  _selectedProvince = prov;
                });
              }
              break;
            }
          }
        }

        if (updateAddressField || _address.trim().isEmpty) {
          final parts = [road, suburb, district, city].where((p) => p.trim().isNotEmpty).toList();
          final formatted = parts.isNotEmpty ? parts.join(', ') : displayName;
          if (formatted.isNotEmpty && mounted) {
            setState(() {
              _address = formatted;
              _addressController.text = formatted;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _handleGetGPSLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      // 1. Kiểm tra dịch vụ GPS của thiết bị
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Vui lòng bật định vị (GPS) trên thiết bị của bạn.'),
              backgroundColor: const Color(0xFFDC2626),
              action: SnackBarAction(
                label: 'Bật GPS',
                textColor: Colors.white,
                onPressed: () => Geolocator.openLocationSettings(),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. Kiểm tra và yêu cầu quyền truy cập vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Quyền truy cập vị trí bị từ chối. Vui lòng cấp quyền để lấy vị trí thiết bị.'),
                backgroundColor: Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Quyền vị trí bị từ chối vĩnh viễn. Vui lòng mở Cài đặt ứng dụng.'),
              backgroundColor: const Color(0xFFDC2626),
              action: SnackBarAction(
                label: 'Mở Cài đặt',
                textColor: Colors.white,
                onPressed: () => Geolocator.openAppSettings(),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 3. Lấy vị trí GPS thực tế của máy
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không nhận được tín hiệu GPS từ thiết bị. Hãy thử lại hoặc chọn trên bản đồ.'),
              backgroundColor: Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final latStr = position.latitude.toStringAsFixed(6);
      final lngStr = position.longitude.toStringAsFixed(6);

      setState(() {
        _lat = latStr;
        _lng = lngStr;
        _latController.text = latStr;
        _lngController.text = lngStr;
      });

      // Di chuyển bản đồ đến đúng vị trí thực tế của thiết bị
      _mapKey.currentState?.flyTo(position.latitude, position.longitude, 16.0, 500);

      // Giải mã địa chỉ và tỉnh thành từ tọa độ GPS thực tế của máy
      _reverseGeocode(position.latitude, position.longitude, updateAddressField: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã cập nhật vị trí GPS thiết bị: $latStr, $lngStr',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lấy vị trí thiết bị: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (picked.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(picked);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chọn ảnh: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getRegionForProvince(String province) {
    final north = ['Hà Nội', 'Hải Phòng', 'Bắc Giang', 'Bắc Kạn', 'Bắc Ninh', 'Cao Bằng', 'Điện Biên', 'Hà Giang', 'Hà Nam', 'Hải Dương', 'Hòa Bình', 'Hưng Yên', 'Lai Châu', 'Lạng Sơn', 'Lào Cai', 'Nam Định', 'Ninh Bình', 'Phú Thọ', 'Quảng Ninh', 'Sơn La', 'Thái Bình', 'Thái Nguyên', 'Tuyên Quang', 'Vĩnh Phúc', 'Yên Bái'];
    final central = ['Đà Nẵng', 'Bình Định', 'Bình Thuận', 'Đắk Lắk', 'Đắk Nông', 'Gia Lai', 'Hà Tĩnh', 'Khánh Hòa', 'Kon Tum', 'Lâm Đồng', 'Nghệ An', 'Ninh Thuận', 'Phú Yên', 'Quảng Bình', 'Quảng Nam', 'Quảng Ngãi', 'Quảng Trị', 'Thanh Hóa', 'Thừa Thiên Huế'];
    final pClean = province.replaceAll('TP ', '').trim();
    if (north.any((p) => p.toLowerCase() == pClean.toLowerCase() || p.toLowerCase().contains(pClean.toLowerCase()) || pClean.toLowerCase().contains(p.toLowerCase()))) {
      return 'Miền Bắc';
    }
    if (central.any((p) => p.toLowerCase() == pClean.toLowerCase() || p.toLowerCase().contains(pClean.toLowerCase()) || pClean.toLowerCase().contains(p.toLowerCase()))) {
      return 'Miền Trung';
    }
    return 'Miền Nam';
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_activePreviewImgIndex >= _selectedImages.length) {
        _activePreviewImgIndex = (_selectedImages.length - 1).clamp(0, 99);
      }
    });
  }

  String _formatPriceNumber(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final num = int.tryParse(clean);
    if (num == null) return raw.trim().isNotEmpty ? raw : '0';
    return num.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMsg = '');

    if (_name.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập tên địa điểm bạn muốn đề xuất.');
      if (_nameKey.currentContext != null) {
        Scrollable.ensureVisible(
          _nameKey.currentContext!,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          alignment: 0.15,
        );
      }
      _nameFocusNode.requestFocus();
      return;
    }
    if (_address.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập địa chỉ cụ thể của địa điểm hoặc chọn trên bản đồ.');
      if (_addressKey.currentContext != null) {
        Scrollable.ensureVisible(
          _addressKey.currentContext!,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          alignment: 0.15,
        );
      }
      _addressFocusNode.requestFocus();
      return;
    }
    if (_description.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng viết một vài dòng chia sẻ về điểm đặc sắc của nơi này.');
      if (_descKey.currentContext != null) {
        Scrollable.ensureVisible(
          _descKey.currentContext!,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          alignment: 0.15,
        );
      }
      _descFocusNode.requestFocus();
      return;
    }

    // Kiểm tra trạng thái đăng nhập trước khi gửi lên hệ thống
    final token = await AuthService().getAccessToken();
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!isLoggedIn || token == null || token.isEmpty) {
      final loginSuccess = await _showLoginRequiredModal();
      if (loginSuccess == true && mounted) {
        setState(() {
          _isAuthenticated = true;
          _errorMsg = '';
        });
        _handleSubmit();
      }
      return;
    }

    setState(() => _isSubmitting = true);

    final latNum = double.tryParse(_lat) ?? 21.0285;
    final lngNum = double.tryParse(_lng) ?? 105.8542;
    final hoursStr = _is24Hours ? 'Mở cửa cả ngày (24/7)' : '$_openTime – $_closeTime';
    final priceStr = _isFree ? 'Miễn phí' : '$_minPrice đ – $_maxPrice đ';

    try {
      // 1. Send contribute place with photos to backend API
      final res = await PlaceApiService().contributePlace(
        name: _name.trim(),
        category: _selectedCategory,
        region: _getRegionForProvince(_selectedProvince),
        province: _selectedProvince,
        location: _address.trim(),
        hours: hoursStr,
        price: priceStr,
        phoneNumber: _phone.trim(),
        website: _website.trim(),
        desc: _description.trim(),
        detailedDescription: _description.trim(),
        latitude: latNum,
        longitude: lngNum,
        photoFiles: _selectedImages,
      );

      // Nếu token bị hết hạn giữa chừng (401), yêu cầu đăng nhập lại mà không làm mất form
      if (!res.success && res.message.contains('UNAUTHORIZED')) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          final loginSuccess = await _showLoginRequiredModal();
          if (loginSuccess == true && mounted) {
            setState(() {
              _isAuthenticated = true;
              _errorMsg = '';
            });
            _handleSubmit();
          }
        }
        return;
      }

      // Sync created proposal to local profile cache so user sees it in their profile
      if (res.success && res.data != null) {
        final p = res.data!;
        await UserProfileApiService().saveLocalProposal(
          ProposalItemModel(
            id: p.id,
            name: p.name,
            category: p.category,
            province: p.province,
            address: p.location,
            phone: p.phoneNumber,
            website: p.website,
            openingHours: p.hours,
            priceRange: p.priceRange,
            description: p.desc,
            coverImg: p.img,
            mediaUrls: p.mediaUrls,
            status: 0,
            createdAt: 'Vừa xong',
          ),
        );
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          if (res.success) {
            _isSubmittedSuccess = true;
          } else {
            _errorMsg = res.message.isNotEmpty ? res.message : 'Không thể gửi đề xuất lúc này. Vui lòng thử lại.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMsg = 'Có lỗi xảy ra khi gửi đề xuất: $e';
        });
      }
    }
  }

  Future<bool?> _showLoginRequiredModal() async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _PreservedLoginModalSheet(
        placeName: _name.trim().isNotEmpty ? _name.trim() : 'địa điểm mới',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF059669),
            ),
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return _buildUnauthenticatedScreen();
    }

    if (_isSubmittedSuccess) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _isViewMode
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                _selectedCategory == 'Ẩm thực' ? 'Chia sẻ Quán ăn & Món ngon' : 'Đề xuất địa điểm mới',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: const Color(0xFFE2E8F0), height: 1),
              ),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;

          if (isWide) {
            return SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isViewMode) ...[
                          _buildViewModeHeaderBar(),
                          _buildRejectReasonCallout(),
                          _buildAdminNoteCallout(),
                        ] else ...[
                          _buildRewardBanner(),
                          const SizedBox(height: 16),
                        ],
                        if (_errorMsg.isNotEmpty) ...[
                          _buildErrorAlert(),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left 8 columns (Form)
                            Expanded(
                              flex: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSection1BasicInfo(),
                                  const SizedBox(height: 16),
                                  _buildSection2MapLocation(),
                                  const SizedBox(height: 16),
                                  _buildSection3HoursAndPricing(),
                                  const SizedBox(height: 16),
                                  _buildSection4PhotoUpload(),
                                  const SizedBox(height: 16),
                                  _buildSubmitBar(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right 4 columns (Sidebar Preview + Guidelines)
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionCard(
                                    title: 'Bản xem trước trực tiếp',
                                    icon: Icons.remove_red_eye_outlined,
                                    child: _buildLivePreviewCard(),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSectionCard(
                                    title: 'Quy chuẩn đóng góp địa điểm',
                                    icon: Icons.verified_user_outlined,
                                    child: _buildGuidelinesList(),
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
              ),
            );
          }

          // Mobile / Tablet Vertical Layout
          return SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isViewMode) ...[
                    _buildViewModeHeaderBar(),
                    _buildRejectReasonCallout(),
                    _buildAdminNoteCallout(),
                  ] else ...[
                    _buildRewardBanner(),
                    const SizedBox(height: 16),
                  ],
                  if (_errorMsg.isNotEmpty) ...[
                    _buildErrorAlert(),
                    const SizedBox(height: 16),
                  ],
                  _buildSection1BasicInfo(),
                  const SizedBox(height: 16),
                  _buildSection2MapLocation(),
                  const SizedBox(height: 16),
                  _buildSection3HoursAndPricing(),
                  const SizedBox(height: 16),
                  _buildSection4PhotoUpload(),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Bản xem trước trực tiếp',
                    icon: Icons.remove_red_eye_outlined,
                    child: _buildLivePreviewCard(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Quy chuẩn đóng góp địa điểm',
                    icon: Icons.verified_user_outlined,
                    child: _buildGuidelinesList(),
                  ),
                  const SizedBox(height: 16),
                  _buildSubmitBar(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== SECTION BUILDERS ====================

  Widget _buildSection1BasicInfo() {
    return _buildSectionCard(
      title: '1. Thông tin cơ bản & Thể loại',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name Field + Live Suggestions
          Container(
            key: _nameKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Tên địa điểm', isRequired: true),
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  enabled: !_isViewMode,
                  onChanged: _onNameChanged,
                  decoration: _inputDecoration(
                    hintText: 'Ví dụ: Đồi Chè Cầu Đất, Cà phê Mây Lang Thang, Bánh Mì Phượng...',
                  ),
                ),
              ],
            ),
          ),

          // Duplicate Suggestions dropdown
          if (!_isViewMode && _showSuggestions && _suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Địa điểm đã có trên hệ thống',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                        Text(
                          'Chạm để tự động điền',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                  ..._suggestions.map(
                    (p) => InkWell(
                      onTap: () => _selectSuggestion(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    p.location.isNotEmpty ? p.location : p.province,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.category,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
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
          ],

          const SizedBox(height: 14),

          // Category & Province (2 columns, matching screenshot)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Danh mục', isRequired: true),
                    DropdownButtonFormField<String>(
                      initialValue: _categories.contains(_selectedCategory) ? _selectedCategory : _categories.first,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: _isViewMode
                          ? null
                          : (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Tỉnh / Thành phố', isRequired: true),
                    DropdownButtonFormField<String>(
                      initialValue: _allProvinces.contains(_selectedProvince) ? _selectedProvince : _allProvinces.first,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: _allProvinces
                          .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: _isViewMode
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedProvince = val);
                                final coords = _getProvinceCoordinates(val);
                                if (coords != null) {
                                  setState(() {
                                    _lat = coords[0].toStringAsFixed(6);
                                    _lng = coords[1].toStringAsFixed(6);
                                    _latController.text = _lat;
                                    _lngController.text = _lng;
                                  });
                                  _mapKey.currentState?.flyTo(coords[0], coords[1], 13.0, 500);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Address detail + Live Google Maps autocomplete suggestions
          Container(
            key: _addressKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Địa chỉ chi tiết', isRequired: true),
                TextFormField(
                  controller: _addressController,
                  focusNode: _addressFocusNode,
                  enabled: !_isViewMode,
                  onChanged: _onAddressChanged,
                  onFieldSubmitted: (val) => _locateAddressOnMap(val),
                  decoration: _inputDecoration(
                    hintText: 'Số nhà, tên đường, phường/xã, quận/huyện...',
                    suffixIcon: _isLoadingAddressSuggestions
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF059669),
                              ),
                            ),
                          )
                        : (!_isViewMode && _addressController.text.isNotEmpty)
                            ? IconButton(
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  size: 18,
                                  color: Color(0xFF94A3B8),
                                ),
                                tooltip: 'Xóa địa chỉ',
                                splashRadius: 18,
                                onPressed: () {
                                  _addressController.clear();
                                  setState(() {
                                    _address = '';
                                    _addressSuggestions = [];
                                    _showAddressSuggestions = false;
                                  });
                                },
                              )
                            : null,
                  ),
                ),

                // Google Map-style Address Autocomplete Dropdown
                if (!_isViewMode && _showAddressSuggestions && _addressSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.search_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Gợi ý địa chỉ (${_addressSuggestions.length})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const Text(
                                'Chạm để tự động điền',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: _addressSuggestions.map((item) {
                                return InkWell(
                                  onTap: () => _selectAddressSuggestion(item),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2, right: 10),
                                          child: Icon(
                                            item.isHistory ? Icons.access_time_rounded : Icons.location_on_outlined,
                                            size: 18,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (item.fullAddress != item.title) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.fullAddress,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Phone & Website
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Số điện thoại liên hệ'),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_isViewMode,
                      onChanged: (val) => setState(() => _phone = val),
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        hintText: 'Ví dụ: 0263 3838 123',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Website / Fanpage'),
                    TextFormField(
                      controller: _websiteController,
                      enabled: !_isViewMode,
                      onChanged: (val) => setState(() => _website = val),
                      keyboardType: TextInputType.url,
                      decoration: _inputDecoration(
                        hintText: 'https://facebook.com/...',
                      ),
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

  Widget _buildSection2MapLocation() {
    return _buildSectionCard(
      title: '2. Vị trí trên bản đồ',
      icon: Icons.location_on_outlined,
      action: _isViewMode
          ? null
          : TextButton.icon(
              onPressed: _isLocating ? null : _handleGetGPSLocation,
              icon: _isLocating
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)))
                  : const Icon(Icons.navigation_outlined, size: 13, color: Color(0xFF059669)),
              label: Text(
                _isLocating ? 'Đang lấy GPS...' : 'Lấy vị trí GPS hiện tại của tôi',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFECFDF5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Click chuột vào bất kỳ điểm nào trên bản đồ hoặc kéo thả ghim màu xanh lá để cập nhật tọa độ chính xác.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Map Container
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Stack(
                children: [
                  MapboxInteractiveMap(
                    key: _mapKey,
                    initialLat: double.tryParse(_lat) ?? 21.0285,
                    initialLng: double.tryParse(_lng) ?? 105.8542,
                    initialZoom: 15.0,
                    onTapLatLng: _isViewMode ? null : (lat, lng) => _onMapTapped(lat, lng),
                    customMarkers: [
                      MapboxCustomMarker(
                        id: 'selected_pin',
                        latitude: double.tryParse(_lat) ?? 21.0285,
                        longitude: double.tryParse(_lng) ?? 105.8542,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _name.trim().isNotEmpty ? _name.trim() : 'Điểm đã chọn',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.place, color: Colors.white, size: 19),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Coordinate HUD badge
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pin_drop_rounded, size: 12, color: Color(0xFF34D399)),
                          const SizedBox(width: 4),
                          Text(
                            'Lat: $_lat | Lng: $_lng',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Recenter on pin button
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: InkWell(
                      onTap: () {
                        final latNum = double.tryParse(_lat) ?? 21.0285;
                        final lngNum = double.tryParse(_lng) ?? 105.8542;
                        _mapKey.currentState?.flyTo(latNum, lngNum, 16.0, 400);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.center_focus_strong_rounded, size: 18, color: Color(0xFF059669)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Coordinates Inputs
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vĩ độ (Latitude)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _latController,
                      enabled: !_isViewMode,
                      onChanged: (val) => _onManualCoordinateChanged(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(hintText: '21.028500'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kinh độ (Longitude)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _lngController,
                      enabled: !_isViewMode,
                      onChanged: (val) => _onManualCoordinateChanged(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(hintText: '105.854200'),
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

  Widget _buildSection3HoursAndPricing() {
    return _buildSectionCard(
      title: '3. Thông tin khác',
      icon: Icons.access_time_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row of 2 Subcards (Giờ mở cửa on left, Giá vé / Chi phí on right)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 550;
              final subCard1 = Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.schedule, size: 16, color: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Text('Giờ mở cửa', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _is24Hours,
                              activeColor: const Color(0xFF059669),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: _isViewMode ? null : (val) => setState(() => _is24Hours = val ?? false),
                            ),
                            const Text('Mở 24/7', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_is24Hours)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Mở cửa', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                const SizedBox(height: 3),
                                TextFormField(
                                  initialValue: _openTime,
                                  enabled: !_isViewMode,
                                  onChanged: (val) => setState(() => _openTime = val),
                                  decoration: _inputDecoration(
                                    hintText: '07:30 SA',
                                    suffixIcon: const Icon(Icons.schedule, size: 16, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Đóng cửa', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                const SizedBox(height: 3),
                                TextFormField(
                                  initialValue: _closeTime,
                                  enabled: !_isViewMode,
                                  onChanged: (val) => setState(() => _closeTime = val),
                                  decoration: _inputDecoration(
                                    hintText: '10:00 CH',
                                    suffixIcon: const Icon(Icons.schedule, size: 16, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Địa điểm đón khách liên tục cả ngày lẫn đêm.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              );

              final subCard2 = Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Text(
                              '\$',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                            ),
                            SizedBox(width: 6),
                            Text('Giá vé / Chi phí (VNĐ)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _isFree,
                              activeColor: const Color(0xFF059669),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: _isViewMode ? null : (val) => setState(() => _isFree = val ?? false),
                            ),
                            const Text('Miễn phí vé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_isFree)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Giá tối thiểu', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                const SizedBox(height: 3),
                                TextFormField(
                                  controller: _minPriceController,
                                  enabled: !_isViewMode,
                                  onChanged: (val) => setState(() => _minPrice = val),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    VndCurrencyInputFormatter(),
                                  ],
                                  decoration: _inputDecoration(
                                    hintText: '35.000',
                                    suffixText: 'đ',
                                    suffixIcon: (!_isViewMode && _minPriceController.text.isNotEmpty)
                                        ? IconButton(
                                            icon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF94A3B8)),
                                            splashRadius: 16,
                                            onPressed: () {
                                              _minPriceController.clear();
                                              setState(() => _minPrice = '');
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Giá tối đa', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                const SizedBox(height: 3),
                                TextFormField(
                                  controller: _maxPriceController,
                                  enabled: !_isViewMode,
                                  onChanged: (val) => setState(() => _maxPrice = val),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    VndCurrencyInputFormatter(),
                                  ],
                                  decoration: _inputDecoration(
                                    hintText: '120.000',
                                    suffixText: 'đ',
                                    suffixIcon: (!_isViewMode && _maxPriceController.text.isNotEmpty)
                                        ? IconButton(
                                            icon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF94A3B8)),
                                            splashRadius: 16,
                                            onPressed: () {
                                              _maxPriceController.clear();
                                              setState(() => _maxPrice = '');
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Địa điểm không thu phí vé vào cửa.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    subCard1,
                    const SizedBox(height: 12),
                    subCard2,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: subCard1),
                  const SizedBox(width: 12),
                  Expanded(child: subCard2),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          Container(
            key: _descKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Mô tả', isRequired: true),
                TextFormField(
                  controller: _descController,
                  focusNode: _descFocusNode,
                  enabled: !_isViewMode,
                  onChanged: (val) => setState(() => _description = val),
                  maxLines: 4,
                  decoration: _inputDecoration(
                    hintText: 'Chia sẻ lý do nơi này đặc biệt, món ăn nên thử, góc chụp ảnh đẹp hoặc thời điểm lý tưởng để ghé thăm...',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection4PhotoUpload() {
    final totalImages = _networkImages.length + _selectedImages.length;

    return _buildSectionCard(
      title: '4. Hình ảnh địa điểm thực tế',
      icon: Icons.image_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag & Drop / Upload Box (only in create mode)
          if (!_isViewMode) ...[
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_upload_outlined, size: 24, color: Color(0xFF059669)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tải ảnh từ thiết bị (Click hoặc kéo thả ảnh vào đây)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Hỗ trợ định dạng JPG, PNG, WEBP, JPEG',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          Text(
            'Danh sách ảnh ($totalImages)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          if (totalImages > 0)
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: totalImages,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final isNetwork = idx < _networkImages.length;
                  final isSelectedForPreview = idx == _activePreviewImgIndex;

                  return GestureDetector(
                    onTap: () => setState(() => _activePreviewImgIndex = idx),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelectedForPreview ? const Color(0xFF059669) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: isNetwork
                                ? Image.network(
                                    _networkImages[idx],
                                    width: 86,
                                    height: 86,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 86,
                                      height: 86,
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(Icons.broken_image_outlined, size: 24, color: Color(0xFF94A3B8)),
                                    ),
                                  )
                                : Image.file(
                                    File(_selectedImages[idx - _networkImages.length].path),
                                    width: 86,
                                    height: 86,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        if (idx == 0)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF065F46).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Ảnh bìa chính', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        if (!_isViewMode)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                if (isNetwork) {
                                  setState(() {
                                    _networkImages.removeAt(idx);
                                    if (_activePreviewImgIndex >= _networkImages.length + _selectedImages.length) {
                                      _activePreviewImgIndex = ((_networkImages.length + _selectedImages.length) - 1).clamp(0, 99);
                                    }
                                  });
                                } else {
                                  _removeImage(idx - _networkImages.length);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'Chưa có ảnh nào được thêm.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    final totalImages = _networkImages.length + _selectedImages.length;
    final hasImages = totalImages > 0;
    final hoursStr = _is24Hours ? '07:30 - 22:00' : '$_openTime - $_closeTime';
    final priceStr = _isFree ? 'Miễn phí' : '${_formatPriceNumber(_minPrice)} đ';

    Widget previewImgWidget;
    if (!hasImages) {
      previewImgWidget = Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 48, color: Color(0xFFCBD5E1)),
              SizedBox(height: 8),
              Text(
                'Chưa có ảnh địa điểm',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              SizedBox(height: 4),
              Text(
                'Tải ảnh lên để xem trước',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    } else if (_activePreviewImgIndex < _networkImages.length) {
      previewImgWidget = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          _networkImages[_activePreviewImgIndex],
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(child: Icon(Icons.broken_image_outlined, size: 32, color: Color(0xFF94A3B8))),
          ),
        ),
      );
    } else {
      final fileIdx = (_activePreviewImgIndex - _networkImages.length).clamp(0, _selectedImages.length - 1);
      previewImgWidget = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(_selectedImages[fileIdx].path),
          fit: BoxFit.cover,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview Cover Photo Box / Carousel
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: previewImgWidget,
            ),
            if (totalImages > 1) ...[
              // Left Arrow
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activePreviewImgIndex = (_activePreviewImgIndex == 0)
                            ? totalImages - 1
                            : _activePreviewImgIndex - 1;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
              // Right Arrow
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activePreviewImgIndex = (_activePreviewImgIndex == totalImages - 1)
                            ? 0
                            : _activePreviewImgIndex + 1;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
              // Counter Badge
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_activePreviewImgIndex + 1}/$totalImages',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 14),

        // Text info
        Text(
          _name.trim().isNotEmpty ? _name.trim() : 'Tên địa điểm đề xuất',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            const Text('5.0', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(width: 4),
            const Text('·', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text(_selectedCategory, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _address.trim().isNotEmpty ? '$_address, $_selectedProvince' : _selectedProvince,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _description.trim().isNotEmpty ? _description.trim() : 'Mô tả về địa điểm sẽ cập nhật trực tiếp tại đây...',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(hoursStr, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            Text(priceStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
          ],
        ),
      ],
    );
  }

  Widget _buildGuidelinesList() {
    return Column(
      children: [
        _buildStandardItem('Địa điểm có thật, có vị trí chính xác trên bản đồ.'),
        const SizedBox(height: 8),
        _buildStandardItem('Hình ảnh chụp thực tế rõ ràng, không chứa hình mờ quảng cáo.'),
        const SizedBox(height: 8),
        _buildStandardItem('Cung cấp mức giá và khung giờ mở cửa chính xác.'),
      ],
    );
  }

  Widget _buildSubmitBar() {
    if (_isViewMode) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Đề xuất này đang ở chế độ xem thông tin và không thể chỉnh sửa.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                elevation: 0,
              ),
              child: const Text('Quay lại', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                const Text(
                  'Bằng việc gửi đề xuất, bạn xác nhận thông tin địa điểm là chính xác và tuân thủ tiêu chuẩn cộng đồng LangThang.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _isSubmitting ? 'Đang gửi đề xuất...' : 'Gửi đề xuất địa điểm mới',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Bằng việc gửi đề xuất, bạn xác nhận thông tin địa điểm là chính xác và tuân thủ tiêu chuẩn cộng đồng LangThang.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _isSubmitting ? 'Đang gửi đề xuất...' : 'Gửi đề xuất địa điểm mới',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== VIEW MODE & SUB-COMPONENTS ====================

  Widget _buildViewModeHeaderBar() {
    if (!_isViewMode) return const SizedBox.shrink();
    final p = widget.proposal;
    final createdStr = p?.createdAt != null ? (p!.createdAt.contains('T') ? p.createdAt.split('T')[0] : p.createdAt) : 'Gần đây';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF334155), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Chi tiết địa điểm đề xuất',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(p?.status ?? 0),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mã đề xuất #${p?.id ?? ''} • Ngày gửi: $createdStr',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              backgroundColor: const Color(0xFFF8FAFC),
              foregroundColor: const Color(0xFF334155),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Quay lại', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectReasonCallout() {
    if (!_isViewMode || widget.proposal?.status != 2 || widget.proposal?.rejectReason == null || widget.proposal!.rejectReason!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text(
                'Lý do từ chối từ Ban Quản trị:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF9F1239)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              widget.proposal!.rejectReason!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNoteCallout() {
    if (!_isViewMode || widget.proposal?.adminNote == null || widget.proposal!.adminNote!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text(
                'Ghi chú từ Quản trị viên:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              widget.proposal!.adminNote!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(int status) {
    if (status == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF065F46)),
            SizedBox(width: 4),
            Text('Đã duyệt', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
          ],
        ),
      );
    }
    if (status == 2) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFE11D48)),
            SizedBox(width: 4),
            Text('Từ chối', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFE11D48))),
          ],
        ),
      );
    }
    if (status == 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFD97706)),
            SizedBox(width: 4),
            Text('Cần bổ sung', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFD97706)),
          SizedBox(width: 4),
          Text('Chờ duyệt', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
        ],
      ),
    );
  }

  // ==================== SUB-COMPONENTS ====================

  Widget _buildRewardBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Cùng xây dựng bản đồ du lịch',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  'Nhận ngay +100 điểm cống hiến uy tín cho mỗi địa điểm được phê duyệt!',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorAlert() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMsg,
              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Widget? action,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF059669)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStandardItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_rounded, size: 16, color: Color(0xFF059669)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
    TextStyle? suffixStyle,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: suffixStyle ?? const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
      ),
    );
  }

  Widget _buildUnauthenticatedScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Đề xuất địa điểm',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFEF3C7)),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFD97706), size: 32),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Yêu cầu đăng nhập tài khoản',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bạn cần đăng nhập vào tài khoản LangThang để có thể gửi đề xuất địa điểm và nhận điểm cống hiến uy tín.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.stars_rounded, size: 18, color: Color(0xFF059669)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '+100 điểm uy tín sẽ được tự động cộng vào tài khoản khi địa điểm của bạn được duyệt.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w600, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.pushNamed(context, '/login');
                            _checkAuth();
                          },
                          icon: const Icon(Icons.login_rounded, size: 16),
                          label: const Text('Đăng nhập ngay', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await Navigator.pushNamed(context, '/register');
                            _checkAuth();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Đăng ký tài khoản', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gửi đề xuất thành công!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cảm ơn bạn đã đóng góp địa điểm "$_name" cho cộng đồng LangThang. Ban kiểm duyệt sẽ xem xét và công khai địa điểm trong vòng 24 giờ.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.auto_awesome, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '+100 điểm cống hiến sẽ được cộng vào hồ sơ cá nhân ngay khi đề xuất được duyệt.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Về trang chủ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isSubmittedSuccess = false;
                              _name = '';
                              _nameController.clear();
                              _address = '';
                              _addressController.clear();
                              _description = '';
                              _descController.clear();
                              _selectedImages.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Đề xuất địa điểm khác', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bộ định dạng phân cách hàng nghìn cho tiền tệ VNĐ (ví dụ: 35000 -> 35.000)
class VndCurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Chỉ giữ lại chữ số
    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final num = int.tryParse(cleanText);
    if (num == null) return oldValue;

    // Phân cách dấu chấm hàng nghìn
    final formatted = cleanText.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Mô hình gợi ý địa chỉ Google Maps cho Address Autocomplete
class AddressSuggestion {
  final String title;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String province;
  final bool isHistory;

  const AddressSuggestion({
    required this.title,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    required this.province,
    this.isHistory = false,
  });
}

/// Modal Bottom Sheet đăng nhập nhanh giữ nguyên toàn bộ dữ liệu form đã nhập
class _PreservedLoginModalSheet extends StatefulWidget {
  final String placeName;

  const _PreservedLoginModalSheet({required this.placeName});

  @override
  State<_PreservedLoginModalSheet> createState() => _PreservedLoginModalSheetState();
}

class _PreservedLoginModalSheetState extends State<_PreservedLoginModalSheet> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String _errorText = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      final res = await AuthService().login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (res.success) {
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorText = res.message.isNotEmpty
                ? res.message
                : 'Email hoặc mật khẩu không chính xác. Vui lòng thử lại.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
      _errorText = '';
    });

    try {
      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? ApiConstants.googleClientId : null,
        scopes: const <String>['email', 'profile'],
      );

      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final account = await googleSignIn.signIn();
      if (account == null) {
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken ?? auth.accessToken ?? 'google_auth_token_${account.id}';

      final response = await AuthService().loginWithGoogle(
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        googleId: account.id,
      );

      if (mounted) {
        setState(() => _isGoogleLoading = false);
        if (response.success) {
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorText = response.message.isNotEmpty
                ? response.message
                : 'Đăng nhập Google không thành công. Vui lòng thử lại!';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _errorText = 'Lỗi xác thực Google: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        margin: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Preservation Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_added_rounded, color: Color(0xFF059669), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bản thảo của bạn đang được lưu an toàn',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                            Text(
                              'Địa điểm: "${widget.placeName}" (toàn bộ ảnh, tọa độ, mô tả vẫn giữ nguyên)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF047857),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                const Text(
                  'Đăng nhập để gửi đề xuất',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Phiên làm việc đã hết hạn. Đăng nhập lại để đề xuất được lưu trực tiếp vào cơ sở dữ liệu hệ thống.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 18),

                if (_errorText.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorText,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Email Field
                const Text('Email', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: const Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập email' : null,
                ),
                const SizedBox(height: 14),

                // Password Field
                const Text('Mật khẩu', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu của bạn',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF64748B)),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                ),
                const SizedBox(height: 20),

                // Login Submit Button
                ElevatedButton(
                  onPressed: (_isLoading || _isGoogleLoading) ? null : _handleEmailLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Đăng nhập & Tiếp tục gửi đề xuất',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 12),

                // Google Login Button
                OutlinedButton.icon(
                  onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleLogin,
                  icon: _isGoogleLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)))
                      : const Icon(Icons.g_mobiledata_rounded, size: 24, color: Color(0xFFEA4335)),
                  label: const Text('Đăng nhập bằng Google', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chưa có tài khoản? ', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.pushNamed(context, '/register');
                        final loggedIn = await AuthService().isLoggedIn();
                        if (loggedIn && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                      child: const Text(
                        'Đăng ký ngay',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../widgets/mapbox_interactive_map.dart';

class ContributePlaceScreen extends StatefulWidget {
  const ContributePlaceScreen({super.key});

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

  // State values matching ProposePlacePage.tsx
  String _name = '';
  String _selectedCategory = 'Thắng cảnh';
  String _selectedRegion = 'Miền Bắc';
  String _selectedProvince = 'Hà Nội';
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
  String _minPrice = '35000';
  String _maxPrice = '120000';

  String _description = '';
  final List<XFile> _selectedImages = [];
  int _activePreviewImgIndex = 0;

  bool _isSubmitting = false;
  bool _isSubmittedSuccess = false;
  String _errorMsg = '';

  // Live duplicate suggestion state
  bool _showSuggestions = false;
  List<PlaceModel> _suggestions = [];
  Timer? _debounceTimer;

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
    'Thắng cảnh',
    'Di tích',
    'Ẩm thực',
    'Bãi biển',
    'Cà phê',
    'Vui chơi',
    'Trải nghiệm',
    'Khách sạn & Homestay',
    'Trải nghiệm bản địa',
  ];

  final Map<String, List<String>> _provincesByRegion = {
    'Miền Bắc': [
      'Hà Nội',
      'Hà Giang',
      'Lào Cai / Sa Pa',
      'Quảng Ninh / Hạ Long',
      'Ninh Bình',
      'Cao Bằng',
      'Hải Phòng',
      'Sơn La / Mộc Châu',
      'Bắc Kạn',
      'Lạng Sơn',
      'Tuyên Quang',
      'Yên Bái',
      'Điện Biên',
      'Lai Châu',
      'Hòa Bình',
    ],
    'Miền Trung': [
      'Đà Nẵng',
      'Thừa Thiên Huế',
      'Quảng Nam / Hội An',
      'Lâm Đồng / Đà Lạt',
      'Khánh Hòa / Nha Trang',
      'Bình Định / Quy Nhơn',
      'Quảng Bình',
      'Phú Yên',
      'Nghệ An',
      'Hà Tĩnh',
      'Quảng Trị',
      'Quảng Ngãi',
      'Ninh Thuận',
      'Bình Thuận / Mũi Né',
      'Kon Tum',
      'Gia Lai',
      'Đắk Lắk',
      'Đắk Nông',
    ],
    'Miền Nam': [
      'TP. Hồ Chí Minh',
      'Kiên Giang / Phú Quốc',
      'Bà Rịa - Vũng Tàu',
      'Cần Thơ',
      'Tây Ninh',
      'An Giang',
      'Đồng Tháp',
      'Cà Mau',
      'Bình Dương',
      'Đồng Nai',
      'Bến Tre',
      'Tiền Giang',
      'Vĩnh Long',
      'Trà Vinh',
      'Sóc Trăng',
      'Bạc Liêu',
      'Hậu Giang',
    ],
  };

  @override
  void initState() {
    super.initState();
    _latController.text = _lat;
    _lngController.text = _lng;
    _minPriceController.text = _minPrice;
    _maxPriceController.text = _maxPrice;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addressObj = data['address'] as Map<String, dynamic>?;
        final displayName = data['display_name'] as String? ?? '';

        final road = addressObj?['road'] ?? addressObj?['pedestrian'] ?? addressObj?['street'] ?? '';
        final suburb = addressObj?['suburb'] ?? addressObj?['neighbourhood'] ?? addressObj?['quarter'] ?? '';
        final district = addressObj?['city_district'] ?? addressObj?['county'] ?? addressObj?['district'] ?? '';
        final city = addressObj?['city'] ?? addressObj?['province'] ?? addressObj?['state'] ?? '';

        // Auto-match province
        if (city.isNotEmpty) {
          for (final entry in _provincesByRegion.entries) {
            for (final prov in entry.value) {
              if (city.toLowerCase().contains(prov.toLowerCase()) || prov.toLowerCase().contains(city.toLowerCase())) {
                setState(() {
                  _selectedRegion = entry.key;
                  _selectedProvince = prov;
                });
                break;
              }
            }
          }
        }

        if (updateAddressField || _address.trim().isEmpty) {
          final parts = [road, suburb, district, city].where((p) => p.trim().isNotEmpty).toList();
          final formatted = parts.isNotEmpty ? parts.join(', ') : displayName;
          if (formatted.isNotEmpty) {
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
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dịch vụ vị trí (GPS) trên thiết bị chưa được bật. Vui lòng bật GPS.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Quyền truy cập vị trí GPS bị từ chối.'),
                backgroundColor: Color(0xFFDC2626),
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quyền vị trí bị từ chối vĩnh viễn. Vui lòng cấp quyền trong Cài đặt ứng dụng.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      final latStr = pos.latitude.toStringAsFixed(6);
      final lngStr = pos.longitude.toStringAsFixed(6);

      setState(() {
        _lat = latStr;
        _lng = lngStr;
        _latController.text = latStr;
        _lngController.text = lngStr;
        _isLocating = false;
      });

      _mapKey.currentState?.flyTo(pos.latitude, pos.longitude, 15.5, 500);

      await _reverseGeocode(pos.latitude, pos.longitude, updateAddressField: _address.trim().isEmpty);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã định vị thành công vị trí GPS của bạn ($latStr, $lngStr).'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lấy vị trí GPS ($e). Bạn có thể chạm trực tiếp trên bản đồ.'),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
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

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chụp ảnh: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_activePreviewImgIndex >= _selectedImages.length) {
        _activePreviewImgIndex = (_selectedImages.length - 1).clamp(0, 99);
      }
    });
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

    setState(() => _isSubmitting = true);

    final latNum = double.tryParse(_lat) ?? 21.0285;
    final lngNum = double.tryParse(_lng) ?? 105.8542;
    final hoursStr = _is24Hours ? 'Mở cửa cả ngày (24/7)' : '$_openTime – $_closeTime';
    final priceStr = _isFree ? 'Miễn phí' : '$_minPrice đ – $_maxPrice đ';
    final minPriceNum = _isFree ? 0.0 : double.tryParse(_minPrice.replaceAll(RegExp(r'[^0-9.]'), ''));
    final maxPriceNum = _isFree ? 0.0 : double.tryParse(_maxPrice.replaceAll(RegExp(r'[^0-9.]'), ''));
    final coverImgStr = _selectedImages.isNotEmpty ? _selectedImages.first.path : '';

    try {
      // 1. Send contribute place to main catalog
      final res = await PlaceApiService().contributePlace(
        name: _name.trim(),
        category: _selectedCategory,
        region: _selectedRegion,
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

      // 2. Sync proposal to user's profile proposals tab
      final proposalRes = await UserProfileApiService().createProposal(
        name: _name.trim(),
        category: _selectedCategory,
        province: _selectedProvince,
        address: _address.trim(),
        phone: _phone.trim(),
        website: _website.trim(),
        openingHours: hoursStr,
        priceRange: priceStr,
        minPrice: minPriceNum,
        maxPrice: maxPriceNum,
        description: _description.trim(),
        latitude: latNum,
        longitude: lngNum,
        coverImg: coverImgStr,
        mediaUrls: _selectedImages.map((e) => e.path).toList(),
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          if (res.success || proposalRes.success) {
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

  @override
  Widget build(BuildContext context) {
    if (_isSubmittedSuccess) {
      return _buildSuccessScreen();
    }

    final availableProvinces = _provincesByRegion[_selectedRegion] ?? [];

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
          'Đề xuất địa điểm mới',
          style: TextStyle(
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
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== REWARD BANNER (Matching ProposePlacePage.tsx) =====
              _buildRewardBanner(),
              const SizedBox(height: 16),

              // ===== ERROR ALERT (If any) =====
              if (_errorMsg.isNotEmpty) ...[
                _buildErrorAlert(),
                const SizedBox(height: 16),
              ],

              // ===== 1. BASIC INFO & CATEGORY =====
              _buildSectionCard(
                title: '1. Thông tin cơ bản & Thể loại',
                icon: Icons.article_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Field + Live Suggestions
                    Container(
                      key: _nameKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Tên địa điểm / Quán ăn / Thắng cảnh', isRequired: true),
                          TextFormField(
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            onChanged: _onNameChanged,
                            decoration: _inputDecoration(
                              hintText: 'Ví dụ: Đồi Chè Cầu Đất, Cà phê Mây Lang Thang, Bánh Mì Phượng...',
                              prefixIcon: const Icon(Icons.place_outlined, size: 18, color: Color(0xFF059669)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Duplicate Suggestions dropdown
                    if (_showSuggestions && _suggestions.isNotEmpty) ...[
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

                    // Category & Region
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Danh mục chính', isRequired: true),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                isExpanded: true,
                                decoration: _inputDecoration(),
                                items: _categories
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCategory = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Khu vực', isRequired: true),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRegion,
                                isExpanded: true,
                                decoration: _inputDecoration(),
                                items: _provincesByRegion.keys
                                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedRegion = val;
                                      final provs = _provincesByRegion[val] ?? [];
                                      if (provs.isNotEmpty) _selectedProvince = provs.first;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Province
                    _buildLabel('Tỉnh / Thành phố', isRequired: true),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedRegion),
                      initialValue: availableProvinces.contains(_selectedProvince)
                          ? _selectedProvince
                          : (availableProvinces.isNotEmpty ? availableProvinces.first : null),
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: availableProvinces
                          .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedProvince = val);
                      },
                    ),

                    const SizedBox(height: 14),

                    Container(
                      key: _addressKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Địa chỉ chi tiết', isRequired: true),
                          TextFormField(
                            controller: _addressController,
                            focusNode: _addressFocusNode,
                            onChanged: (val) => setState(() => _address = val),
                            decoration: _inputDecoration(
                              hintText: 'Số nhà, tên đường, phường/xã, quận/huyện...',
                              prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF059669)),
                            ),
                          ),
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
                              _buildLabel('Số điện thoại (tùy chọn)'),
                              TextFormField(
                                controller: _phoneController,
                                onChanged: (val) => setState(() => _phone = val),
                                keyboardType: TextInputType.phone,
                                decoration: _inputDecoration(
                                  hintText: 'Ví dụ: 0263 3838 123',
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Website / Fanpage (tùy chọn)'),
                              TextFormField(
                                controller: _websiteController,
                                onChanged: (val) => setState(() => _website = val),
                                keyboardType: TextInputType.url,
                                decoration: _inputDecoration(
                                  hintText: 'https://facebook.com/...',
                                  prefixIcon: const Icon(Icons.language_outlined, size: 16, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ===== 2. INTERACTIVE MAP SECTION =====
              _buildSectionCard(
                title: '2. Vị trí chính xác trên Bản đồ',
                icon: Icons.map_outlined,
                action: TextButton.icon(
                  onPressed: _isLocating ? null : _handleGetGPSLocation,
                  icon: _isLocating
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)))
                      : const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF059669)),
                  label: Text(
                    _isLocating ? 'Đang lấy GPS...' : 'Lấy vị trí GPS',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFECFDF5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chạm vào bản đồ hoặc nhấn "Lấy vị trí GPS" để chọn chính xác tọa độ.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    // Map Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 250,
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
                              onTapLatLng: (lat, lng) => _onMapTapped(lat, lng),
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
                                        width: 36,
                                        height: 36,
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
                                        child: const Icon(Icons.place, color: Colors.white, size: 20),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Top instruction badge
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFF059669)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Chạm bản đồ để chọn vị trí',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Coordinate badge
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
                              const Text('Vĩ độ (Latitude)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _latController,
                                onChanged: (val) => _onManualCoordinateChanged(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDecoration(hintText: '21.028500'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kinh độ (Longitude)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _lngController,
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
              ),

              const SizedBox(height: 16),

              // ===== 3. OPENING HOURS & PRICING =====
              _buildSectionCard(
                title: '3. Thời gian hoạt động & Chi phí tham quan',
                icon: Icons.access_time_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hours Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
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
                                  Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF059669)),
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
                                    onChanged: (val) => setState(() => _is24Hours = val ?? false),
                                  ),
                                  const Text('Mở 24/7', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                ],
                              ),
                            ],
                          ),
                          if (!_is24Hours) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Mở cửa', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      TextFormField(
                                        initialValue: _openTime,
                                        onChanged: (val) => setState(() => _openTime = val),
                                        decoration: _inputDecoration(hintText: '07:30'),
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
                                      const SizedBox(height: 2),
                                      TextFormField(
                                        initialValue: _closeTime,
                                        onChanged: (val) => setState(() => _closeTime = val),
                                        decoration: _inputDecoration(hintText: '22:00'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Price Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
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
                                  Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFF059669)),
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
                                    onChanged: (val) => setState(() => _isFree = val ?? false),
                                  ),
                                  const Text('Miễn phí vé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                ],
                              ),
                            ],
                          ),
                          if (!_isFree) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Giá tối thiểu', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      TextFormField(
                                        controller: _minPriceController,
                                        onChanged: (val) => setState(() => _minPrice = val),
                                        keyboardType: TextInputType.number,
                                        decoration: _inputDecoration(hintText: '35000'),
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
                                      const SizedBox(height: 2),
                                      TextFormField(
                                        controller: _maxPriceController,
                                        onChanged: (val) => setState(() => _maxPrice = val),
                                        keyboardType: TextInputType.number,
                                        decoration: _inputDecoration(hintText: '120000'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      key: _descKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Mô tả đặc sắc & Kinh nghiệm tham quan', isRequired: true),
                          TextFormField(
                            controller: _descController,
                            focusNode: _descFocusNode,
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
              ),

              const SizedBox(height: 16),

              // ===== 4. PHOTO UPLOAD SECTION =====
              _buildSectionCard(
                title: '4. Hình ảnh địa điểm thực tế',
                icon: Icons.image_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickImages,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                              ),
                              child: Column(
                                children: const [
                                  Icon(Icons.cloud_upload_outlined, size: 28, color: Color(0xFF059669)),
                                  SizedBox(height: 6),
                                  Text('Tải ảnh từ thư viện', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  SizedBox(height: 2),
                                  Text('Hỗ trợ JPG, PNG, WEBP', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _takePhoto,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Column(
                                children: const [
                                  Icon(Icons.camera_alt_outlined, size: 28, color: Color(0xFF059669)),
                                  SizedBox(height: 6),
                                  Text('Chụp ảnh trực tiếp', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  SizedBox(height: 2),
                                  Text('Từ camera điện thoại', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Danh sách ảnh đã thêm (${_selectedImages.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (ctx, idx) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(_selectedImages[idx].path),
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
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
                                      child: const Text('Ảnh bìa', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(idx),
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
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ===== 5. LIVE PREVIEW CARD =====
              _buildSectionCard(
                title: 'Bản xem trước trực tiếp',
                icon: Icons.remove_red_eye_outlined,
                child: _buildLivePreviewCard(),
              ),

              const SizedBox(height: 16),

              // ===== 6. COMMUNITY STANDARDS =====
              _buildSectionCard(
                title: 'Quy chuẩn đóng góp địa điểm',
                icon: Icons.verified_user_outlined,
                child: Column(
                  children: [
                    _buildStandardItem('Địa điểm có thật, có vị trí chính xác trên bản đồ.'),
                    const SizedBox(height: 6),
                    _buildStandardItem('Hình ảnh chụp thực tế rõ ràng, không chứa hình mờ quảng cáo.'),
                    const SizedBox(height: 6),
                    _buildStandardItem('Cung cấp mức giá và khung giờ mở cửa chính xác.'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ===== 7. SUBMIT BUTTON & TERMS =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Bằng việc gửi đề xuất, bạn xác nhận thông tin địa điểm là chính xác và tuân thủ tiêu chuẩn cộng đồng LangThang.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          _isSubmitting ? 'Đang gửi đề xuất...' : 'Gửi đề xuất địa điểm mới',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          shadowColor: const Color(0xFF059669).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          const SizedBox(width: 8),
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
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    final hasImages = _selectedImages.isNotEmpty;
    final hoursStr = _is24Hours ? 'Mở cửa 24/7' : '$_openTime – $_closeTime';
    final priceStr = _isFree ? 'Miễn phí' : '${_minPrice.trim().isNotEmpty ? _minPrice : '0'} đ';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview Cover Photo
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: hasImages
                      ? Image.file(
                          File(_selectedImages[_activePreviewImgIndex].path),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined, size: 36, color: Color(0xFF94A3B8)),
                                SizedBox(height: 4),
                                Text('Chưa có ảnh địa điểm', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              if (hasImages && _selectedImages.length > 1)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_activePreviewImgIndex + 1}/${_selectedImages.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.trim().isNotEmpty ? _name.trim() : 'Tên địa điểm đề xuất',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    const Text('5.0', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(width: 4),
                    const Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
                    const SizedBox(width: 4),
                    Text(_selectedCategory, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF059669)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        _address.trim().isNotEmpty ? '$_address, $_selectedProvince' : _selectedProvince,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _description.trim().isNotEmpty ? _description.trim() : 'Mô tả về địa điểm sẽ cập nhật trực tiếp tại đây...',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(hoursStr, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text(priceStr, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.3),
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
            fontSize: 12,
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

  InputDecoration _inputDecoration({String? hintText, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
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
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Đề xuất khác', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Xem trong Hồ sơ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

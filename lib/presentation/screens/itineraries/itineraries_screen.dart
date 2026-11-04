import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/travel_api_service.dart';
import '../../../data/services/itinerary_api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/itinerary/itinerary_catalog_card.dart';
import '../../widgets/itinerary/itinerary_quick_preview_modal.dart';
import '../auth/login_screen.dart';
import 'itinerary_detail_screen.dart';

class ItinerariesScreen extends StatefulWidget {
  final String? initialKeyword;

  const ItinerariesScreen({
    super.key,
    this.initialKeyword,
  });

  @override
  State<ItinerariesScreen> createState() => _ItinerariesScreenState();
}

class _ItinerariesScreenState extends State<ItinerariesScreen> {
  final TravelApiService _apiService = TravelApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<ItineraryModel> _allItineraries = [];
  bool _isLoading = true;

  String _selectedTheme = 'all'; // 'all', 'beach', 'mountain', 'food', 'heritage', 'relax', 'adventure', 'family'
  String _selectedDuration = 'all'; // 'all', '1', '2', '3', '4', '5'
  String _selectedBudget = 'all'; // 'all', 'under1m', '1m-3m', '3m-5m', 'above5m'
  String _selectedDestination = 'all'; // 'all' or province name
  final Set<int> _appliedItineraryIds = {};

  final List<Map<String, dynamic>> _themes = const [
    {'id': 'all', 'label': 'Tất cả', 'icon': Icons.auto_awesome_rounded},
    {'id': 'beach', 'label': 'Biển đảo', 'icon': Icons.beach_access_rounded},
    {'id': 'mountain', 'label': 'Vùng cao', 'icon': Icons.terrain_rounded},
    {'id': 'food', 'label': 'Food Tour', 'icon': Icons.restaurant_rounded},
    {'id': 'heritage', 'label': 'Di sản & Phố cổ', 'icon': Icons.temple_buddhist_rounded},
    {'id': 'relax', 'label': 'Nghỉ dưỡng', 'icon': Icons.spa_rounded},
    {'id': 'adventure', 'label': 'Phượt bụi', 'icon': Icons.two_wheeler_rounded},
    {'id': 'family', 'label': 'Gia đình', 'icon': Icons.family_restroom_rounded},
  ];

  final List<Map<String, String>> _visualDestinations = const [
    {
      'id': 'all',
      'name': 'Tất cả',
      'image': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400&h=500&fit=crop',
      'tag': 'Toàn quốc',
    },
    {
      'id': 'Đà Nẵng',
      'name': 'Đà Nẵng',
      'image': 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=400&h=500&fit=crop',
      'tag': 'Cầu Vàng & Biển',
    },
    {
      'id': 'Hà Nội',
      'name': 'Hà Nội',
      'image': 'https://images.unsplash.com/photo-1509023464722-18d996393ca8?w=400&h=500&fit=crop',
      'tag': 'Thủ đô nghìn năm',
    },
    {
      'id': 'TP. Hồ Chí Minh',
      'name': 'TP.HCM',
      'image': 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=400&h=500&fit=crop',
      'tag': 'Sôi động & Ẩm thực',
    },
    {
      'id': 'Tỉnh Lâm Đồng',
      'name': 'Đà Lạt',
      'image': 'https://images.unsplash.com/photo-1588668214407-6ea9a6d8c272?w=400&h=500&fit=crop',
      'tag': 'Xứ sở ngàn hoa',
    },
    {
      'id': 'Tỉnh Khánh Hòa',
      'name': 'Nha Trang',
      'image': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=400&h=500&fit=crop',
      'tag': 'Vịnh biển ngọc',
    },
    {
      'id': 'Kiên Giang',
      'name': 'Phú Quốc',
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&h=500&fit=crop',
      'tag': 'Đảo ngọc hoàng hôn',
    },
    {
      'id': 'Tỉnh Lào Cai',
      'name': 'Sa Pa',
      'image': 'https://images.unsplash.com/photo-1528127269322-539801943592?w=400&h=500&fit=crop',
      'tag': 'Săn mây Fansipan',
    },
    {
      'id': 'Quảng Nam',
      'name': 'Hội An',
      'image': 'https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?w=400&h=500&fit=crop',
      'tag': 'Phố đèn lồng',
    },
    {
      'id': 'Thừa Thiên Huế',
      'name': 'Huế',
      'image': 'https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=400&h=500&fit=crop',
      'tag': 'Cố đô cổ kính',
    },
    {
      'id': 'Tỉnh Ninh Bình',
      'name': 'Ninh Bình',
      'image': 'https://images.unsplash.com/photo-1570168007204-dfb528c6958f?w=400&h=500&fit=crop',
      'tag': 'Tràng An kỳ vĩ',
    },
    {
      'id': 'Tỉnh Quảng Ninh',
      'name': 'Hạ Long',
      'image': 'https://images.unsplash.com/photo-1528127269322-539801943592?w=400&h=500&fit=crop',
      'tag': 'Kỳ quan thế giới',
    },
  ];

  final List<Map<String, String>> _durations = const [
    {'id': 'all', 'label': 'Tất cả thời lượng', 'short': 'Tất cả ngày'},
    {'id': '1', 'label': '1 Ngày', 'short': '1 Ngày'},
    {'id': '2', 'label': '2 Ngày 1 Đêm (2N1Đ)', 'short': '2N1Đ'},
    {'id': '3', 'label': '3 Ngày 2 Đêm (3N2Đ)', 'short': '3N2Đ'},
    {'id': '4', 'label': '4 Ngày 3 Đêm (4N3Đ)', 'short': '4N3Đ'},
    {'id': '5', 'label': '5 Ngày trở lên (5N+)', 'short': '5N+'},
  ];

  final List<Map<String, String>> _budgets = const [
    {'id': 'all', 'label': 'Tất cả mức giá', 'short': 'Mọi mức giá'},
    {'id': 'under1m', 'label': 'Dưới 1 triệu', 'short': '< 1 triệu'},
    {'id': '1m-3m', 'label': '1 - 3 triệu', 'short': '1 - 3 triệu'},
    {'id': '3m-5m', 'label': '3 - 5 triệu', 'short': '3 - 5 triệu'},
    {'id': 'above5m', 'label': 'Trên 5 triệu', 'short': '> 5 triệu'},
  ];

  bool get _hasActiveFilters =>
      _selectedTheme != 'all' ||
      _selectedDuration != 'all' ||
      _selectedBudget != 'all' ||
      _selectedDestination != 'all' ||
      _searchController.text.trim().isNotEmpty;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedTheme != 'all') count++;
    if (_selectedDuration != 'all') count++;
    if (_selectedBudget != 'all') count++;
    if (_selectedDestination != 'all') count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  List<String> get _destinationList {
    final set = <String>{};
    final standard = [
      'Tỉnh Bắc Ninh', 'Tỉnh Cà Mau', 'Tỉnh An Giang',
      'Tỉnh Đắk Lắk', 'Tỉnh Điện Biên', 'Tỉnh Cao Bằng',
      'Tỉnh Đồng Tháp', 'Tỉnh Gia Lai', 'Tỉnh Đồng Nai',
      'Tỉnh Hưng Yên', 'Tỉnh Khánh Hòa', 'Tỉnh Hà Tĩnh',
      'Tỉnh Lạng Sơn', 'Tỉnh Lào Cai', 'Tỉnh Lai Châu',
      'Tỉnh Nghệ An', 'Tỉnh Ninh Bình', 'Tỉnh Lâm Đồng',
      'Tỉnh Quảng Ngãi', 'Tỉnh Quảng Ninh', 'Tỉnh Phú Thọ',
      'Tỉnh Sơn La', 'Tỉnh Tây Ninh', 'Tỉnh Quảng Trị',
      'Tỉnh Thanh Hóa', 'Tỉnh Tuyên Quang', 'Tỉnh Thái Nguyên',
      'Tỉnh Vĩnh Long', 'Đà Nẵng', 'Hà Nội',
      'TP. Hồ Chí Minh', 'Thừa Thiên Huế', 'Quảng Nam',
      'Kiên Giang', 'Bình Thuận'
    ];
    for (final p in standard) {
      set.add(p);
    }
    for (final it in _allItineraries) {
      if (it.destination.isNotEmpty) set.add(it.destination);
    }
    final list = set.toList();
    list.sort((a, b) => a.compareTo(b));
    return list;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword != null && widget.initialKeyword!.isNotEmpty) {
      _searchController.text = widget.initialKeyword!;
    }
    _loadItineraries();
  }

  Future<void> _checkAuthAndLoad() async {
    _loadItineraries();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadItineraries() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getItineraries(),
        _apiService.getAppliedItineraryIds(),
      ]);

      final list = results[0] as List<ItineraryModel>;
      final appliedIds = results[1] as Set<int>;

      if (mounted) {
        setState(() {
          _allItineraries = list;
          _appliedItineraryIds.addAll(appliedIds);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedTheme = 'all';
      _selectedDuration = 'all';
      _selectedBudget = 'all';
      _selectedDestination = 'all';
      _searchController.clear();
    });
  }

  List<ItineraryModel> get _filteredItineraries {
    return _allItineraries.where((item) {
      // Filter by Theme
      if (_selectedTheme != 'all') {
        final fullMeta = '${item.title} ${item.style} ${item.destination} ${item.overview ?? ''} ${item.tags.join(' ')}'.toLowerCase();
        switch (_selectedTheme) {
          case 'beach':
            if (!fullMeta.contains('biển') && !fullMeta.contains('đảo') && !fullMeta.contains('phú quốc') && !fullMeta.contains('nha trang') && !fullMeta.contains('mỹ khê') && !fullMeta.contains('hạ long')) {
              return false;
            }
            break;
          case 'mountain':
            if (!fullMeta.contains('vùng cao') && !fullMeta.contains('sa pa') && !fullMeta.contains('hà giang') && !fullMeta.contains('đà lạt') && !fullMeta.contains('fansipan') && !fullMeta.contains('núi')) {
              return false;
            }
            break;
          case 'food':
            if (!fullMeta.contains('ẩm thực') && !fullMeta.contains('food') && !fullMeta.contains('món ngon') && !fullMeta.contains('ăn vặt') && !fullMeta.contains('chợ đêm')) {
              return false;
            }
            break;
          case 'heritage':
            if (!fullMeta.contains('di sản') && !fullMeta.contains('phố cổ') && !fullMeta.contains('hội an') && !fullMeta.contains('huế') && !fullMeta.contains('hà nội') && !fullMeta.contains('văn hóa')) {
              return false;
            }
            break;
          case 'relax':
            if (!fullMeta.contains('nghỉ dưỡng') && !fullMeta.contains('resort') && !fullMeta.contains('thư giãn') && !fullMeta.contains('spa')) {
              return false;
            }
            break;
          case 'adventure':
            if (!fullMeta.contains('phượt') && !fullMeta.contains('khám phá') && !fullMeta.contains('xe máy') && !fullMeta.contains('trekking')) {
              return false;
            }
            break;
          case 'family':
            if (!fullMeta.contains('gia đình') && !fullMeta.contains('nhẹ nhàng') && !fullMeta.contains('trẻ em') && !fullMeta.contains('cuối tuần')) {
              return false;
            }
            break;
        }
      }

      // Filter by Destination
      if (_selectedDestination != 'all') {
        final dest = item.destination.toLowerCase();
        final clean = _selectedDestination
            .toLowerCase()
            .replaceAll('tỉnh ', '')
            .replaceAll('thành phố ', '')
            .replaceAll('tp. ', '')
            .trim();
        if (!dest.contains(clean)) return false;
      }

      // Filter by Duration
      if (_selectedDuration != 'all') {
        final d = item.daysCount;
        if (_selectedDuration == '1' && d != 1) return false;
        if (_selectedDuration == '2' && d != 2) return false;
        if (_selectedDuration == '3' && d != 3) return false;
        if (_selectedDuration == '4' && d != 4) return false;
        if (_selectedDuration == '5' && d < 5) return false;
      }

      // Filter by Budget
      if (_selectedBudget != 'all') {
        final costNum = item.calculatedTotalCost;
        if (_selectedBudget == 'under1m' && costNum >= 1000000) return false;
        if (_selectedBudget == '1m-3m' && (costNum < 1000000 || costNum > 3000000)) return false;
        if (_selectedBudget == '3m-5m' && (costNum < 3000000 || costNum > 5000000)) return false;
        if (_selectedBudget == 'above5m' && costNum <= 5000000) return false;
      }

      // Filter by Keyword
      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final stopDetails = item.days
            .expand((d) => d.stops)
            .map((s) => '${s.location} ${s.activity}')
            .join(' ');
        final tagText = item.tags.join(' ');
        final fullText =
            '${item.title} ${item.destination} ${item.overview ?? ''} ${item.style} ${item.author.name} $tagText $stopDetails'
                .toLowerCase();
        if (!fullText.contains(q)) return false;
      }

      return true;
    }).toList();
  }

  Future<bool> _ensureAuthenticated(String actionDescription) async {
    final token = await AuthService().getAccessToken();
    if (token != null && token.isNotEmpty) return true;

    if (!mounted) return false;
    final proceedToLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF059669), size: 24),
            SizedBox(width: 8),
            Text('Yêu cầu đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Phiên đăng nhập đã hết hạn hoặc bạn chưa đăng nhập. Vui lòng đăng nhập để $actionDescription.',
          style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF475569)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (proceedToLogin == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      _checkAuthAndLoad();
      final refreshedToken = await AuthService().getAccessToken();
      return refreshedToken != null && refreshedToken.isNotEmpty;
    }
    return false;
  }

  Future<void> _handleApplyItinerary(ItineraryModel itinerary) async {
    final clonedItinerary = itinerary.copyWith(
      id: DateTime.now().millisecondsSinceEpoch % 100000 + 100000,
      title: '${itinerary.title} (Của tôi)',
    );

    setState(() {
      _appliedItineraryIds.add(itinerary.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã mở lịch trình "${itinerary.title}". Bạn có thể tùy biến điểm dừng và bấm Lưu để xuất bản chuyến đi!',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItineraryDetailScreen(itinerary: clonedItinerary),
      ),
    ).then((_) => _checkAuthAndLoad());
  }

  Future<void> _handleCreateNewTrip() async {
    final isAuthed = await _ensureAuthenticated('tạo chuyến đi mới');
    if (!isAuthed) return;

    setState(() => _isLoading = true);
    final createdTrip = await ItineraryApiService().createNewTrip(
      title: 'Chuyến đi của tôi',
      description: 'Lên kế hoạch và lưu lại các địa điểm yêu thích.',
    );
    setState(() => _isLoading = false);

    if (createdTrip != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo chuyến đi mới #${createdTrip.id} thành công!'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItineraryDetailScreen(
            itinerary: createdTrip,
          ),
        ),
      ).then((_) => _checkAuthAndLoad());
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không thể tạo chuyến đi. Vui lòng kiểm tra lại kết nối mạng.'),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _openQuickPreview(ItineraryModel itinerary) {
    ItineraryQuickPreviewModal.show(
      context,
      itinerary: itinerary,
      onApply: () => _handleApplyItinerary(itinerary),
    );
  }

  void _showDestinationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DestinationPickerSheet(
        destinations: _destinationList,
        selectedDestination: _selectedDestination,
        onSelect: (dest) {
          setState(() => _selectedDestination = dest);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAllFiltersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AllFiltersBottomSheet(
        selectedDuration: _selectedDuration,
        selectedBudget: _selectedBudget,
        selectedDestination: _selectedDestination,
        durations: _durations,
        budgets: _budgets,
        destinations: _destinationList,
        onApply: (duration, budget, destination) {
          setState(() {
            _selectedDuration = duration;
            _selectedBudget = budget;
            _selectedDestination = destination;
          });
          Navigator.pop(context);
        },
        onReset: () {
          _resetFilters();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredItineraries;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        child: RefreshIndicator(
          color: const Color(0xFF059669),
          onRefresh: () async {
            await _checkAuthAndLoad();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // 1. Sleek Top Bar (Airbnb / Wanderlog Style)
              SliverToBoxAdapter(
                child: _buildTopBar(canPop),
              ),

              // 2. Floating Search Capsule with Tune Filter Button
              SliverToBoxAdapter(
                child: _buildSearchCapsule(),
              ),

              // 3. Category / Theme Bar (Airbnb / Klook Style Icons)
              SliverToBoxAdapter(
                child: _buildThemeCategoryBar(),
              ),

              // 4. Visual Destination Stories Carousel (Cards with Photos)
              SliverToBoxAdapter(
                child: _buildVisualDestinationsCarousel(),
              ),

              // 5. Quick Duration & Budget Pills Bar
              SliverToBoxAdapter(
                child: _buildQuickPillsBar(),
              ),

              // 6. Results Header & Active Filter Tags
              SliverToBoxAdapter(
                child: _buildResultsSummary(filteredList.length),
              ),

              // 7. Feed Content List or Empty State
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF059669)),
                  ),
                )
              else if (filteredList.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filteredList[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ItineraryCatalogCard(
                            itinerary: item,
                            isApplied: _appliedItineraryIds.contains(item.id),
                            onQuickPreview: () => _openQuickPreview(item),
                            onOpenDetail: () => _handleApplyItinerary(item),
                          ),
                        );
                      },
                      childCount: filteredList.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Bar with Logo / Title and "Tạo mới" Button
  Widget _buildTopBar(bool canPop) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (canPop) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Khám Phá Lịch Trình',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kế hoạch chi tiết từ cộng đồng xê dịch',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),

          // Primary "Tạo chuyến đi" pill button
          InkWell(
            onTap: _handleCreateNewTrip,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_rounded, size: 16, color: Color(0xFF059669)),
                  SizedBox(width: 4),
                  Text(
                    'Tạo mới',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Floating Capsule Search Bar with Integrated Filter
  Widget _buildSearchCapsule() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: Color(0xFF059669), size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Bạn muốn đi đâu? (Đà Nẵng, Sa Pa, Hà Nội...)',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Vertical separator
            Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
            const SizedBox(width: 4),

            // Tune Filter Button
            InkWell(
              onTap: _showAllFiltersModal,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 19,
                      color: _activeFilterCount > 0 ? const Color(0xFF059669) : const Color(0xFF475569),
                    ),
                    if (_activeFilterCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF059669),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// Horizontal Theme / Category Tabs Bar (Airbnb Style)
  Widget _buildThemeCategoryBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: _themes.map((theme) {
            final isSel = _selectedTheme == theme['id'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedTheme = theme['id'] as String;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        theme['icon'] as IconData,
                        size: 15,
                        color: isSel ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        theme['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Visual Destination Stories / Cards (Klook / Traveloka style)
  Widget _buildVisualDestinationsCarousel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Điểm đến truyền cảm hứng',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              InkWell(
                onTap: _showDestinationPicker,
                child: Row(
                  children: const [
                    Text(
                      'Tất cả 42 tỉnh',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF059669)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Destination Photo Cards
          SizedBox(
            height: 125,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _visualDestinations.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final dest = _visualDestinations[index];
                final isSel = _selectedDestination == dest['id'];

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDestination = isSel ? 'all' : dest['id']!;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel ? const Color(0xFF059669) : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Background Photo
                        Positioned.fill(
                          child: Image.network(
                            dest['image']!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFCBD5E1)),
                          ),
                        ),

                        // Gradient Shadow
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                                stops: const [0.35, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Selected Checkmark Pill
                        if (isSel)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF059669),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                            ),
                          ),

                        // Destination Title & Tag
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dest['name']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                dest['tag']!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Quick Duration & Budget Pills Bar
  Widget _buildQuickPillsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Duration selector
            ..._durations.map((dur) {
              final isSel = _selectedDuration == dur['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDuration = isSel ? 'all' : dur['id']!;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dur['short']!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        color: isSel ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            }),

            Container(height: 16, width: 1, color: const Color(0xFFCBD5E1), margin: const EdgeInsets.symmetric(horizontal: 4)),

            // Budget selector
            ..._budgets.where((b) => b['id'] != 'all').map((b) {
              final isSel = _selectedBudget == b['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedBudget = isSel ? 'all' : b['id']!;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      b['short']!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        color: isSel ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Results summary row & active filters
  Widget _buildResultsSummary(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Tìm thấy $count lịch trình',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    '$_activeFilterCount tiêu chí',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (_hasActiveFilters)
            InkWell(
              onTap: _resetFilters,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFE11D48)),
                    SizedBox(width: 3),
                    Text(
                      'Xóa bộ lọc',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Empty state illustration & reset button
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.explore_off_rounded, size: 40, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy chuyến đi phù hợp',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Không có lịch trình nào khớp với các tiêu chí tìm kiếm hiện tại. Thử chọn điểm đến khác hoặc đặt lại bộ lọc để khám phá toàn bộ chuyến đi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Đặt lại tất cả bộ lọc'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Destination Picker Sheet with Search Bar & Modern Tiles
class _DestinationPickerSheet extends StatefulWidget {
  final List<String> destinations;
  final String selectedDestination;
  final ValueChanged<String> onSelect;

  const _DestinationPickerSheet({
    required this.destinations,
    required this.selectedDestination,
    required this.onSelect,
  });

  @override
  State<_DestinationPickerSheet> createState() => _DestinationPickerSheetState();
}

class _DestinationPickerSheetState extends State<_DestinationPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final filtered = widget.destinations.where((d) {
      if (query.isEmpty) return true;
      return d.toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chọn Điểm Đến',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 21, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Đóng',
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _search = val),
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm tỉnh thành phố...',
                  hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // "Tất cả điểm đến" tile
          ListTile(
            onTap: () => widget.onSelect('all'),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.selectedDestination == 'all' ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.public_rounded,
                size: 19,
                color: widget.selectedDestination == 'all' ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
            ),
            title: Text(
              'Tất cả điểm đến',
              style: TextStyle(
                fontSize: 14,
                fontWeight: widget.selectedDestination == 'all' ? FontWeight.w900 : FontWeight.w600,
                color: widget.selectedDestination == 'all' ? const Color(0xFF059669) : const Color(0xFF0F172A),
              ),
            ),
            trailing: widget.selectedDestination == 'all'
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 21)
                : null,
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // List of Destinations
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
              itemBuilder: (context, index) {
                final dest = filtered[index];
                final isSel = widget.selectedDestination == dest;
                return ListTile(
                  onTap: () => widget.onSelect(dest),
                  leading: Container(
                    padding: const EdgeInsets.all(7.5),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: isSel ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                    ),
                  ),
                  title: Text(
                    dest,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w500,
                      color: isSel ? const Color(0xFF059669) : const Color(0xFF1E293B),
                    ),
                  ),
                  trailing: isSel
                      ? const Icon(Icons.check_rounded, color: Color(0xFF059669), size: 20)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// All-in-One Filter Bottom Sheet (Airbnb style)
class _AllFiltersBottomSheet extends StatefulWidget {
  final String selectedDuration;
  final String selectedBudget;
  final String selectedDestination;
  final List<Map<String, String>> durations;
  final List<Map<String, String>> budgets;
  final List<String> destinations;
  final Function(String duration, String budget, String destination) onApply;
  final VoidCallback onReset;

  const _AllFiltersBottomSheet({
    required this.selectedDuration,
    required this.selectedBudget,
    required this.selectedDestination,
    required this.durations,
    required this.budgets,
    required this.destinations,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_AllFiltersBottomSheet> createState() => _AllFiltersBottomSheetState();
}

class _AllFiltersBottomSheetState extends State<_AllFiltersBottomSheet> {
  late String _dur;
  late String _bud;
  late String _dest;

  @override
  void initState() {
    super.initState();
    _dur = widget.selectedDuration;
    _bud = widget.selectedBudget;
    _dest = widget.selectedDestination;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bộ Lọc Chuyến Đi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dur = 'all';
                      _bud = 'all';
                      _dest = 'all';
                    });
                  },
                  child: const Text(
                    'Xóa tất cả',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFE11D48)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Duration Section
                  const Text(
                    'Thời lượng chuyến đi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.durations.map((d) {
                      final isSel = _dur == d['id'];
                      return ChoiceChip(
                        label: Text(d['label']!),
                        selected: isSel,
                        onSelected: (val) => setState(() => _dur = val ? d['id']! : 'all'),
                        selectedColor: const Color(0xFF059669),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF334155),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSel ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // 2. Budget Section
                  const Text(
                    'Mức giá ước tính',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.budgets.map((b) {
                      final isSel = _bud == b['id'];
                      return ChoiceChip(
                        label: Text(b['label']!),
                        selected: isSel,
                        onSelected: (val) => setState(() => _bud = val ? b['id']! : 'all'),
                        selectedColor: const Color(0xFF059669),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF334155),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSel ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => widget.onApply(_dur, _bud, _dest),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Áp dụng bộ lọc',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

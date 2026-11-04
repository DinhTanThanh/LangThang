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

  String _selectedDuration = 'all'; // 'all', '1', '2', '3', '4', '5'
  String _selectedBudget = 'all'; // 'all', 'under1m', '1m-3m', '3m-5m', 'above5m'
  String _selectedDestination = 'all'; // 'all' or province name
  final Set<int> _appliedItineraryIds = {};

  final List<Map<String, String>> _durations = const [
    {'id': 'all', 'label': 'Tất cả thời lượng'},
    {'id': '1', 'label': '1 Ngày'},
    {'id': '2', 'label': '2 Ngày 1 Đêm (2N1Đ)'},
    {'id': '3', 'label': '3 Ngày 2 Đêm (3N2Đ)'},
    {'id': '4', 'label': '4 Ngày 3 Đêm (4N3Đ)'},
    {'id': '5', 'label': '5 Ngày trở lên (5N+)'},
  ];

  final List<Map<String, String>> _budgets = const [
    {'id': 'all', 'label': 'Tất cả mức giá'},
    {'id': 'under1m', 'label': 'Dưới 1 triệu'},
    {'id': '1m-3m', 'label': '1 - 3 triệu'},
    {'id': '3m-5m', 'label': '3 - 5 triệu'},
    {'id': 'above5m', 'label': 'Trên 5 triệu'},
  ];

  bool get _hasActiveFilters =>
      _selectedDuration != 'all' ||
      _selectedBudget != 'all' ||
      _selectedDestination != 'all' ||
      _searchController.text.trim().isNotEmpty;

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
      _selectedDuration = 'all';
      _selectedBudget = 'all';
      _selectedDestination = 'all';
      _searchController.clear();
    });
  }

  List<ItineraryModel> get _filteredItineraries {
    return _allItineraries.where((item) {
      // Filter by Destination
      if (_selectedDestination != 'all') {
        final dest = item.destination.toLowerCase();
        final clean = _selectedDestination.toLowerCase().replaceAll('tỉnh ', '').replaceAll('thành phố ', '').replaceAll('tp. ', '').trim();
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

      // Filter by Keyword (Text search across title, destination, overview, style, author, tags, stop locations & activities)
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF065F46), size: 24),
            SizedBox(width: 8),
            Text('Yêu cầu đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Phiên đăng nhập đã hết hạn hoặc bạn chưa đăng nhập. Vui lòng đăng nhập lại để $actionDescription và lưu vào cơ sở dữ liệu.',
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
              backgroundColor: const Color(0xFF064E3B),
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
    // Clone lịch trình để người dùng tự do thiết kế, chỉnh sửa điểm đến
    // Không gửi lưu trước lên server để tránh tạo bản sao chưa chỉnh sửa
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
          'Đã mở lịch trình "${itinerary.title}". Bạn có thể chỉnh sửa và bấm Lưu để đăng chuyến đi!',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF047857),
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
    final isAuthed = await _ensureAuthenticated('tạo và lên kế hoạch chuyến đi mới');
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
          content: Text('Đã tạo chuyến đi mới #${createdTrip.id} thành công vào cơ sở dữ liệu!'),
          backgroundColor: const Color(0xFF065F46),
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
          content: const Text('Không thể tạo chuyến đi vào cơ sở dữ liệu máy chủ. Vui lòng kiểm tra lại kết nối.'),
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

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredItineraries;

    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Lịch Trình Khám Phá',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 16.5, fontWeight: FontWeight.w800),
              ),
              centerTitle: true,
              actions: [
                TextButton.icon(
                  onPressed: _handleCreateNewTrip,
                  icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF047857)),
                  label: const Text(
                    'Tạo chuyến đi',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: const Color(0xFFE2E8F0), height: 1),
              ),
            )
          : null,
      body: SafeArea(
        top: !canPop,
        child: RefreshIndicator(
        color: const Color(0xFF059669),
        onRefresh: () async {
          await _checkAuthAndLoad();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Redesigned Hero Filter Card (Matching Share_Locations Screenshot)
              _buildHeroFilterCard(),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF059669)),
                  ),
                )
              else ...[
                // Results Counter & Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchController.text.trim().isNotEmpty
                            ? 'Tìm thấy ${filteredList.length} chuyến đi cho "${_searchController.text.trim()}"'
                            : 'Tìm thấy ${filteredList.length} chuyến đi',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Itinerary Cards List Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: CircularProgressIndicator(color: Color(0xFF059669)),
                          ),
                        )
                      else if (filteredList.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.explore_off_rounded, size: 44, color: Color(0xFFCBD5E1)),
                              const SizedBox(height: 12),
                              const Text(
                                'Không tìm thấy chuyến đi nào phù hợp',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Không có lịch trình nào khớp với các tiêu chí tìm kiếm hiện tại. Bạn có thể thử đặt lại bộ lọc để khám phá toàn bộ chuyến đi.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _resetFilters,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF064E3B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Đặt lại bộ lọc',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final item = filteredList[index];

                            return ItineraryCatalogCard(
                              itinerary: item,
                              isApplied: _appliedItineraryIds.contains(item.id),
                              onQuickPreview: () => _openQuickPreview(item),
                              onOpenDetail: () => _handleApplyItinerary(item),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeroFilterCard() {
    final destinations = _destinationList;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Lịch trình sẵn sàng.',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Description 1
          const Text(
            'Tham khảo kế hoạch chuyến đi chi tiết theo từng ngày, cung đường và dự toán ngân sách từ cộng đồng.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF475569),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),

          // Description 2
          const Text(
            'Áp dụng ngay lộ trình yêu thích hoặc tùy chỉnh điểm dừng để tạo nên hành trình mang đậm dấu ấn cá nhân.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Search Box with "Tìm" button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm lịch trình, địa điểm, từ khóa',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: ElevatedButton(
                    onPressed: () => setState(() {}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: const Text('Tìm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),

          // Destination Header: "Điểm đến" + "35 tỉnh thành"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Điểm đến',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Text(
                '${destinations.length} tỉnh thành',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Destination List - Scrollable container with scrollbar matching Screenshot 1
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUnderlineOption(
                      label: 'Tất cả điểm đến',
                      isSelected: _selectedDestination == 'all',
                      onTap: () => setState(() => _selectedDestination = 'all'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 7,
                      children: destinations.map((dest) {
                        return _buildUnderlineOption(
                          label: dest,
                          isSelected: _selectedDestination == dest,
                          onTap: () => setState(() => _selectedDestination = dest),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Section 1: Thời lượng chuyến đi
          const Text(
            'Thời lượng chuyến đi',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _durations.map((dur) {
                final isSel = _selectedDuration == dur['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _buildUnderlineOption(
                    label: dur['label']!,
                    isSelected: isSel,
                    onTap: () => setState(() => _selectedDuration = dur['id']!),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Section 2: Giá tiền ước tính
          const Text(
            'Giá tiền ước tính',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _budgets.map((b) {
                final isSel = _selectedBudget == b['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _buildUnderlineOption(
                    label: b['label']!,
                    isSelected: isSel,
                    onTap: () => setState(() => _selectedBudget = b['id']!),
                  ),
                );
              }).toList(),
            ),
          ),

          if (_hasActiveFilters) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFE11D48)),
                label: const Text('Đặt lại bộ lọc', style: TextStyle(fontSize: 11.5, color: Color(0xFFE11D48), fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnderlineOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          color: isSelected ? const Color(0xFF047857) : const Color(0xFF475569),
          decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
          decorationColor: const Color(0xFF047857),
          decorationThickness: 2,
        ),
      ),
    );
  }
}

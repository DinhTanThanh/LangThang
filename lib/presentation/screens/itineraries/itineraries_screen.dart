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
  final Set<int> _appliedItineraryIds = {};
  final Map<int, bool> _savedStatus = {};

  final List<Map<String, String>> _durations = const [
    {'id': 'all', 'label': 'Tất cả thời lượng'},
    {'id': '1', 'label': '1 Ngày'},
    {'id': '2', 'label': '2N1Đ'},
    {'id': '3', 'label': '3N2Đ'},
    {'id': '4', 'label': '4N3Đ'},
    {'id': '5', 'label': '5N+'},
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
      _searchController.text.trim().isNotEmpty;

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
      _searchController.clear();
    });
  }

  List<ItineraryModel> get _filteredItineraries {
    return _allItineraries.where((item) {
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

  Future<void> _handleSaveItinerary(int id) async {
    final isAuthed = await _ensureAuthenticated('lưu lịch trình yêu thích');
    if (!isAuthed) return;

    final isAlreadySaved = _savedStatus[id] ?? false;
    final willSave = !isAlreadySaved;
    setState(() {
      _savedStatus[id] = willSave;
    });

    ItineraryModel? foundItem;
    try {
      foundItem = _allItineraries.firstWhere((item) => item.id == id);
    } catch (_) {}

    await _apiService.saveItinerary(id, itinerary: foundItem, isSaving: willSave);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willSave ? 'Đã lưu lịch trình vào bộ sưu tập cá nhân!' : 'Đã bỏ lưu lịch trình.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: willSave ? const Color(0xFF047857) : const Color(0xFF374151),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
              // Hero Banner Section (Matching Share_Locations ItineraryPage.tsx)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                  ),
                ),
                child: Column(
                  children: [
                    // Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.explore_rounded, color: Color(0xFF6EE7B7), size: 13),
                          SizedBox(width: 5),
                          Text(
                            'KẾ HOẠCH DU LỊCH TỰ TÚC',
                            style: TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Main Heading
                    const Text(
                      'Lịch Trình Khám Phá Việt Nam Từng Bước',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    const Text(
                      'Các lộ trình du lịch tối ưu hóa thời gian và chi phí, kèm điểm ăn chơi, phương tiện và mẹo hữu ích cho từng ngày.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search Box (Matching Share_Locations /itinerary)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Tìm kiếm lịch trình, địa điểm, trải nghiệm...',
                                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(5),
                            child: InkWell(
                              onTap: () => setState(() {}),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF064E3B),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.search_rounded, color: Colors.white, size: 15),
                                    SizedBox(width: 5),
                                    Text(
                                      'Tìm kiếm',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 10),
                    // Create New Trip Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleCreateNewTrip,
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Tạo chuyến đi mới',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: const Color(0xFF34D399).withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF059669)),
                  ),
                )
              else ...[
                // Multi-dimensional Filter Bar Container (Matching Share_Locations ItineraryCatalogView)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(16),
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
                      // Filter Header & Reset button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.tune_rounded, size: 15, color: Color(0xFF065F46)),
                              SizedBox(width: 6),
                              Text(
                                'Bộ lọc chuyến đi',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          if (_hasActiveFilters)
                            InkWell(
                              onTap: _resetFilters,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFECDD3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.restart_alt_rounded, size: 13, color: Color(0xFFE11D48)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Đặt lại',
                                      style: TextStyle(
                                        fontSize: 11,
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
                      const SizedBox(height: 12),

                      // Duration & Budget Options Row
                      // Duration Row
                      Row(
                        children: const [
                          Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF065F46)),
                          SizedBox(width: 5),
                          Text(
                            'Thời lượng chuyến đi:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _durations.map((dur) {
                            final isSelected = _selectedDuration == dur['id'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedDuration = dur['id']!);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF065F46) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF065F46) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    dur['label']!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Budget Row
                      Row(
                        children: const [
                          Icon(Icons.payments_outlined, size: 13, color: Color(0xFF065F46)),
                          SizedBox(width: 5),
                          Text(
                            'Giá tiền ước tính:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _budgets.map((bg) {
                            final isSelected = _selectedBudget == bg['id'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedBudget = bg['id']!);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF065F46) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF065F46) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    bg['label']!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

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
                            final isSaved = _savedStatus[item.id] ?? item.isSaved;

                            return ItineraryCatalogCard(
                              itinerary: item,
                              isSaved: isSaved,
                              isApplied: _appliedItineraryIds.contains(item.id),
                              onQuickPreview: () => _openQuickPreview(item),
                              onOpenDetail: () => _handleApplyItinerary(item),
                              onToggleSave: (id) => _handleSaveItinerary(id),
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
}

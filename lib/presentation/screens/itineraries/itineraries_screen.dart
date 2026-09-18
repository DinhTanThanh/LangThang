import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/travel_api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/itinerary/itinerary_catalog_card.dart';
import '../../widgets/itinerary/itinerary_quick_preview_modal.dart';
import '../../widgets/itinerary_auth_gate.dart';
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

  bool _isAuthenticated = true;
  bool _isCheckingAuth = true;
  List<ItineraryModel> _itineraries = [];
  bool _isLoading = true;

  String _selectedRegion = 'all';
  String _selectedDuration = 'all';
  String _selectedBudget = 'all';
  final Map<int, bool> _savedStatus = {};

  final List<Map<String, String>> _regions = const [
    {'id': 'all', 'label': 'Tất cả vùng miền'},
    {'id': 'north', 'label': '🏔️ Miền Bắc'},
    {'id': 'central', 'label': '🏖️ Miền Trung'},
    {'id': 'south', 'label': '🌴 Miền Nam'},
  ];

  final List<Map<String, String>> _durations = const [
    {'id': 'all', 'label': 'Tất cả thời lượng'},
    {'id': '1_day', 'label': '⚡ 1 Ngày'},
    {'id': '2d1n', 'label': '🏖️ 2N1Đ'},
    {'id': '3d2n', 'label': '🏞️ 3N2Đ'},
    {'id': '4d3n', 'label': '✈️ 4N3Đ'},
  ];

  final List<Map<String, String>> _budgets = const [
    {'id': 'all', 'label': 'Tất cả mức giá'},
    {'id': 'under1m', 'label': 'Dưới 1 triệu'},
    {'id': '1m-3m', 'label': '1 - 3 triệu'},
    {'id': '3m-5m', 'label': '3 - 5 triệu'},
    {'id': 'above5m', 'label': 'Trên 5 triệu'},
  ];

  bool get _hasActiveFilters =>
      _selectedRegion != 'all' ||
      _selectedDuration != 'all' ||
      _selectedBudget != 'all' ||
      _searchController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword != null && widget.initialKeyword!.isNotEmpty) {
      _searchController.text = widget.initialKeyword!;
    }
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final loggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = loggedIn;
      _isCheckingAuth = false;
    });

    if (loggedIn) {
      _loadItineraries();
    } else {
      setState(() => _isLoading = false);
    }
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
      if (_isAuthenticated) {
        _loadItineraries();
      }
    });
  }

  Future<void> _loadItineraries() async {
    setState(() => _isLoading = true);
    final list = await _apiService.getItineraries(
      duration: _selectedDuration,
      keyword: _searchController.text.trim(),
      region: _selectedRegion,
      budget: _selectedBudget,
    );

    if (mounted) {
      setState(() {
        _itineraries = list;
        _isLoading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedRegion = 'all';
      _selectedDuration = 'all';
      _selectedBudget = 'all';
      _searchController.clear();
    });
    _loadItineraries();
  }

  Future<void> _handleSaveItinerary(int id) async {
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng đăng nhập để lưu lịch trình yêu thích.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Đăng nhập',
            textColor: const Color(0xFF34D399),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
              _checkAuthAndLoad();
            },
          ),
        ),
      );
      return;
    }

    final isAlreadySaved = _savedStatus[id] ?? false;
    final willSave = !isAlreadySaved;
    setState(() {
      _savedStatus[id] = willSave;
    });

    ItineraryModel? foundItem;
    try {
      foundItem = _itineraries.firstWhere((item) => item.id == id);
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

  void _openDetailScreen(ItineraryModel itinerary) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItineraryDetailScreen(
          itinerary: itinerary,
          initialIsSaved: _savedStatus[itinerary.id] ?? itinerary.isSaved,
        ),
      ),
    );
  }

  void _openQuickPreview(ItineraryModel itinerary) {
    ItineraryQuickPreviewModal.show(
      context,
      itinerary: itinerary,
      onApply: () => _openDetailScreen(itinerary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF064E3B),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Lịch Trình Khám Phá',
          style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
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

                    if (_isAuthenticated) ...[
                      const SizedBox(height: 16),
                      // Search Box
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Tìm lịch trình theo điểm đến (Đà Nẵng, Sa Pa, Hà Nội)...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF059669), size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9CA3AF)),
                                    onPressed: () {
                                      _searchController.clear();
                                      _loadItineraries();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (_isCheckingAuth)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF059669)),
                  ),
                )
              else if (!_isAuthenticated) ...[
                const SizedBox(height: 16),
                ItineraryAuthGate(
                  onAuthSuccess: _checkAuthAndLoad,
                ),
              ] else ...[
                // Multi-dimensional Filter Bar Container
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Region Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: _regions.map((reg) {
                            final isSelected = _selectedRegion == reg['id'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedRegion = reg['id']!);
                                  _loadItineraries();
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF059669) : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    reg['label']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : const Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Duration & Budget Chips Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Duration chips
                            ..._durations.map((dur) {
                              final isSelected = _selectedDuration == dur['id'];
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedDuration = dur['id']!);
                                    _loadItineraries();
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Text(
                                      dur['label']!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? const Color(0xFF065F46) : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                            // Budget chips
                            ..._budgets.where((b) => b['id'] != 'all').map((b) {
                              final isSelected = _selectedBudget == b['id'];
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedBudget = isSelected ? 'all' : b['id']!);
                                    _loadItineraries();
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFFEF3C7) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Text(
                                      b['label']!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? const Color(0xFF92400E) : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      // Reset Filters Button if Active
                      if (_hasActiveFilters) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: InkWell(
                            onTap: _resetFilters,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFF059669)),
                                SizedBox(width: 4),
                                Text(
                                  'Đặt lại bộ lọc',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE5E7EB)),

                // Itinerary List Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.explore_rounded, color: Color(0xFF059669), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Lịch Trình Đề Xuất (${_itineraries.length})',
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Lộ trình mẫu chi tiết được biên soạn bởi thổ địa và chuyên gia',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 14),

                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: CircularProgressIndicator(color: Color(0xFF059669)),
                          ),
                        )
                      else if (_itineraries.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.explore_off_rounded, size: 40, color: Color(0xFF9CA3AF)),
                              const SizedBox(height: 10),
                              const Text(
                                'Không tìm thấy lịch trình phù hợp.',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Hãy thử thay đổi vùng miền, thời lượng hoặc xóa bớt bộ lọc.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: _resetFilters,
                                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                                label: const Text('Xem tất cả lịch trình', style: TextStyle(fontSize: 12.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _itineraries.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final item = _itineraries[index];
                            final isSaved = _savedStatus[item.id] ?? item.isSaved;

                            return ItineraryCatalogCard(
                              itinerary: item,
                              isSaved: isSaved,
                              onQuickPreview: () => _openQuickPreview(item),
                              onOpenDetail: () => _openDetailScreen(item),
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
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/travel_api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/itinerary_card.dart';
import '../../widgets/itinerary_auth_gate.dart';
import '../auth/login_screen.dart';

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
  String _selectedDuration = 'all';
  int? _expandedId;
  final Map<int, bool> _savedStatus = {};

  final List<Map<String, String>> _durations = const [
    {'id': 'all', 'label': 'Tất cả thời lượng'},
    {'id': '1_day', 'label': '⚡ 1 Ngày'},
    {'id': '2d1n', 'label': '🏖️ 2 Ngày 1 Đêm'},
    {'id': '3d2n', 'label': '🏞️ 3 Ngày 2 Đêm'},
    {'id': '4d3n', 'label': '✈️ 4 Ngày 3 Đêm'},
  ];

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
    );

    if (mounted) {
      setState(() {
        _itineraries = list;
        _isLoading = false;
        if (list.isNotEmpty && (_expandedId == null || !list.any((i) => i.id == _expandedId))) {
          _expandedId = list.first.id;
        }
      });
    }
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
    setState(() {
      _savedStatus[id] = !isAlreadySaved;
    });

    await _apiService.saveItinerary(id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !isAlreadySaved
                ? 'Đã lưu lịch trình vào bộ sưu tập cá nhân!'
                : 'Đã bỏ lưu lịch trình.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: !isAlreadySaved ? const Color(0xFF047857) : const Color(0xFF374151),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
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
                // Duration Filter Chips
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _durations.map((dur) {
                        final isSelected = _selectedDuration == dur['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedDuration = dur['id']!);
                              _loadItineraries();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF059669) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                dur['label']!,
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
                                'Hãy thử thay đổi thời lượng hoặc từ khóa tìm kiếm.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _itineraries.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final item = _itineraries[index];
                            final isExpanded = _expandedId == item.id;
                            final isSaved = _savedStatus[item.id] ?? item.isSaved;

                            return ItineraryCard(
                              itinerary: item,
                              isExpanded: isExpanded,
                              isSaved: isSaved,
                              onToggleExpand: () {
                                setState(() {
                                  _expandedId = isExpanded ? null : item.id;
                                });
                              },
                              onSave: (id) => _handleSaveItinerary(id),
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

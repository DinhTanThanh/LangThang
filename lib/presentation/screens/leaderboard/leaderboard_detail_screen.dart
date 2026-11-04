import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/ranking_model.dart';
import '../../../data/services/ranking_api_service.dart';
import '../../widgets/leaderboard/destination_rank_card_widget.dart';
import '../../widgets/leaderboard/ranking_place_card_widget.dart';

class LeaderboardDetailScreen extends StatefulWidget {
  final RankingOverviewCategory category;
  final Function(int)? onNavigateTab;

  const LeaderboardDetailScreen({
    super.key,
    required this.category,
    this.onNavigateTab,
  });

  @override
  State<LeaderboardDetailScreen> createState() => _LeaderboardDetailScreenState();
}

class _LeaderboardDetailScreenState extends State<LeaderboardDetailScreen> {
  final RankingApiService _rankingApiService = RankingApiService();
  final ScrollController _scrollController = ScrollController();

  late String _currentType;
  int? _currentPlaceTypeId;
  int? _selectedProvinceId;
  int? _selectedCategoryId;
  int _currentPage = 1;
  final int _pageSize = 20;

  bool _isLoading = true;
  String? _errorMessage;
  RankingDetailViewData? _detailData;

  @override
  void initState() {
    super.initState();
    _currentType = widget.category.type;
    _currentPlaceTypeId = widget.category.placeTypeId;
    _loadDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isSpecial = _currentType == 'place' || _currentType == 'province';

    final res = await _rankingApiService.getRankingDetail(
      type: _currentType,
      placeTypeId: _currentType == 'place_type' ? (_currentPlaceTypeId ?? 1) : null,
      provinceId: !isSpecial ? _selectedProvinceId : null,
      categoryId: !isSpecial ? _selectedCategoryId : null,
      page: _currentPage,
      pageSize: _pageSize,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _detailData = res.data;
        } else {
          _errorMessage = res.message.isNotEmpty ? res.message : 'Không thể tải chi tiết xếp hạng.';
        }
      });
    }
  }

  void _onProvinceChanged(int? provinceId) {
    setState(() {
      _selectedProvinceId = provinceId;
      _currentPage = 1;
    });
    _loadDetail();
    _scrollToTop();
  }

  void _onCategoryChanged(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _currentPage = 1;
    });
    _loadDetail();
    _scrollToTop();
  }

  void _onPageChanged(int newPage) {
    setState(() {
      _currentPage = newPage;
    });
    _loadDetail();
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideFilters = _currentType == 'place' || (_currentType == 'province' && _selectedProvinceId == null);
    final isViewingProvinces = _currentType == 'province' && _selectedProvinceId == null;
    final hasContent = isViewingProvinces
        ? (_detailData?.provinceItems.isNotEmpty == true)
        : (_detailData?.items.isNotEmpty == true);

    final bannerUrl = _detailData?.header.coverImageUrl ?? widget.category.coverImageUrl;
    final headerTitle = _detailData?.header.targetName ??
        _detailData?.header.title ??
        widget.category.displayName;
    final headerSubtitle = _detailData?.header.subtitle ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. SliverAppBar with Hero Banner & Title (Unpinned so it scrolls off cleanly)
              SliverAppBar(
                expandedHeight: 220,
                pinned: false,
                floating: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (bannerUrl != null && bannerUrl.isNotEmpty)
                    Image.network(
                      bannerUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0F172A)),
                    )
                  else
                    Container(color: const Color(0xFF0F172A)),

                  // Dark gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),

                  // Title & Subtitle at bottom
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          headerTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                        if (headerSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            headerSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.9),
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
          ),

          // 2. Filter Bar
          if (!hideFilters)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phạm vi Dropdown
                    Row(
                      children: [
                        const Text(
                          'PHẠM VI:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _selectedProvinceId,
                              isDense: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Toàn quốc'),
                                ),
                                ...(_detailData?.availableProvinces.map((prov) {
                                      return DropdownMenuItem<int?>(
                                        value: prov.id,
                                        child: Text(prov.name),
                                      );
                                    }) ??
                                    []),
                              ],
                              onChanged: _onProvinceChanged,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Subcategory Pill Filters
                    if (_detailData?.subCategories.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSubCategoryPill(
                              title: 'Tất cả',
                              isSelected: _selectedCategoryId == null,
                              onTap: () => _onCategoryChanged(null),
                            ),
                            const SizedBox(width: 8),
                            ...(_detailData!.subCategories.map((sub) {
                              final isSelected = _selectedCategoryId == sub.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildSubCategoryPill(
                                  title: sub.name,
                                  isSelected: isSelected,
                                  onTap: () => _onCategoryChanged(sub.id),
                                ),
                              );
                            })),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                  ],
                ),
              ),
            ),

          // 3. Body: Content / Loading / Error
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF059669)),
                    SizedBox(height: 12),
                    Text(
                      'Đang nạp dữ liệu chi tiết...',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null && !hasContent)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFD97706)),
                      const SizedBox(height: 12),
                      const Text(
                        'Không thể tải dữ liệu xếp hạng',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadDetail,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Thử lại'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (!hasContent)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        isViewingProvinces
                            ? 'Chưa có dữ liệu xếp hạng tỉnh thành.'
                            : 'Không tìm thấy địa điểm nào phù hợp.',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Hãy thử chọn tỉnh thành hoặc danh mục con khác.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // List of items
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (isViewingProvinces) {
                      final item = _detailData!.provinceItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DestinationRankCardWidget(
                          destination: item,
                          onSelectProvince: _onProvinceChanged,
                        ),
                      );
                    } else {
                      final item = _detailData!.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: RankingPlaceCardWidget(place: item),
                      );
                    }
                  },
                  childCount: isViewingProvinces
                      ? _detailData!.provinceItems.length
                      : _detailData!.items.length,
                ),
              ),
            ),

            // Pagination Controls
            if (_detailData != null && _detailData!.totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Trang ${_detailData!.page} / ${_detailData!.totalPages} (${_detailData!.totalCount} ${isViewingProvinces ? 'tỉnh thành' : 'địa điểm'})',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _detailData!.page > 1
                                  ? () => _onPageChanged(_detailData!.page - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left_rounded, size: 16),
                              label: const Text('Trước', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _detailData!.page < _detailData!.totalPages
                                  ? () => _onPageChanged(_detailData!.page + 1)
                                  : null,
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(Icons.chevron_right_rounded, size: 16),
                              label: const Text('Sau', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),

          // Floating adaptive back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, _) {
                final isScrolled = _scrollController.hasClients && _scrollController.offset > 120;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isScrolled
                            ? Colors.white
                            : Colors.black.withValues(alpha: 0.45),
                        boxShadow: isScrolled
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: isScrolled ? const Color(0xFF0F172A) : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildSubCategoryPill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

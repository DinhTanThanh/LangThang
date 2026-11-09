import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/place_filter_dto.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/device_context_service.dart';
import '../../widgets/place_card_grid.dart';
import '../../widgets/place_card_list.dart';
import '../../widgets/filter_bottom_sheet.dart';
import 'place_detail_screen.dart';
import 'contribute_place_screen.dart';

enum ViewMode { grid, list }

class DestinationsScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialRegion;
  final String? initialProvince;
  final String? initialCategory;
  final int? initialCategoryId;

  const DestinationsScreen({
    super.key,
    this.initialSearchQuery,
    this.initialRegion,
    this.initialProvince,
    this.initialCategory,
    this.initialCategoryId,
  });

  @override
  State<DestinationsScreen> createState() => DestinationsScreenState();
}

class DestinationsScreenState extends State<DestinationsScreen> {
  final PlaceApiService _placeApiService = PlaceApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  Timer? _suggestionDebounceTimer;

  List<PlaceModel> _filteredPlaces = [];
  List<PlaceModel> _dbPlaceSuggestions = [];
  bool _isFetchingSuggestions = false;
  PlaceFilterOptionsDto? _filterOptions;
  int _totalElements = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _showSuggestions = false;

  ViewMode _viewMode = ViewMode.grid;
  String _sortOption = 'popular_desc';

  final List<Map<String, String>> _sortOptions = [
    {'label': 'Được đề xuất hàng đầu', 'value': 'popular_desc'},
    {'label': 'Đánh giá cao nhất', 'value': 'rating_desc'},
    {'label': 'Nhiều lượt đánh giá nhất', 'value': 'reviews_desc'},
    {'label': 'Giá: Thấp đến cao', 'value': 'price_asc'},
    {'label': 'Giá: Cao đến thấp', 'value': 'price_desc'},
    {'label': 'Mới nhất', 'value': 'newest'},
  ];

  final List<String> _trendingSuggestions = [
    'Hà Nội',
    'Đà Nẵng',
    'Sa Pa',
    'Hội An',
    'Phú Quốc',
    'Hạ Long',
    'Đà Lạt',
    'Cà phê trứng',
  ];

  late FilterCriteria _filterCriteria;

  @override
  void initState() {
    super.initState();
    _filterCriteria = FilterCriteria(
      regions: widget.initialRegion != null && widget.initialRegion != 'Tất cả'
          ? [widget.initialRegion!]
          : [],
      provinces: widget.initialProvince != null && widget.initialProvince != 'Tất cả'
          ? [widget.initialProvince!]
          : [],
      category: widget.initialCategory,
      categoryId: widget.initialCategoryId,
    );
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
    }

    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus;
      });
    });

    _scrollController.addListener(_onScroll);

    _initLoad();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      if (!_isLoading && !_isLoadingMore && _currentPage < _totalPages) {
        _loadMorePlaces();
      }
    }
  }

  void applySearch({String? query, String? region, String? category, int? categoryId}) {
    _searchController.text = query ?? '';
    setState(() {
      _filterCriteria = FilterCriteria(
        regions: region != null && region != 'Tất cả' ? [region] : [],
        category: category,
        categoryId: categoryId,
      );
      if (_filterOptions != null) {
        if (region != null && region != 'Tất cả') {
          final foundReg = _filterOptions!.regions.firstWhere(
            (r) => r.name.toLowerCase().contains(region.toLowerCase()),
            orElse: () => const RegionLookupDto(id: 0, name: '', provinces: []),
          );
          if (foundReg.id > 0) {
            _filterCriteria.regionIds = [foundReg.id];
          }
        }
        if (category != null && _filterCriteria.categoryId == null) {
          final foundCat = _filterOptions!.categories.firstWhere(
            (c) => c.name.toLowerCase().contains(category.toLowerCase()),
            orElse: () => const LookupItemDto(id: 0, name: ''),
          );
          if (foundCat.id > 0) {
            _filterCriteria.categoryId = foundCat.id;
            _filterCriteria.category = foundCat.name;
          }
        }
      }
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    _fetchPlaces();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _suggestionDebounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    // 1. Fetch filter options from API
    final optRes = await _placeApiService.getFilterOptions();
    if (mounted && optRes.data != null) {
      setState(() {
        _filterOptions = optRes.data;
        // Resolve initial region to ID if provided
        if (widget.initialRegion != null && widget.initialRegion != 'Tất cả') {
          final foundReg = _filterOptions!.regions.firstWhere(
            (r) => r.name.toLowerCase().contains(widget.initialRegion!.toLowerCase()),
            orElse: () => const RegionLookupDto(id: 0, name: '', provinces: []),
          );
          if (foundReg.id > 0) {
            _filterCriteria.regionIds = [foundReg.id];
          }
        }
        // Resolve initial category to ID if provided
        if (widget.initialCategory != null && _filterCriteria.categoryId == null) {
          final foundCat = _filterOptions!.categories.firstWhere(
            (c) => c.name.toLowerCase().contains(widget.initialCategory!.toLowerCase()),
            orElse: () => const LookupItemDto(id: 0, name: ''),
          );
          if (foundCat.id > 0) {
            _filterCriteria.categoryId = foundCat.id;
            _filterCriteria.category = foundCat.name;
          }
        }
      });
    }

    // 2. Fetch places from API
    await _fetchPlaces();
  }

  PlaceFilterParams _buildFilterParams({required int page}) {
    double? minPrice;
    double? maxPrice;
    if (_filterCriteria.priceTier == 1) {
      minPrice = 0;
      maxPrice = 0;
    } else if (_filterCriteria.priceTier == 2) {
      minPrice = 1;
      maxPrice = 100000;
    } else if (_filterCriteria.priceTier == 3) {
      minPrice = 100000;
      maxPrice = 500000;
    } else if (_filterCriteria.priceTier == 4) {
      minPrice = 500000;
      maxPrice = 50000000;
    }

    return PlaceFilterParams(
      keyword: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      categoryId: _filterCriteria.categoryId,
      regionId: _filterCriteria.regionIds.isNotEmpty ? _filterCriteria.regionIds.first : null,
      provinceId: _filterCriteria.provinceIds.isNotEmpty ? _filterCriteria.provinceIds.first : null,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minRating: _filterCriteria.minRating > 0 ? _filterCriteria.minRating : null,
      sortBy: _sortOption,
      page: page,
      pageSize: 12,
    );
  }

  Future<void> _fetchPlaces() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    final params = _buildFilterParams(page: 1);
    final res = await _placeApiService.searchPlaces(params);

    if (mounted) {
      setState(() {
        _filteredPlaces = res.data ?? [];
        _totalElements = res.meta?.totalElements ?? _filteredPlaces.length;
        _totalPages = res.meta?.totalPages ?? 1;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePlaces() async {
    if (_isLoadingMore || _currentPage >= _totalPages) return;

    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    final params = _buildFilterParams(page: nextPage);
    final res = await _placeApiService.searchPlaces(params);

    if (mounted) {
      setState(() {
        if (res.data != null && res.data!.isNotEmpty) {
          _filteredPlaces.addAll(res.data!);
          _currentPage = nextPage;
          _totalElements = res.meta?.totalElements ?? _filteredPlaces.length;
          _totalPages = res.meta?.totalPages ?? _totalPages;
        }
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _fetchPlaces();
    });

    _suggestionDebounceTimer?.cancel();
    final query = value.trim();
    if (query.isNotEmpty) {
      setState(() {
        _isFetchingSuggestions = true;
      });
      _suggestionDebounceTimer = Timer(const Duration(milliseconds: 250), () {
        _fetchDbSuggestions(query);
      });
    } else {
      setState(() {
        _dbPlaceSuggestions = [];
        _isFetchingSuggestions = false;
      });
    }
  }

  Future<void> _fetchDbSuggestions(String query) async {
    if (query.isEmpty) return;
    try {
      final res = await _placeApiService.searchPlaces(PlaceFilterParams(
        keyword: query,
        page: 1,
        pageSize: 6,
      ));
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _dbPlaceSuggestions = res.data ?? [];
          _isFetchingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingSuggestions = false;
        });
      }
    }
  }

  List<String> _getCategoryAndProvinceSuggestions() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty || _filterOptions == null) return [];
    final List<String> matches = [];

    for (final reg in _filterOptions!.regions) {
      for (final prov in reg.provinces) {
        if (prov.name.toLowerCase().contains(q) && !matches.contains(prov.name)) {
          matches.add(prov.name);
        }
      }
    }

    for (final cat in _filterOptions!.categories) {
      if (cat.name.toLowerCase().contains(q) && !matches.contains(cat.name)) {
        matches.add(cat.name);
      }
    }

    return matches.take(4).toList();
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FilterBottomSheet(
          initialCriteria: _filterCriteria,
          filterOptions: _filterOptions,
          onApply: (newCriteria) {
            setState(() {
              _filterCriteria = newCriteria;
              _currentPage = 1;
            });

            // Ghi nhận tín hiệu ngữ cảnh tìm kiếm vào DeviceContextService
            if (newCriteria.categoryId != null && newCriteria.categoryId! > 0) {
              DeviceContextService().recordCategoryInterest(newCriteria.categoryId!, scoreToAdd: 3);
            }
            if (newCriteria.provinceIds.isNotEmpty) {
              for (final pid in newCriteria.provinceIds) {
                LookupItemDto? foundProv;
                for (final reg in _filterOptions?.regions ?? <RegionLookupDto>[]) {
                  for (final prov in reg.provinces) {
                    if (prov.id == pid) {
                      foundProv = prov;
                      break;
                    }
                  }
                  if (foundProv != null) break;
                }
                if (foundProv != null && foundProv.id > 0) {
                  DeviceContextService().recordSearchIntent(
                    provinceId: foundProv.id,
                    provinceName: foundProv.name,
                    scoreToAdd: 3,
                  );
                }
              }
            }

            _fetchPlaces();
          },
        );
      },
    );
  }
  void _openSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sắp xếp kết quả',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              ..._sortOptions.map((opt) {
                final isSelected = _sortOption == opt['value'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _sortOption = opt['value']!;
                      _currentPage = 1;
                    });
                    _fetchPlaces();
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          opt['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF047857) : const Color(0xFF334155),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, size: 18, color: Color(0xFF047857)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _resetAllFilters() {
    setState(() {
      _filterCriteria.reset();
      _searchController.clear();
      _currentPage = 1;
    });
    _fetchPlaces();
  }

  @override
  Widget build(BuildContext context) {
    final activeChips = _buildActiveFilterChips();
    final sortLabel = _sortOptions.firstWhere(
      (s) => s['value'] == _sortOption,
      orElse: () => _sortOptions.first,
    )['label']!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContributePlaceScreen(
                initialCategory: _filterCriteria.category,
                initialProvince: _filterCriteria.provinces.isNotEmpty ? _filterCriteria.provinces.first : null,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF047857),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_location_alt_rounded, size: 20),
        label: const Text(
          'Đề xuất địa điểm',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.2),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            if (_searchFocusNode.hasFocus) {
              _searchFocusNode.unfocus();
            }
          },
          child: Column(
            children: [
              // 1. Search Bar Header (ExploreSearchBar style)
              _buildSearchBarHeader(),

              // 2. Active Filter Chips Bar (ExploreActiveChips style)
              if (activeChips.isNotEmpty) _buildActiveChipsSection(activeChips),

              // 3. Toolbar Bar (ExploreToolbar style)
              _buildToolbar(sortLabel),

              // 4. Content Area
              Expanded(
                child: Stack(
                  children: [
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          )
                        : _filteredPlaces.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: _fetchPlaces,
                                color: AppColors.primary,
                                child: _viewMode == ViewMode.grid
                                    ? _buildGridView()
                                    : _buildListView(),
                              ),

                    // Suggestions Overlay Dropdown from Database & Categories/Provinces
                    if (_showSuggestions) _buildSuggestionsOverlay(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SUGGESTIONS OVERLAY ====================
  Widget _buildSuggestionsOverlay() {
    final query = _searchController.text.trim();
    final catProvMatches = _getCategoryAndProvinceSuggestions();
    final hasNoResults = query.isNotEmpty && !_isFetchingSuggestions && _dbPlaceSuggestions.isEmpty && catProvMatches.isEmpty;

    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // If query is empty -> Show trending keywords
                  if (query.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: Row(
                        children: const [
                          Icon(Icons.trending_up, size: 16, color: Color(0xFF047857)),
                          SizedBox(width: 6),
                          Text(
                            'ĐIỂM ĐẾN PHỔ BIẾN & THỊNH HÀNH',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _trendingSuggestions.map((item) {
                          return InkWell(
                            onTap: () {
                              _searchController.text = item;
                              _searchFocusNode.unfocus();
                              _fetchPlaces();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    item,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ] else ...[
                    // When user types query:
                    // 1. Loading state
                    if (_isFetchingSuggestions)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: const [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Đang tìm kiếm trong cơ sở dữ liệu...',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),

                    // 2. Database Place Suggestions
                    if (_dbPlaceSuggestions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                        child: Row(
                          children: const [
                            Icon(Icons.place_rounded, size: 16, color: Color(0xFF047857)),
                            SizedBox(width: 6),
                            Text(
                              'ĐỊA ĐIỂM TỪ DATABASE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ..._dbPlaceSuggestions.map((place) {
                        return InkWell(
                          onTap: () {
                            _searchFocusNode.unfocus();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlaceDetailScreen(
                                  place: place,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                // Thumbnail Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    color: const Color(0xFFE2E8F0),
                                    child: place.img.isNotEmpty
                                        ? Image.network(
                                            place.img,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                              Icons.image_not_supported,
                                              size: 20,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          )
                                        : const Icon(Icons.location_on, size: 22, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title & Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        place.name,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (place.rating > 0) ...[
                                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                            const SizedBox(width: 2),
                                            Text(
                                              place.rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                                            const SizedBox(width: 6),
                                          ],
                                          Expanded(
                                            child: Text(
                                              place.location.isNotEmpty
                                                  ? place.location
                                                  : (place.province.isNotEmpty ? place.province : place.category),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Fill search button
                                IconButton(
                                  icon: const Icon(Icons.north_west_rounded, size: 16, color: Color(0xFF94A3B8)),
                                  tooltip: 'Điền vào thanh tìm kiếm',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    _searchController.text = place.name;
                                    _searchFocusNode.unfocus();
                                    _fetchPlaces();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    // 3. Category & Province suggestions
                    if (catProvMatches.isNotEmpty) ...[
                      if (_dbPlaceSuggestions.isNotEmpty) const Divider(height: 8, color: Color(0xFFF1F5F9)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                        child: Row(
                          children: const [
                            Icon(Icons.explore_outlined, size: 16, color: Color(0xFF047857)),
                            SizedBox(width: 6),
                            Text(
                              'TỈNH THÀNH & DANH MỤC LIÊN QUAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...catProvMatches.map((item) {
                        return InkWell(
                          onTap: () {
                            _searchController.text = item;
                            _searchFocusNode.unfocus();
                            _fetchPlaces();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.search, size: 15, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 8),
                                    Text(
                                      item,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.north_west, size: 14, color: Color(0xFF94A3B8)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    // 4. Empty State
                    if (hasNoResults)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Không tìm thấy địa điểm nào khớp với "$query" trong cơ sở dữ liệu.',
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
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
      ),
    );
  }

  // ==================== SEARCH BAR HEADER ====================
  Widget _buildSearchBarHeader() {
    final canPop = Navigator.canPop(context);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(canPop ? 6 : 16, 12, 16, 12),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
              tooltip: 'Quay lại',
              onPressed: () => Navigator.pop(context),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      keyboardType: TextInputType.text,
                      autocorrect: true,
                      enableSuggestions: true,
                      onSubmitted: (_) {
                        _searchFocusNode.unfocus();
                        _fetchPlaces();
                      },
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'Tìm địa điểm, tỉnh thành, món ăn...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        setState(() {
                          _dbPlaceSuggestions = [];
                          _isFetchingSuggestions = false;
                        });
                        _searchController.clear();
                        _fetchPlaces();
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        _searchFocusNode.unfocus();
                        _fetchPlaces();
                      },
                      child: const Text(
                        'Tìm kiếm',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
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

  // ==================== ACTIVE CHIPS SECTION ====================
  Widget _buildActiveChipsSection(List<Widget> chips) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'ĐANG LỌC:',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: chips),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _resetAllFilters,
              child: const Text(
                'Xóa tất cả',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE11D48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActiveFilterChips() {
    final chips = <Widget>[];

    if (_searchController.text.trim().isNotEmpty) {
      chips.add(_buildActiveChip(
        label: '"${_searchController.text.trim()}"',
        onDeleted: () {
          _searchController.clear();
          _fetchPlaces();
        },
      ));
    }

    if (_filterCriteria.category != null && _filterCriteria.category!.isNotEmpty) {
      chips.add(_buildActiveChip(
        label: _filterCriteria.category!,
        onDeleted: () {
          setState(() {
            _filterCriteria.categoryId = null;
            _filterCriteria.category = null;
            _currentPage = 1;
          });
          _fetchPlaces();
        },
      ));
    }

    for (final reg in List<String>.from(_filterCriteria.regions)) {
      chips.add(_buildActiveChip(
        label: reg,
        onDeleted: () {
          setState(() {
            _filterCriteria.regions.remove(reg);
            if (_filterOptions != null) {
              final regObj = _filterOptions!.regions.firstWhere(
                (r) => r.name == reg,
                orElse: () => const RegionLookupDto(id: 0, name: '', provinces: []),
              );
              if (regObj.id > 0) _filterCriteria.regionIds.remove(regObj.id);
            }
            _currentPage = 1;
          });
          _fetchPlaces();
        },
      ));
    }

    for (final prov in List<String>.from(_filterCriteria.provinces)) {
      chips.add(_buildActiveChip(
        label: prov,
        onDeleted: () {
          setState(() {
            _filterCriteria.provinces.remove(prov);
            if (_filterOptions != null) {
              for (final r in _filterOptions!.regions) {
                final pObj = r.provinces.firstWhere(
                  (p) => p.name == prov,
                  orElse: () => const LookupItemDto(id: 0, name: ''),
                );
                if (pObj.id > 0) _filterCriteria.provinceIds.remove(pObj.id);
              }
            }
            _currentPage = 1;
          });
          _fetchPlaces();
        },
      ));
    }

    if (_filterCriteria.priceTier > 0) {
      final tierLabels = ['Tất cả', 'Miễn phí', '< 100k', '100k - 500k', '> 500k'];
      chips.add(_buildActiveChip(
        label: tierLabels[_filterCriteria.priceTier],
        onDeleted: () {
          setState(() {
            _filterCriteria.priceTier = 0;
            _currentPage = 1;
          });
          _fetchPlaces();
        },
      ));
    }

    if (_filterCriteria.minRating > 0) {
      chips.add(_buildActiveChip(
        label: '★ ${_filterCriteria.minRating}+',
        onDeleted: () {
          setState(() {
            _filterCriteria.minRating = 0;
            _currentPage = 1;
          });
          _fetchPlaces();
        },
      ));
    }

    return chips;
  }

  Widget _buildActiveChip({required String label, required VoidCallback onDeleted}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF065F46),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDeleted,
            child: const Icon(Icons.close, size: 13, color: Color(0xFF047857)),
          ),
        ],
      ),
    );
  }

  // ==================== TOOLBAR SECTION ====================
  Widget _buildToolbar(String sortLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total Places Found (Wrapped in Expanded to prevent overflow)
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                text: '',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                children: [
                  TextSpan(
                    text: '$_totalElements',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const TextSpan(text: ' địa điểm'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Actions: Sort + Filter + ViewMode
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sort Trigger
              InkWell(
                onTap: _openSortBottomSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          sortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Filter Trigger
              InkWell(
                onTap: _openFilterBottomSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _filterCriteria.activeCount > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _filterCriteria.activeCount > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 13,
                        color: _filterCriteria.activeCount > 0 ? const Color(0xFF047857) : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _filterCriteria.activeCount > 0 ? '(${_filterCriteria.activeCount})' : 'Lọc',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _filterCriteria.activeCount > 0 ? const Color(0xFF047857) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // ViewMode Switcher
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewModeButton(ViewMode.grid, Icons.grid_view_rounded),
                    _buildViewModeButton(ViewMode.list, Icons.view_list_rounded),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(ViewMode mode, IconData icon) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 15,
          color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  // ==================== LIST / GRID VIEWS ====================
  Widget _buildGridView() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final place = _filteredPlaces[index];
                return PlaceCardGrid(
                  place: place,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaceDetailScreen(place: place),
                      ),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                  onToggleSave: (saved) {
                    setState(() {
                      _filteredPlaces[index] = place.copyWith(isSaved: saved);
                    });
                    if (saved) {
                      PlaceApiService().savePlace(place.id, place: place);
                    } else {
                      PlaceApiService().unsavePlace(place.id);
                    }
                  },
                );
              },
              childCount: _filteredPlaces.length,
            ),
          ),
        ),
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else if (_filteredPlaces.length < _totalElements)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _loadMorePlaces,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF059669)),
                  label: Text(
                    'Xem thêm địa điểm (${_filteredPlaces.length}/$_totalElements)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListView() {
    final hasMore = _filteredPlaces.length < _totalElements;
    final extraCount = (_isLoadingMore || hasMore) ? 1 : 0;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPlaces.length + extraCount,
      itemBuilder: (context, index) {
        if (index == _filteredPlaces.length) {
          if (_isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _loadMorePlaces,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF059669)),
                label: Text(
                  'Xem thêm địa điểm (${_filteredPlaces.length}/$_totalElements)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          );
        }
        final place = _filteredPlaces[index];
        return PlaceCardList(
          place: place,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaceDetailScreen(place: place),
              ),
            ).then((_) {
              if (mounted) setState(() {});
            });
          },
          onToggleSave: (saved) {
            setState(() {
              _filteredPlaces[index] = place.copyWith(isSaved: saved);
            });
            if (saved) {
              PlaceApiService().savePlace(place.id, place: place);
            } else {
              PlaceApiService().unsavePlace(place.id);
            }
          },
        );
      },
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.explore_off_outlined, size: 36, color: Color(0xFF047857)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không tìm thấy địa điểm nào',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy thử thay đổi từ khóa tìm kiếm hoặc bỏ bớt các tiêu chí lọc.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.restart_alt, size: 16, color: Colors.white),
              label: const Text(
                'Đặt lại bộ lọc',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/favorite_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/blog_model.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/favorite_api_service.dart';
import '../../screens/destinations/place_detail_screen.dart';
import '../../screens/itineraries/itinerary_detail_screen.dart';
import '../../screens/blog/blog_detail_screen.dart';

class FavoritesSectionWidget extends StatefulWidget {
  final VoidCallback? onFavoriteChanged;

  const FavoritesSectionWidget({
    super.key,
    this.onFavoriteChanged,
  });

  @override
  State<FavoritesSectionWidget> createState() => _FavoritesSectionWidgetState();
}

class _FavoritesSectionWidgetState extends State<FavoritesSectionWidget> {
  final FavoriteApiService _favoriteService = FavoriteApiService();

  List<FavoriteItemModel> _allFavorites = [];
  bool _isLoading = true;

  FavoriteTargetType _selectedTab = FavoriteTargetType.all;
  String _searchQuery = '';
  String _sortBy = 'newest'; // 'newest', 'rating', 'name'
  bool _isGridView = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    FavoriteApiService.favoritesNotifier.addListener(_onGlobalFavoritesChanged);
  }

  void _onGlobalFavoritesChanged() {
    if (mounted) {
      _loadFavorites();
    }
  }

  @override
  void dispose() {
    FavoriteApiService.favoritesNotifier.removeListener(_onGlobalFavoritesChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final res = await _favoriteService.getFavorites();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _allFavorites = res.data!.items;
        }
      });
    }
  }

  Future<void> _removeFavorite(FavoriteItemModel item) async {
    final removedIndex = _allFavorites.indexOf(item);
    setState(() {
      _allFavorites.removeWhere((f) => f.targetType == item.targetType && f.targetId == item.targetId);
    });

    final res = await _favoriteService.removeFavorite(
      targetType: item.targetType,
      targetId: item.targetId,
    );

    if (!res.success) {
      if (mounted) {
        setState(() {
          if (removedIndex >= 0 && removedIndex <= _allFavorites.length) {
            _allFavorites.insert(removedIndex, item);
          } else {
            _allFavorites.add(item);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'Không thể bỏ lưu mục này.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    widget.onFavoriteChanged?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã bỏ lưu "${item.title}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Hoàn tác',
          textColor: Colors.amber,
          onPressed: () async {
            setState(() {
              if (removedIndex >= 0 && removedIndex <= _allFavorites.length) {
                _allFavorites.insert(removedIndex, item);
              } else {
                _allFavorites.add(item);
              }
            });
            await _favoriteService.addFavorite(
              targetType: item.targetType,
              targetId: item.targetId,
              title: item.title,
              subtitle: item.subtitle,
              coverImg: item.coverImg,
              categoryTag: item.categoryTag,
              rating: item.rating,
              reviewCount: item.reviewCount,
              price: item.price,
            );
            widget.onFavoriteChanged?.call();
          },
        ),
      ),
    );
  }

  void _navigateToDetail(FavoriteItemModel item) async {
    if (item.targetType == 1 || item.targetType == 2) {
      // Địa điểm / Ẩm thực -> PlaceDetailScreen
      final place = PlaceModel(
        id: item.targetId,
        name: item.title,
        category: item.categoryTag.isNotEmpty ? item.categoryTag : (item.targetType == 2 ? 'Ẩm thực & Cafe' : 'Danh lam thắng cảnh'),
        location: item.subtitle,
        region: 'Miền Bắc',
        province: item.subtitle,
        type: item.targetType == 2 ? 'Ẩm thực' : 'Điểm tham quan',
        rating: item.rating,
        reviews: item.reviewCount,
        price: item.price ?? 'Miễn phí',
        priceMax: 0,
        priceRange: item.price ?? 'Miễn phí',
        hours: '07:30 – 22:00',
        status: 'Đang mở cửa',
        desc: item.subtitle,
        detailedDescription: item.subtitle,
        phoneNumber: '',
        website: '',
        img: item.coverImg,
        mediaUrls: item.mediaUrls.isNotEmpty ? item.mediaUrls : [item.coverImg],
        latitude: 21.0285,
        longitude: 105.8542,
        tags: [item.categoryTag],
        amenities: const [],
        isSaved: true,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PlaceDetailScreen(place: place)),
      );
      _loadFavorites();
    } else if (item.targetType == 3) {
      // Hành trình -> Mở trực tiếp màn hình chi tiết lịch trình ItineraryDetailScreen
      final itinerary = ItineraryModel(
        id: item.targetId,
        title: item.title,
        destination: item.subtitle.isNotEmpty ? item.subtitle : 'Việt Nam',
        region: 'Việt Nam',
        duration: 'Lộ trình khám phá',
        daysCount: 1,
        nightsCount: 0,
        style: item.categoryTag.isNotEmpty ? item.categoryTag : 'Khám phá',
        coverUrl: item.coverImg,
        isSaved: true,
        author: const ItineraryAuthorModel(
          name: 'Tác giả',
          avatar: '',
        ),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItineraryDetailScreen(
            itinerary: itinerary,
            initialIsSaved: true,
          ),
        ),
      );
      _loadFavorites();
    } else if (item.targetType == 4) {
      // Bài viết -> Mở trực tiếp màn hình đọc bài viết BlogDetailScreen
      final blog = BlogModel(
        id: item.targetId.toString(),
        title: item.title,
        summary: item.subtitle,
        category: item.categoryTag.isNotEmpty ? item.categoryTag : 'Cẩm nang',
        imageUrl: item.coverImg,
        author: const BlogAuthorModel(name: 'Tác giả', role: 'Thổ địa', rank: 'Blogger'),
        publishedDate: item.savedDate.isNotEmpty ? item.savedDate : 'Vừa xong',
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BlogDetailScreen(blog: blog)),
      );
      _loadFavorites();
    }
  }

  List<FavoriteItemModel> _getFilteredFavorites() {
    var list = _allFavorites.where((item) {
      final matchesTab = _selectedTab == FavoriteTargetType.all || item.targetType == _selectedTab.value;
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query) ||
          item.categoryTag.toLowerCase().contains(query);
      return matchesTab && matchesSearch;
    }).toList();

    if (_sortBy == 'rating') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'name') {
      list.sort((a, b) => a.title.compareTo(b.title));
    }

    return list;
  }

  int _getCountForType(FavoriteTargetType type) {
    if (type == FavoriteTargetType.all) return _allFavorites.length;
    return _allFavorites.where((f) => f.targetType == type.value).length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredFavorites();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Header Section =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Địa điểm & Mục đã lưu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_allFavorites.length} mục đã lưu trong tài khoản của bạn',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _loadFavorites,
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                      tooltip: 'Làm mới',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ===== Category Pills (All, Place, Food, Itinerary, Blog) =====
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: FavoriteTargetType.values.map((type) {
                      final isSelected = _selectedTab == type;
                      final count = _getCountForType(type);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = type),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  type.icon,
                                  size: 14,
                                  color: isSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  type.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF047857) : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF047857) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                                    ),
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
                const SizedBox(height: 14),

                // ===== Search, Sort & View Mode Switcher =====
                Row(
                  children: [
                    // Search Box
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Tìm trong mục đã lưu...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 9),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort Menu
                    PopupMenuButton<String>(
                      initialValue: _sortBy,
                      onSelected: (val) => setState(() => _sortBy = val),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              _sortBy == 'rating'
                                  ? 'Đánh giá'
                                  : _sortBy == 'name'
                                      ? 'A-Z'
                                      : 'Mới nhất',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'newest',
                          child: Text('Mới lưu gần đây', style: TextStyle(fontSize: 12)),
                        ),
                        const PopupMenuItem(
                          value: 'rating',
                          child: Text('Đánh giá cao nhất', style: TextStyle(fontSize: 12)),
                        ),
                        const PopupMenuItem(
                          value: 'name',
                          child: Text('Theo tên A - Z', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),

                    // Grid / List View Toggle
                    Container(
                      height: 38,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          _buildViewToggleBtn(
                            icon: Icons.grid_view_rounded,
                            isSelected: _isGridView,
                            onTap: () => setState(() => _isGridView = true),
                          ),
                          _buildViewToggleBtn(
                            icon: Icons.view_list_rounded,
                            isSelected: !_isGridView,
                            onTap: () => setState(() => _isGridView = false),
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

          // ===== Content Body =====
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
              ),
            )
          else if (filtered.isEmpty)
            _buildEmptyState()
          else if (_isGridView)
            _buildGridView(filtered)
          else
            _buildListView(filtered),
        ],
      ),
    );
  }

  Widget _buildViewToggleBtn({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.favorite_border_rounded, size: 28, color: Color(0xFFE11D48)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Không tìm thấy mục đã lưu nào',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hãy khám phá các địa điểm, món ăn, lịch trình hoặc bài viết trên LangThang để lưu lại cho chuyến đi của bạn!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }

  // ===== Grid View (2-column layout) =====
  Widget _buildGridView(List<FavoriteItemModel> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildGridCard(item);
          },
        );
      },
    );
  }

  Widget _buildGridCard(FavoriteItemModel item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Thumbnail & Remove Heart Button
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        item.coverImg,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: Icon(item.targetTypeEnum.icon, color: const Color(0xFF94A3B8), size: 32),
                        ),
                      ),
                    ),
                    // Category Tag Top Left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.categoryTag.isNotEmpty ? item.categoryTag : item.targetTypeEnum.label,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    // Unsave Bookmark/Favorite Button Top Right
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: item.targetType == 4 ? const Color(0xFF047857) : Colors.black45,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _removeFavorite(item),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              item.targetType == 4 ? Icons.bookmark_rounded : Icons.favorite_rounded,
                              color: item.targetType == 4 ? Colors.white : const Color(0xFFF43F5E),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Card Information
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        if (item.reviewCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${item.reviewCount})',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ],
                    ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== List View (Horizontal card layout) =====
  Widget _buildListView(List<FavoriteItemModel> items) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToDetail(item),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 78,
                        height: 78,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              item.coverImg,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFFF1F5F9),
                                child: Icon(item.targetTypeEnum.icon, color: const Color(0xFF94A3B8), size: 24),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  item.targetTypeEnum.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (item.subtitle.isNotEmpty)
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 2),
                              Text(
                                item.rating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              if (item.price != null && item.price!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.price!,
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                  ),
                                ),
                              ],
                              if (item.savedDate.isNotEmpty) ...[
                                const Spacer(),
                                Text(
                                  item.savedDate,
                                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Remove Button (Bookmark icon for blogs, Favorite icon for others)
                    IconButton(
                      icon: Icon(
                        item.targetType == 4 ? Icons.bookmark_rounded : Icons.favorite_rounded,
                        color: item.targetType == 4 ? const Color(0xFF047857) : const Color(0xFFF43F5E),
                        size: 20,
                      ),
                      tooltip: item.targetType == 4 ? 'Bỏ lưu bài viết' : 'Bỏ lưu',
                      onPressed: () => _removeFavorite(item),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

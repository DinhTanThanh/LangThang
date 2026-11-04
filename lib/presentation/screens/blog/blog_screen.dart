import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/blog_model.dart';
import '../../../data/services/blog_api_service.dart';
import '../../widgets/blog/blog_card_widget.dart';
import '../../widgets/blog/blog_detail_modal.dart';
import 'blog_detail_screen.dart';
import 'blog_editor_screen.dart';

class BlogScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialSearchQuery;

  const BlogScreen({
    super.key,
    this.initialCategory,
    this.initialSearchQuery,
  });

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  final BlogApiService _blogService = BlogApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<BlogModel> _blogs = [];
  bool _isLoading = true;
  int _displayCount = 9;

  String _selectedCategory = 'all';

  final List<Map<String, dynamic>> _categoryTabs = const [
    {'id': 'all', 'label': 'Tất cả', 'icon': Icons.auto_awesome_rounded},
    {'id': 'Nhà hàng & Quán ăn', 'label': 'Ẩm thực', 'icon': Icons.restaurant_rounded},
    {'id': 'Cà phê & Tráng miệng', 'label': 'Cà phê', 'icon': Icons.coffee_rounded},
    {'id': 'Danh lam thắng cảnh', 'label': 'Danh lam', 'icon': Icons.landscape_rounded},
    {'id': 'Homestay & Farmstay', 'label': 'Homestay', 'icon': Icons.cottage_rounded},
    {'id': 'Khách sạn & Resort', 'label': 'Resort', 'icon': Icons.hotel_rounded},
    {'id': 'Di tích & Tâm linh', 'label': 'Di tích', 'icon': Icons.temple_buddhist_rounded},
    {'id': 'Đặc sản & Quà lưu niệm', 'label': 'Đặc sản', 'icon': Icons.card_giftcard_rounded},
    {'id': 'Chợ & Phố đi bộ', 'label': 'Phố đi bộ', 'icon': Icons.storefront_rounded},
    {'id': 'Khu vui chơi giải trí', 'label': 'Vui chơi', 'icon': Icons.attractions_rounded},
    {'id': 'Khu sinh thái & Nông trại', 'label': 'Sinh thái', 'icon': Icons.eco_rounded},
    {'id': 'Villa & Hostel', 'label': 'Villa', 'icon': Icons.villa_rounded},
  ];

  final List<String> _allCategoryNames = const [
    'Đặc sản & Quà lưu niệm',
    'Homestay & Farmstay',
    'Khu vui chơi giải trí',
    'Villa & Hostel',
    'Cà phê & Tráng miệng',
    'Danh lam thắng cảnh',
    'Khách sạn & Resort',
    'Nhà hàng & Quán ăn',
    'Chợ & Phố đi bộ',
    'Di tích & Tâm linh',
    'Khu sinh thái & Nông trại',
    'Thiên nhiên & Sinh thái',
  ];

  bool get _hasActiveFilters =>
      _selectedCategory != 'all' ||
      _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null &&
        widget.initialCategory!.isNotEmpty &&
        widget.initialCategory != 'all' &&
        widget.initialCategory != 'Tất cả' &&
        widget.initialCategory != 'Tất cả danh mục') {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
    }
    _loadBlogs();
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
      _loadBlogs();
    });
  }

  Future<void> _loadBlogs() async {
    setState(() => _isLoading = true);

    final categoryParam = _selectedCategory != 'all' ? _selectedCategory : null;

    final list = await _blogService.getBlogs(
      category: categoryParam,
      keyword: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
    );

    List<BlogModel> filteredList = list;
    if (_selectedCategory != 'all') {
      final selectedLower = _selectedCategory.toLowerCase();
      filteredList = list.where((b) {
        final bCat = b.category.toLowerCase();
        return bCat.contains(selectedLower) || selectedLower.contains(bCat);
      }).toList();
    }

    if (mounted) {
      setState(() {
        _blogs = filteredList;
        _displayCount = 9;
        _isLoading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'all';
      _searchController.clear();
    });
    _loadBlogs();
  }

  void _toggleLike(BlogModel blog) async {
    final nowLiked = await _blogService.toggleLike(blog);
    setState(() {
      final index = _blogs.indexWhere((b) => b.id == blog.id);
      if (index != -1) {
        _blogs[index] = _blogs[index].copyWith(
          isLiked: nowLiked,
          likesCount: nowLiked
              ? _blogs[index].likesCount + 1
              : (_blogs[index].likesCount > 0 ? _blogs[index].likesCount - 1 : 0),
        );
      }
    });
  }

  void _toggleSave(BlogModel blog) async {
    final nowSaved = await _blogService.toggleSave(blog);
    setState(() {
      final index = _blogs.indexWhere((b) => b.id == blog.id);
      if (index != -1) {
        _blogs[index] = _blogs[index].copyWith(isSaved: nowSaved);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowSaved ? 'Đã lưu bài viết vào mục yêu thích!' : 'Đã bỏ lưu bài viết.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: nowSaved ? const Color(0xFF047857) : const Color(0xFF334155),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openBlogDetail(BlogModel blog) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BlogDetailScreen(blog: blog)),
    ).then((_) => _loadBlogs());
  }

  void _openBlogEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BlogEditorScreen(onPublished: _loadBlogs)),
    ).then((val) {
      if (val == true) _loadBlogs();
    });
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryPickerSheet(
        categories: _allCategoryNames,
        selectedCategory: _selectedCategory,
        onSelect: (cat) {
          setState(() => _selectedCategory = cat);
          _loadBlogs();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleArticles = _blogs.take(_displayCount).toList();
    final hasMore = visibleArticles.length < _blogs.length;
    final canPop = Navigator.canPop(context);

    // Filter featured stories for the highlight carousel (only when in "all" tab and no query)
    final isHomeState = _selectedCategory == 'all' && _searchController.text.trim().isEmpty;
    final trendingBlogs = isHomeState ? _blogs.take(4).toList() : <BlogModel>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        child: RefreshIndicator(
          color: const Color(0xFF059669),
          onRefresh: _loadBlogs,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // 1. Top Bar with "Viết bài" button
              SliverToBoxAdapter(
                child: _buildTopBar(canPop),
              ),

              // 2. Floating Search Capsule
              SliverToBoxAdapter(
                child: _buildSearchCapsule(),
              ),

              // 3. Horizontal Category Tabs (Airbnb / Medium Style)
              SliverToBoxAdapter(
                child: _buildCategoryTabsBar(),
              ),

              // 4. Trending Highlights Carousel (Only in home state)
              if (trendingBlogs.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildTrendingCarousel(trendingBlogs),
                ),

              // 5. Results Counter & Active Filter Pills
              SliverToBoxAdapter(
                child: _buildResultsSummary(_blogs.length),
              ),

              // 6. Blog Feed Content or Empty State
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF059669)),
                  ),
                )
              else if (_blogs.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final b = visibleArticles[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: BlogCardWidget(
                            blog: b,
                            onTap: () => _openBlogDetail(b),
                            onQuickPreview: () => BlogDetailModal.show(
                              context,
                              blog: b,
                              onToggleLike: () => _toggleLike(b),
                              onToggleSave: () => _toggleSave(b),
                            ),
                            onToggleLike: () => _toggleLike(b),
                            onToggleSave: () => _toggleSave(b),
                          ),
                        );
                      },
                      childCount: visibleArticles.length,
                    ),
                  ),
                ),

              // 7. Load more button
              if (!_isLoading && hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _displayCount += 6;
                          });
                        },
                        icon: const Icon(Icons.expand_more_rounded, size: 18),
                        label: const Text(
                          'Xem thêm bài viết',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF059669),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Bar with Title and "Viết bài" CTA
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
                    'Cẩm Nang Du Lịch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Bí quyết & Góc nhìn chân thực từ cộng đồng',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),

          // Viết bài CTA button
          InkWell(
            onTap: _openBlogEditor,
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
                  Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF059669)),
                  SizedBox(width: 4),
                  Text(
                    'Viết bài',
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

  /// Floating Capsule Search Bar
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
                onSubmitted: (_) => _loadBlogs(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Tìm cẩm nang, ẩm thực, kinh nghiệm...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchController.clear();
                            _loadBlogs();
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Vertical divider
            Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
            const SizedBox(width: 4),

            // Category picker trigger
            InkWell(
              onTap: _showCategoryPicker,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 19,
                      color: _selectedCategory != 'all' ? const Color(0xFF059669) : const Color(0xFF475569),
                    ),
                    if (_selectedCategory != 'all') ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF059669),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '1',
                          style: TextStyle(
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

  /// Horizontal Category Chips Bar (Airbnb / Medium Style)
  Widget _buildCategoryTabsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: _categoryTabs.map((tab) {
            final isSel = _selectedCategory == tab['id'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = tab['id'] as String;
                  });
                  _loadBlogs();
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
                        tab['icon'] as IconData,
                        size: 15,
                        color: isSel ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab['label'] as String,
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

  /// Trending Stories Carousel (Highlight Horizontal Cards)
  Widget _buildTrendingCarousel(List<BlogModel> trending) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '🔥 Cẩm nang thịnh hành',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Trending Cards
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: trending.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final b = trending[index];
                final coverUrl = b.imageUrl.isNotEmpty ? b.imageUrl : 'https://images.unsplash.com/photo-1528127269322-539801943592?w=600&h=400&fit=crop';

                return InkWell(
                  onTap: () => _openBlogDetail(b),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Cover Photo
                        Positioned.fill(
                          child: Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFCBD5E1)),
                          ),
                        ),

                        // Gradient
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                                stops: const [0.2, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Category & Reading Time (Top)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              b.category.isNotEmpty ? b.category : 'Cẩm nang',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                        // Title & Author (Bottom)
                        Positioned(
                          bottom: 8,
                          left: 10,
                          right: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                b.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    b.authorName.isNotEmpty ? b.authorName : 'Tác giả',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '• ${b.readTimeMinutes} phút đọc',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
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

  /// Results summary row & active filter indicators
  Widget _buildResultsSummary(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Khám phá $count bài viết',
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
                    _selectedCategory != 'all' ? _selectedCategory : 'Đang lọc',
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
            child: const Icon(Icons.auto_stories_rounded, size: 40, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy cẩm nang phù hợp',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Không có bài viết nào khớp với từ khóa hoặc danh mục đã chọn. Thử tìm với từ khóa khác hoặc đặt lại bộ lọc để khám phá toàn bộ cẩm nang.',
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
            label: const Text('Đặt lại bộ lọc'),
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

/// Category Picker BottomSheet with Search & Selection Tiles
class _CategoryPickerSheet extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelect;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final filtered = widget.categories.where((c) {
      if (query.isEmpty) return true;
      return c.toLowerCase().contains(query);
    }).toList();

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
                  'Chọn Danh Mục Cẩm Nang',
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
                  hintText: 'Tìm kiếm chủ đề, danh mục...',
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

          // "Tất cả danh mục" tile
          ListTile(
            onTap: () => widget.onSelect('all'),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.selectedCategory == 'all' ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.category_rounded,
                size: 19,
                color: widget.selectedCategory == 'all' ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
            ),
            title: Text(
              'Tất cả danh mục',
              style: TextStyle(
                fontSize: 14,
                fontWeight: widget.selectedCategory == 'all' ? FontWeight.w900 : FontWeight.w600,
                color: widget.selectedCategory == 'all' ? const Color(0xFF059669) : const Color(0xFF0F172A),
              ),
            ),
            trailing: widget.selectedCategory == 'all'
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 21)
                : null,
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // List of Categories
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
              itemBuilder: (context, index) {
                final cat = filtered[index];
                final isSel = widget.selectedCategory == cat;
                return ListTile(
                  onTap: () => widget.onSelect(cat),
                  leading: Container(
                    padding: const EdgeInsets.all(7.5),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      size: 17,
                      color: isSel ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                    ),
                  ),
                  title: Text(
                    cat,
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

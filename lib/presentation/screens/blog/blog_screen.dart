import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/blog_model.dart';
import '../../../data/services/blog_api_service.dart';
import '../../widgets/blog/blog_featured_card.dart';
import '../../widgets/blog/blog_card_widget.dart';
import '../../widgets/blog/blog_detail_modal.dart';
import 'blog_detail_screen.dart';
import 'blog_editor_screen.dart';

class BlogScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialRegion;

  const BlogScreen({
    super.key,
    this.initialCategory,
    this.initialRegion,
  });

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  final BlogApiService _blogService = BlogApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<BlogModel> _blogs = [];
  BlogModel? _featuredBlog;
  bool _isLoading = true;

  String _selectedRegion = 'all';
  String? _selectedProvince;
  String _selectedCategory = 'all';

  final List<Map<String, String>> _regions = const [
    {'id': 'all', 'label': 'Tất cả vùng miền'},
    {'id': 'north', 'label': '🏔️ Miền Bắc'},
    {'id': 'central', 'label': '🏖️ Miền Trung'},
    {'id': 'south', 'label': '🌴 Miền Nam'},
  ];

  final Map<String, List<String>> _provincesByRegion = const {
    'all': ['Hà Nội', 'Sa Pa', 'Ninh Bình', 'Hà Giang', 'Hội An', 'Đà Nẵng', 'Huế', 'Đà Lạt', 'TP. Hồ Chí Minh', 'Cần Thơ', 'Phú Quốc'],
    'north': ['Hà Nội', 'Hà Giang', 'Sa Pa', 'Ninh Bình', 'Quảng Ninh'],
    'central': ['Đà Nẵng', 'Hội An', 'Huế', 'Đà Lạt', 'Nha Trang', 'Quy Nhơn'],
    'south': ['TP. Hồ Chí Minh', 'Cần Thơ', 'Phú Quốc', 'An Giang', 'Vũng Tàu'],
  };

  final List<String> _categories = const [
    'Tất cả',
    'Di tích lịch sử - Văn hóa',
    'Ẩm thực & Quán xá',
    'Cảnh quan thiên nhiên',
    'Làng nghề truyền thống',
    'Kinh nghiệm du lịch',
    'Check-in sống ảo',
  ];

  bool get _hasActiveFilters =>
      _selectedRegion != 'all' ||
      _selectedProvince != null ||
      _selectedCategory != 'all' ||
      _searchController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialRegion != null) {
      _selectedRegion = widget.initialRegion!;
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
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadBlogs();
    });
  }

  Future<void> _loadBlogs() async {
    setState(() => _isLoading = true);

    final list = await _blogService.getBlogs(
      category: _selectedCategory != 'all' ? _selectedCategory : null,
      keyword: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      region: _selectedRegion != 'all' ? _selectedRegion : null,
      province: _selectedProvince,
    );

    BlogModel? feat;
    try {
      feat = list.firstWhere((b) => b.featured, orElse: () => list.first);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _blogs = list;
        _featuredBlog = feat;
        _isLoading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedRegion = 'all';
      _selectedProvince = null;
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
          likesCount: nowLiked ? _blogs[index].likesCount + 1 : (_blogs[index].likesCount > 0 ? _blogs[index].likesCount - 1 : 0),
        );
      }
      if (_featuredBlog?.id == blog.id) {
        _featuredBlog = _featuredBlog!.copyWith(
          isLiked: nowLiked,
          likesCount: nowLiked ? _featuredBlog!.likesCount + 1 : (_featuredBlog!.likesCount > 0 ? _featuredBlog!.likesCount - 1 : 0),
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
      if (_featuredBlog?.id == blog.id) {
        _featuredBlog = _featuredBlog!.copyWith(isSaved: nowSaved);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowSaved ? 'Đã lưu bài viết vào mục yêu thích!' : 'Đã bỏ lưu bài viết.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: nowSaved ? const Color(0xFF047857) : const Color(0xFF374151),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF064E3B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cẩm nang du lịch',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.white, size: 20),
            tooltip: 'Viết bài chia sẻ',
            onPressed: _openBlogEditor,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBlogs,
        color: const Color(0xFF059669),
        child: CustomScrollView(
          slivers: [
            // Hero Banner Section (Matching BlogFeedView.tsx)
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF064E3B), Color(0xFF047857)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFF6EE7B7)),
                          SizedBox(width: 5),
                          Text(
                            'CẨM NANG & BẢN SẮC VIỆT',
                            style: TextStyle(
                              color: Color(0xFFD1FAE5),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Hành trình khám phá đất nước',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Kinh nghiệm du lịch tự túc, ẩm thực đường phố và những câu chuyện văn hóa chân thực từ cộng đồng Thổ Địa.',
                      style: TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search Bar Inside Hero
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
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Tìm cẩm nang, địa danh, món ăn...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF059669), size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadBlogs();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Multi-Filter Bar (Regions, Provinces, Categories, Reset)
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                            child: FilterChip(
                              label: Text(
                                reg['label']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF059669),
                              backgroundColor: const Color(0xFFF3F4F6),
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedRegion = selected ? reg['id']! : 'all';
                                  _selectedProvince = null;
                                });
                                _loadBlogs();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Province Chips (All popular provinces or Region-specific provinces)
                    if (_provincesByRegion[_selectedRegion] != null && _provincesByRegion[_selectedRegion]!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Tỉnh thành: ',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
                            ),
                            ..._provincesByRegion[_selectedRegion]!.map((prov) {
                              final isSelected = _selectedProvince == prov;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(
                                    prov,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? const Color(0xFF065F46) : const Color(0xFF374151),
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFFD1FAE5),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  onSelected: (sel) {
                                    setState(() => _selectedProvince = sel ? prov : null);
                                    _loadBlogs();
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == (cat == 'Tất cả' ? 'all' : cat);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() => _selectedCategory = (cat == 'Tất cả' ? 'all' : cat));
                                _loadBlogs();
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF047857) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Reset Filter Bar
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tìm thấy ${_blogs.length} bài viết',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                            ),
                            TextButton.icon(
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFFEF4444)),
                              label: const Text('Đặt lại bộ lọc', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

            const SliverToBoxAdapter(child: Divider(height: 1, color: Color(0xFFE5E7EB))),

            // Main Content Area
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF059669))),
              )
            else if (_blogs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.article_outlined, size: 48, color: Color(0xFFD1D5DB)),
                        const SizedBox(height: 12),
                        const Text(
                          'Không tìm thấy bài viết cẩm nang phù hợp',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Hãy thử thay đổi từ khóa tìm kiếm hoặc đặt lại các bộ lọc chuyên mục.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Đặt lại bộ lọc', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Featured Spotlight Card
                    if (_featuredBlog != null && !_hasActiveFilters) ...[
                      BlogFeaturedCard(
                        blog: _featuredBlog!,
                        onTap: () => _openBlogDetail(_featuredBlog!),
                        onToggleLike: () => _toggleLike(_featuredBlog!),
                        onToggleSave: () => _toggleSave(_featuredBlog!),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tất cả bài viết cẩm nang',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                          ),
                          Text(
                            '${_blogs.length} bài viết',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Blog Feed Cards List
                    ..._blogs.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
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
                        )),
                  ]),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBlogEditor,
        backgroundColor: const Color(0xFF059669),
        icon: const Icon(Icons.edit_square, color: Colors.white, size: 18),
        label: const Text('Viết bài', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

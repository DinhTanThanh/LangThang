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
  BlogModel? _featuredBlog;
  bool _isLoading = true;
  int _displayCount = 9;

  // Selected categories (support multiple or single)
  final Set<String> _selectedCategories = {};

  final List<String> _categories = const [
    'Di tích lịch sử - Văn hóa',
    'Danh lam thắng cảnh',
    'Điểm tham quan du lịch',
    'Điểm chụp ảnh & Check-in',
    'Ẩm thực & Nhà hàng',
    'Quán cà phê & Giải trí',
    'Khách sạn & Nghỉ dưỡng',
    'Kinh nghiệm du lịch',
    'Cẩm nang tự túc',
    'Phượt & Khám phá',
    'Đặc sản vùng miền',
    'Mẹo & Kinh nghiệm',
  ];

  bool get _hasActiveFilters =>
      _selectedCategories.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null &&
        widget.initialCategory!.isNotEmpty &&
        widget.initialCategory != 'all' &&
        widget.initialCategory != 'Tất cả') {
      _selectedCategories.add(widget.initialCategory!);
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

    final categoryParam = _selectedCategories.length == 1
        ? _selectedCategories.first
        : null;

    final list = await _blogService.getBlogs(
      category: categoryParam,
      keyword: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
    );

    // If multiple categories are selected, filter client-side
    List<BlogModel> filteredList = list;
    if (_selectedCategories.length > 1) {
      filteredList = list.where((b) {
        return _selectedCategories.any((cat) =>
            b.category.toLowerCase().contains(cat.toLowerCase()));
      }).toList();
    }

    BlogModel? feat;
    try {
      feat = filteredList.firstWhere((b) => b.featured, orElse: () => filteredList.first);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _blogs = filteredList;
        _featuredBlog = feat;
        _displayCount = 9;
        _isLoading = false;
      });
    }
  }

  void _handleToggleCategory(String? category) {
    setState(() {
      if (category == null) {
        _selectedCategories.clear();
      } else {
        if (_selectedCategories.contains(category)) {
          _selectedCategories.remove(category);
        } else {
          _selectedCategories.add(category);
        }
      }
    });
    _loadBlogs();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategories.clear();
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
      if (_featuredBlog?.id == blog.id) {
        _featuredBlog = _featuredBlog!.copyWith(
          isLiked: nowLiked,
          likesCount: nowLiked
              ? _featuredBlog!.likesCount + 1
              : (_featuredBlog!.likesCount > 0 ? _featuredBlog!.likesCount - 1 : 0),
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

  @override
  Widget build(BuildContext context) {
    final visibleArticles = _blogs.take(_displayCount).toList();
    final hasMore = visibleArticles.length < _blogs.length;

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
                'Cẩm nang du lịch',
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
        onRefresh: _loadBlogs,
        color: const Color(0xFF065F46),
        child: CustomScrollView(
          slivers: [
            // 1. Top Search & Actions Bar (Matching Share_Locations BlogFeedView)
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar + Action Buttons Row
                    Row(
                      children: [
                        // Search Input
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              onSubmitted: (_) => _loadBlogs(),
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: 'Tìm kiếm cẩm nang, ẩm thực...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _searchController.clear();
                                          _loadBlogs();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Search Submit Button
                        ElevatedButton.icon(
                          onPressed: _loadBlogs,
                          icon: const Icon(Icons.search_rounded, size: 15),
                          label: const Text('Tìm kiếm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF065F46),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Viết cẩm nang Action Button (Matching Share_Locations BlogFeedView)
                        ElevatedButton.icon(
                          onPressed: _openBlogEditor,
                          icon: const Icon(Icons.edit_note_rounded, size: 17),
                          label: const Text('Viết bài', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF047857),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),

                    // Active Filters Reset Row (if active)
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'Bộ lọc đang áp dụng (${_selectedCategories.length + (_searchController.text.trim().isNotEmpty ? 1 : 0)})',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
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
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.restart_alt_rounded, size: 12, color: Color(0xFFBE123C)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Đặt lại bộ lọc',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFBE123C)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),

            // 2. Categories Filter Card (Matching Share_Locations BlogFeedView)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_offer_outlined, size: 14, color: Color(0xFF047857)),
                            const SizedBox(width: 6),
                            const Text(
                              'Chủ đề & Danh mục:',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334155),
                              ),
                            ),
                            if (_selectedCategories.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Text(
                                  'Đã chọn ${_selectedCategories.length} danh mục',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // "Tất cả danh mục" Chip
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => _handleToggleCategory(null),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _selectedCategories.isEmpty ? const Color(0xFF064E3B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedCategories.isEmpty ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_selectedCategories.isEmpty) ...[
                                      const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      'Tất cả danh mục',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: _selectedCategories.isEmpty ? FontWeight.w800 : FontWeight.w600,
                                        color: _selectedCategories.isEmpty ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Individual Category Chips
                          ..._categories.map((cat) {
                            final isCatSelected = _selectedCategories.contains(cat);
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () => _handleToggleCategory(cat),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isCatSelected ? const Color(0xFF065F46) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCatSelected ? const Color(0xFF065F46) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCatSelected) ...[
                                        const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        cat,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isCatSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isCatSelected ? Colors.white : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Results Summary Header (Matching Share_Locations BlogFeedView)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Row(
                  children: [
                    const Text(
                      'Tìm thấy ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_blogs.length} bài viết cẩm nang',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    if (_selectedCategories.isNotEmpty)
                      Text(
                        ' • ${_selectedCategories.length} chủ đề',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
            ),

            // 4. Main Blog Feed Content
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF065F46))),
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
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.visibility_off_outlined, size: 36, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Không tìm thấy bài viết nào phù hợp',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Không có bài viết nào khớp với các tiêu chí tìm kiếm hiện tại. Bạn có thể thử đặt lại bộ lọc để khám phá toàn bộ cẩm nang.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.45),
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _resetFilters,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF065F46),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Đặt lại bộ lọc', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Featured Spotlight Card (If available and no filters active)
                    if (_featuredBlog != null && !_hasActiveFilters) ...[
                      BlogFeaturedCard(
                        blog: _featuredBlog!,
                        onTap: () => _openBlogDetail(_featuredBlog!),
                        onToggleLike: () => _toggleLike(_featuredBlog!),
                        onToggleSave: () => _toggleSave(_featuredBlog!),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Feed Cards List
                    ...visibleArticles.map((b) => Padding(
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

                    // Load More Button (Matching Share_Locations BlogFeedView)
                    if (hasMore) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _displayCount += 6;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF065F46),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Xem thêm bài viết',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
          ],
        ),
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBlogEditor,
        backgroundColor: const Color(0xFF065F46),
        elevation: 4,
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Viết cẩm nang',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

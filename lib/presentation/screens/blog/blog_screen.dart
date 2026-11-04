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

  // Selected category matching Screenshot 2 (single-select with underline)
  String _selectedCategory = 'all';

  final List<String> _categories = const [
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

  @override
  Widget build(BuildContext context) {
    final visibleArticles = _blogs.take(_displayCount).toList();
    final hasMore = visibleArticles.length < _blogs.length;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: canPop,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Cẩm nang du lịch',
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _openBlogEditor,
              icon: const Icon(Icons.edit_note_rounded, size: 17),
              label: const Text('Viết bài', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBlogs,
        color: const Color(0xFF047857),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Redesigned Hero Filter Card (Matching Screenshot 2)
              _buildHeroFilterCard(),

              // Section Header: "Khám phá cẩm nang du lịch" (Matching Screenshot 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Khám phá cẩm nang du lịch',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (_blogs.isNotEmpty)
                      Text(
                        '${_blogs.length} bài viết',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),

              // Blog Feed Content
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF047857)),
                  ),
                )
              else if (_blogs.isEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
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
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Không có bài viết nào khớp với các tiêu chí tìm kiếm hiện tại. Bạn có thể thử đặt lại bộ lọc để khám phá toàn bộ cẩm nang.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.45),
                      ),
                      if (_hasActiveFilters) ...[
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _resetFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF047857),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Đặt lại bộ lọc', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleArticles.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final b = visibleArticles[index];
                          return BlogCardWidget(
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
                          );
                        },
                      ),

                      if (hasMore) ...[
                        const SizedBox(height: 18),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _displayCount += 6;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF047857),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'Xem thêm bài viết',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBlogEditor,
        backgroundColor: const Color(0xFF047857),
        elevation: 3,
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Viết cẩm nang',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  /// Redesigned Hero Filter Card matching Screenshot 2:
  /// - "Góc nhìn cẩm nang."
  /// - 2 Description paragraphs
  /// - Search input with "Tìm" green button
  /// - "Danh mục" header with 3-column category list
  /// - Selected category has green bold text with underline
  Widget _buildHeroFilterCard() {
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
            'Góc nhìn cẩm nang.',
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
            'Tổng hợp kinh nghiệm thực tế, cẩm nang ẩm thực và góc nhìn đa chiều từ những người đi trước.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF475569),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),

          // Description 2
          const Text(
            'Bỏ túi những mẹo du lịch hữu ích theo từng mùa để chuyến đi của bạn luôn trọn vẹn và an tâm nhất.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Search Box with "Tìm" button (Matching Screenshot 2)
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
                    onSubmitted: (_) => _loadBlogs(),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm cẩm nang, ẩm thực, kinh nghiệm...',
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
                    onPressed: _loadBlogs,
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

          // Header: "Danh mục"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh mục',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              if (_selectedCategory != 'all')
                InkWell(
                  onTap: _resetFilters,
                  child: const Text(
                    'Xem tất cả',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF047857), fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Categories Container - arranged with underline options matching Screenshot 2
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUnderlineOption(
                  label: 'Tất cả danh mục',
                  isSelected: _selectedCategory == 'all',
                  onTap: () {
                    setState(() => _selectedCategory = 'all');
                    _loadBlogs();
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: _categories.map((cat) {
                    return _buildUnderlineOption(
                      label: cat,
                      isSelected: _selectedCategory == cat,
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        _loadBlogs();
                      },
                    );
                  }).toList(),
                ),
              ],
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

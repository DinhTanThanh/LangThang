import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../data/models/blog_model.dart';
import '../../../data/models/report_model.dart';
import '../../../data/services/blog_api_service.dart';
import '../../../data/models/place_model.dart';
import '../../widgets/blog/blog_table_of_contents_sheet.dart';
import '../../widgets/blog/blog_mentioned_places_widget.dart';
import '../../widgets/blog/blog_card_widget.dart';
import '../../widgets/blog/share_blog_modal.dart';
import '../../widgets/report/report_modal_sheet.dart';
import '../destinations/place_detail_screen.dart';
import '../profile/user_profile_screen.dart';

class BlogDetailScreen extends StatefulWidget {
  final BlogModel blog;

  const BlogDetailScreen({
    super.key,
    required this.blog,
  });

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  final BlogApiService _blogService = BlogApiService();
  final ScrollController _scrollController = ScrollController();

  late BlogModel _blog;
  List<BlogModel> _relatedBlogs = [];
  double _readingProgress = 0.0;

  final List<GlobalKey> _headingKeys = [];
  List<BlogHeadingItem> _headings = [];

  @override
  void initState() {
    super.initState();
    _blog = widget.blog;
    _parseHeadings();
    _scrollController.addListener(_onScroll);
    _loadFullDetailAndRelated();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll > 0) {
      setState(() {
        _readingProgress = (currentScroll / maxScroll).clamp(0.0, 1.0);
      });
    }
  }

  void _parseHeadings() {
    _headings = [];
    _headingKeys.clear();

    final lines = (_blog.content ?? '').split('\n');
    int headingIndex = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
        final title = trimmed.replaceFirst('# ', '').trim();
        _headings.add(BlogHeadingItem(index: headingIndex, title: title, level: 1));
        _headingKeys.add(GlobalKey());
        headingIndex++;
      } else if (trimmed.startsWith('## ')) {
        final title = trimmed.replaceFirst('## ', '').trim();
        _headings.add(BlogHeadingItem(index: headingIndex, title: title, level: 2));
        _headingKeys.add(GlobalKey());
        headingIndex++;
      } else if (trimmed.startsWith('### ')) {
        final title = trimmed.replaceFirst('### ', '').trim();
        _headings.add(BlogHeadingItem(index: headingIndex, title: title, level: 3));
        _headingKeys.add(GlobalKey());
        headingIndex++;
      }
    }
  }

  Future<void> _loadFullDetailAndRelated() async {
    final detail = await _blogService.getBlogDetail(_blog.id);
    if (mounted && detail != null) {
      setState(() {
        _blog = detail;
        _parseHeadings();
      });
    }

    final allBlogs = await _blogService.getBlogs(category: _blog.category);
    if (mounted) {
      setState(() {
        _relatedBlogs = allBlogs.where((b) => b.id != _blog.id).take(4).toList();
      });
    }
  }

  void _toggleLike() async {
    final nowLiked = await _blogService.toggleLike(_blog);
    setState(() {
      _blog = _blog.copyWith(
        isLiked: nowLiked,
        likesCount: nowLiked ? _blog.likesCount + 1 : (_blog.likesCount > 0 ? _blog.likesCount - 1 : 0),
      );
    });
  }

  void _toggleSave() async {
    final nowSaved = await _blogService.toggleSave(_blog);
    setState(() {
      _blog = _blog.copyWith(isSaved: nowSaved);
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

  void _scrollToHeading(int index) {
    if (index >= 0 && index < _headingKeys.length) {
      final keyContext = _headingKeys[index].currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _shareBlog() {
    ShareBlogModal.show(context, blog: _blog);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF064E3B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cẩm nang du lịch',
          style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900),
        ),
        actions: [
          // TOC button (if headings exist)
          if (_headings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.account_tree_outlined, color: Colors.white, size: 20),
              tooltip: 'Mục lục bài viết',
              onPressed: () => BlogTableOfContentsSheet.show(
                context,
                headings: _headings,
                onSelectHeading: _scrollToHeading,
              ),
            ),
          // Share Button
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 19),
            tooltip: 'Chia sẻ bài viết',
            onPressed: _shareBlog,
          ),
          // Report Button
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.white, size: 19),
            tooltip: 'Báo cáo vi phạm',
            onPressed: () {
              ReportModalSheet.show(
                context,
                targetInfo: ReportTargetInfo.forBlog(
                  id: _blog.id,
                  blogTitle: _blog.title,
                  authorName: _blog.authorName,
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Scroll View
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Category Pill + Published Date (Matching BlogReaderView.tsx)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _blog.category.isNotEmpty ? _blog.category : 'Cẩm nang du lịch',
                              style: const TextStyle(
                                color: Color(0xFF065F46),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_blog.publishedDate.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 5),
                                child: Text('•', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              Text(
                                _blog.publishedDate,
                                style: const TextStyle(
                                  color: Color(0xFF047857),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Article Headline Title (Matching BlogReaderView.tsx)
                      Text(
                        _blog.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          height: 1.3,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 3. Excerpt / Summary (Matching BlogReaderView.tsx)
                      if (_blog.summary.isNotEmpty) ...[
                        Text(
                          _blog.summary,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            height: 1.55,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 4. Author & Meta Header Bar (Matching BlogReaderView.tsx)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE2E8F0)),
                            bottom: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Author Avatar & Name
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  UserProfileScreen.navigate(
                                    context,
                                    userId: _blog.author.id.isNotEmpty ? _blog.author.id : null,
                                    userName: _blog.authorName,
                                    userAvatar: _blog.authorAvatar,
                                    userBio: _blog.author.bio,
                                    userRank: _blog.author.role,
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    if (_blog.authorAvatar.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.network(
                                          _blog.authorAvatar,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(),
                                        ),
                                      )
                                    else
                                      _buildFallbackAvatar(),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _blog.authorName.isNotEmpty ? _blog.authorName : 'Tác giả',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            _blog.author.role.isNotEmpty ? _blog.author.role : 'Tác giả chia sẻ',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Right: Read time & Report Button
                            Row(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_blog.readTimeMinutes > 0 ? _blog.readTimeMinutes : 5} phút đọc',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                                ),
                                InkWell(
                                  onTap: () {
                                    ReportModalSheet.show(
                                      context,
                                      targetInfo: ReportTargetInfo.forBlog(
                                        id: _blog.id,
                                        blogTitle: _blog.title,
                                        authorName: _blog.authorName,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.flag_outlined, size: 13, color: Color(0xFF94A3B8)),
                                        SizedBox(width: 3),
                                        Text(
                                          'Báo cáo',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Cover Image (Embedded in Body matching BlogReaderView.tsx)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 280),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: () {
                            final url = _blog.imageUrl.trim();
                            if (url.isEmpty) return _buildCoverPlaceholder();
                            if (url.startsWith('data:image')) {
                              try {
                                final commaIdx = url.indexOf(',');
                                final b64 = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
                                final bytes = base64Decode(b64);
                                return Image.memory(
                                  bytes,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (ctx, err, stack) => _buildCoverPlaceholder(),
                                );
                              } catch (_) {
                                return _buildCoverPlaceholder();
                              }
                            }
                            return Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => _buildCoverPlaceholder(),
                            );
                          }(),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 6. In-Article Quick TOC Widget (Matching BlogTableOfContents.tsx)
                      if (_headings.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.account_tree_outlined, color: Color(0xFF065F46), size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'MỤC LỤC BÀI VIẾT (${_headings.length})',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () => BlogTableOfContentsSheet.show(
                                      context,
                                      headings: _headings,
                                      onSelectHeading: _scrollToHeading,
                                    ),
                                    child: const Text(
                                      'Mở rộng',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 8),
                              ..._headings.take(4).map((h) {
                                return InkWell(
                                  onTap: () => _scrollToHeading(h.index),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: h.level == 1 ? const Color(0xFF065F46) : const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'H${h.level}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: h.level == 1 ? Colors.white : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            h.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF1E293B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // 7. Rich Article Content (Headings, Markdown, Quotes, Bullets)
                      _buildRichArticleContent(),

                      const SizedBox(height: 24),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 20),

                      // 8. Author Footer Profile Box (Matching BlogReaderView.tsx)
                      InkWell(
                        onTap: () {
                          UserProfileScreen.navigate(
                            context,
                            userId: _blog.author.id.isNotEmpty ? _blog.author.id : null,
                            userName: _blog.authorName,
                            userAvatar: _blog.authorAvatar,
                            userBio: _blog.author.bio,
                            userRank: _blog.author.role,
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF0F172A),
                                backgroundImage: _blog.authorAvatar.isNotEmpty
                                    ? NetworkImage(_blog.authorAvatar)
                                    : null,
                                child: _blog.authorAvatar.isEmpty
                                    ? Text(
                                        _blog.authorName.isNotEmpty ? _blog.authorName[0].toUpperCase() : 'T',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _blog.authorName.isNotEmpty ? _blog.authorName : 'Tác giả',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      _blog.author.role.isNotEmpty ? _blog.author.role : 'Thành viên cộng đồng LangThang',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Cảm ơn bạn đã đọc bài viết! Hãy lưu lại cẩm nang hoặc chia sẻ cho bạn bè cùng chuyến đi nhé.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.45),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 9. Mentioned Places Widget
                      if (_blog.mentionedPlaces.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        BlogMentionedPlacesWidget(
                          places: _blog.mentionedPlaces,
                          onPlaceTap: (place) {
                            final placeModel = PlaceModel(
                              id: place.id,
                              name: place.name,
                              category: place.category,
                              location: place.address.isNotEmpty ? place.address : place.province,
                              region: 'Việt Nam',
                              province: place.province,
                              type: place.category,
                              rating: place.rating,
                              reviews: 0,
                              price: 'Miễn phí',
                              priceMax: 0,
                              priceRange: 'Miễn phí',
                              hours: '07:30 – 17:30',
                              status: 'Đang mở cửa',
                              desc: '',
                              detailedDescription: '',
                              phoneNumber: '',
                              website: '',
                              img: place.imageUrl,
                              mediaUrls: place.imageUrl.isNotEmpty ? [place.imageUrl] : [],
                              latitude: 21.0285,
                              longitude: 105.8542,
                              tags: [place.category],
                              amenities: const [],
                              isSaved: false,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PlaceDetailScreen(place: placeModel)),
                            );
                          },
                        ),
                      ],

                      // 10. Tags List
                      if (_blog.tags.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _blog.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 20),

                      // 11. Related Articles
                      if (_relatedBlogs.isNotEmpty) ...[
                        const Text(
                          'Cẩm nang cùng chuyên mục',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),
                        ..._relatedBlogs.map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: BlogCardWidget(
                                blog: b,
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => BlogDetailScreen(blog: b)),
                                  );
                                },
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Top Reading Progress Bar (Matching BlogReaderView.tsx)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _readingProgress,
              minHeight: 3.5,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
          ),

          // Bottom Action Bar (Like, Save, Share, Itinerary CTA)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Like & Save Buttons
                    Row(
                      children: [
                        InkWell(
                          onTap: _toggleLike,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _blog.isLiked ? const Color(0xFFFFF1F2) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _blog.isLiked ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _blog.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: _blog.isLiked ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${_blog.likesCount}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _blog.isLiked ? const Color(0xFFE11D48) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _toggleSave,
                          icon: Icon(
                            _blog.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: _blog.isSaved ? const Color(0xFF065F46) : const Color(0xFF64748B),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: _blog.isSaved ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),

                    // Share Article CTA
                    ElevatedButton.icon(
                      onPressed: _shareBlog,
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Chia sẻ bài viết', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065F46),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF047857)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, color: Colors.white54, size: 48),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    final initial = _blog.authorName.isNotEmpty ? _blog.authorName[0].toUpperCase() : 'T';
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildRichArticleContent() {
    final rawContent = _blog.content ?? '';
    if (rawContent.isEmpty) {
      return const Text('Nội dung chi tiết đang được cập nhật...');
    }

    final lines = rawContent.split('\n');
    List<Widget> widgets = [];
    int headingTracker = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('# ') && !line.startsWith('## ')) {
        final title = line.replaceFirst('# ', '').trim();
        final key = (headingTracker < _headingKeys.length) ? _headingKeys[headingTracker] : null;
        headingTracker++;

        widgets.add(Padding(
          key: key,
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),
        ));
      } else if (line.startsWith('## ')) {
        final title = line.replaceFirst('## ', '').trim();
        final key = (headingTracker < _headingKeys.length) ? _headingKeys[headingTracker] : null;
        headingTracker++;

        widgets.add(Padding(
          key: key,
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),
        ));
      } else if (line.startsWith('### ')) {
        final title = line.replaceFirst('### ', '').trim();
        final key = (headingTracker < _headingKeys.length) ? _headingKeys[headingTracker] : null;
        headingTracker++;

        widgets.add(Padding(
          key: key,
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF065F46),
            ),
          ),
        ));
      } else if (line.startsWith('> ')) {
        final quote = line.replaceFirst('> ', '').trim();
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFF065F46), width: 3)),
          ),
          child: Text(
            quote,
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Color(0xFF065F46),
              height: 1.45,
            ),
          ),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        final bulletText = line.substring(2).trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: Color(0xFF065F46), fontSize: 14, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  bulletText,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
                ),
              ),
            ],
          ),
        ));
      } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            line,
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            line,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF334155),
              height: 1.6,
            ),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

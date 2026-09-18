import 'package:flutter/material.dart';
import '../../../data/models/blog_model.dart';
import '../../../data/services/blog_api_service.dart';
import '../../widgets/blog/blog_table_of_contents_sheet.dart';
import '../../widgets/blog/blog_mentioned_places_widget.dart';
import '../../widgets/blog/blog_card_widget.dart';
import '../itineraries/itineraries_screen.dart';

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
      if (trimmed.startsWith('## ')) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã sao chép liên kết bài viết cẩm nang!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Parallax Sliver AppBar with Cover Image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                elevation: 0,
                backgroundColor: const Color(0xFF064E3B),
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                actions: [
                  // Bookmark Button
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: CircleAvatar(
                      backgroundColor: _blog.isSaved ? const Color(0xFFE11D48) : Colors.black.withValues(alpha: 0.4),
                      child: IconButton(
                        icon: Icon(
                          _blog.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        onPressed: _toggleSave,
                      ),
                    ),
                  ),
                  // Share Button
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      child: IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                        onPressed: _shareBlog,
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _blog.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF064E3B),
                          child: const Center(
                            child: Icon(Icons.menu_book_rounded, color: Colors.white54, size: 48),
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF047857),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _blog.category,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 12, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_blog.readTimeMinutes} phút đọc',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Article Body Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date & Meta
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF6B7280)),
                          const SizedBox(width: 5),
                          Text(
                            _blog.publishedDate,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                          ),
                          if (_blog.province.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(color: Color(0xFF9CA3AF))),
                            const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF059669)),
                            const SizedBox(width: 3),
                            Text(
                              _blog.province,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Article Title
                      Text(
                        _blog.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          height: 1.3,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Excerpt Box
                      if (_blog.summary.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: const Border(
                              left: BorderSide(color: Color(0xFF059669), width: 4),
                            ),
                          ),
                          child: Text(
                            _blog.summary,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF374151),
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Author Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF059669),
                                  backgroundImage: _blog.authorAvatar.isNotEmpty
                                      ? NetworkImage(_blog.authorAvatar)
                                      : null,
                                  child: _blog.authorAvatar.isEmpty
                                      ? Text(
                                          _blog.authorName.isNotEmpty ? _blog.authorName[0].toUpperCase() : 'A',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _blog.authorName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                    ),
                                    Text(
                                      '${_blog.author.role} • ${_blog.author.rank}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // TOC Trigger button
                            if (_headings.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => BlogTableOfContentsSheet.show(
                                  context,
                                  headings: _headings,
                                  onSelectHeading: _scrollToHeading,
                                ),
                                icon: const Icon(Icons.format_list_bulleted_rounded, size: 14, color: Color(0xFF059669)),
                                label: const Text('Mục lục', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF059669)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Rich Markdown / Text Content
                      _buildRichArticleContent(),

                      // Mentioned Places Widget
                      if (_blog.mentionedPlaces.isNotEmpty)
                        BlogMentionedPlacesWidget(
                          places: _blog.mentionedPlaces,
                          onAddToItinerary: (place) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ItinerariesScreen()),
                            );
                          },
                        ),

                      // Tags List
                      if (_blog.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _blog.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 20),

                      // Related Articles
                      if (_relatedBlogs.isNotEmpty) ...[
                        const Text(
                          'Cẩm nang cùng chuyên mục',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
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
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
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
                border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
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
                              color: _blog.isLiked ? const Color(0xFFFFF1F2) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _blog.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: _blog.isLiked ? const Color(0xFFE11D48) : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${_blog.likesCount}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _blog.isLiked ? const Color(0xFFE11D48) : const Color(0xFF374151),
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
                            color: _blog.isSaved ? const Color(0xFF059669) : const Color(0xFF6B7280),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: _blog.isSaved ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),

                    // Plan Trip CTA
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItinerariesScreen(initialKeyword: _blog.province.isNotEmpty ? _blog.province : _blog.category),
                          ),
                        );
                      },
                      icon: const Icon(Icons.explore_rounded, size: 16),
                      label: const Text('Lên lịch trình', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
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

      if (line.startsWith('## ')) {
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
              color: Color(0xFF111827),
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
              color: Color(0xFF047857),
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
            border: const Border(left: BorderSide(color: Color(0xFF059669), width: 3)),
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
              const Text('• ', style: TextStyle(color: Color(0xFF059669), fontSize: 14, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  bulletText,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.45),
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
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.45),
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            line,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF374151),
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

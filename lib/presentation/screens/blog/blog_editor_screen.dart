import 'package:flutter/material.dart';
import '../../../data/services/blog_api_service.dart';

class BlogEditorScreen extends StatefulWidget {
  final VoidCallback? onPublished;

  const BlogEditorScreen({
    super.key,
    this.onPublished,
  });

  @override
  State<BlogEditorScreen> createState() => _BlogEditorScreenState();
}

class _BlogEditorScreenState extends State<BlogEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _coverUrlController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _selectedCategory = 'Di tích lịch sử - Văn hóa';
  final int _readTimeMinutes = 5;
  bool _isPreviewMode = false;
  bool _isPublishing = false;

  final List<String> _categories = [
    'Di tích lịch sử - Văn hóa',
    'Ẩm thực & Quán xá',
    'Cảnh quan thiên nhiên',
    'Làng nghề truyền thống',
    'Kinh nghiệm du lịch',
    'Check-in sống ảo',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _coverUrlController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _insertMarkdown(String prefix, [String suffix = '']) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final selectedText = text.substring(start, end);

    final replacement = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, replacement);
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(offset: start + replacement.length);
  }

  Future<void> _handlePublish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isPublishing = true);

    final success = await BlogApiService().createBlog(
      title: _titleController.text.trim(),
      summary: _summaryController.text.trim(),
      category: _selectedCategory,
      coverUrl: _coverUrlController.text.trim(),
      content: _contentController.text.trim(),
      readTimeMinutes: _readTimeMinutes,
    );

    if (mounted) {
      setState(() => _isPublishing = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã xuất bản bài viết cẩm nang thành công!'),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        if (widget.onPublished != null) widget.onPublished!();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Có lỗi xảy ra khi xuất bản bài viết.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Viết bài cẩm nang mới',
          style: TextStyle(color: Color(0xFF111827), fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          // Toggle Preview / Edit
          IconButton(
            icon: Icon(
              _isPreviewMode ? Icons.edit_note_rounded : Icons.visibility_rounded,
              color: const Color(0xFF059669),
            ),
            tooltip: _isPreviewMode ? 'Chuyển sang soạn thảo' : 'Xem trước bài viết',
            onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
          ),
          // Publish Button
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: _isPublishing ? null : _handlePublish,
              icon: _isPublishing
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 14),
              label: Text(_isPublishing ? 'Đang gửi...' : 'Xuất bản', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: _isPreviewMode ? _buildPreviewMode() : _buildEditorForm(),
    );
  }

  Widget _buildEditorForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title Input
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tiêu đề bài viết *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề bài viết' : null,
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: Kinh nghiệm săn mây Đà Lạt 3N2Đ cực chất...',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category & Read Time Row
          Row(
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chuyên mục', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Thời gian đọc', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text('$_readTimeMinutes phút', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cover Image URL
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('URL Ảnh bìa (Cover Image)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _coverUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://images.unsplash.com/...',
                    hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Summary Excerpt
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tóm tắt ngắn (Excerpt)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _summaryController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Tóm lược trải nghiệm nổi bật trong 1-2 câu ngắn gọn...',
                    hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Markdown Content Editor with Toolbar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Nội dung bài viết *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                    Text('${_contentController.text.length} ký tự', style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF))),
                  ],
                ),
                const SizedBox(height: 8),

                // Markdown Formatting Toolbar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildToolbarBtn('H2', () => _insertMarkdown('\n## ')),
                      _buildToolbarBtn('H3', () => _insertMarkdown('\n### ')),
                      _buildToolbarBtn('B', () => _insertMarkdown('**', '**'), isBold: true),
                      _buildToolbarBtn('Trích dẫn', () => _insertMarkdown('\n> ')),
                      _buildToolbarBtn('Danh sách', () => _insertMarkdown('\n- ')),
                      _buildToolbarBtn('Mẹo thổ địa', () => _insertMarkdown('\n### Mẹo từ Thổ Địa:\n- ')),
                    ],
                  ),
                ),
                const Divider(height: 16, color: Color(0xFFF3F4F6)),

                TextFormField(
                  controller: _contentController,
                  maxLines: 12,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập nội dung bài viết' : null,
                  decoration: const InputDecoration(
                    hintText: 'Nhập nội dung cẩm nang (hỗ trợ tiêu đề ##, danh sách -, trích dẫn >)...',
                    hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2937), height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildToolbarBtn(String label, VoidCallback onTap, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewMode() {
    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Tiêu đề bài viết';
    final summary = _summaryController.text.trim();
    final content = _contentController.text.trim().isNotEmpty ? _contentController.text.trim() : 'Nội dung bài viết xem trước...';

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _selectedCategory,
            style: const TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827), height: 1.3),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: const Border(left: BorderSide(color: Color(0xFF059669), width: 3)),
            ),
            child: Text(summary, style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF4B5563))),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Text(content, style: const TextStyle(fontSize: 13.5, color: Color(0xFF374151), height: 1.6)),
      ],
    );
  }
}

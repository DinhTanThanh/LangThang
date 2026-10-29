import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/blog_api_service.dart';
import '../auth/login_screen.dart';

class TocItem {
  final int level;
  final String text;
  final int lineIndex;

  TocItem({required this.level, required this.text, required this.lineIndex});
}

class BlogEditorScreen extends StatefulWidget {
  final dynamic blogId;
  final String? initialTitle;
  final String? initialSummary;
  final String? initialCategory;
  final int? initialCategoryId;
  final String? initialCoverUrl;
  final String? initialContent;
  final int initialStatus; // 0: Draft (Nháp), 1: Published, 2: Pending (Chờ duyệt)
  final VoidCallback? onPublished;

  const BlogEditorScreen({
    super.key,
    this.blogId,
    this.initialTitle,
    this.initialSummary,
    this.initialCategory,
    this.initialCategoryId,
    this.initialCoverUrl,
    this.initialContent,
    this.initialStatus = 0,
    this.onPublished,
  });

  @override
  State<BlogEditorScreen> createState() => _BlogEditorScreenState();
}

class _BlogEditorScreenState extends State<BlogEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _coverBytes;

  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _contentController;

  late String _selectedCategory;
  int _readTimeMinutes = 5;
  bool _isPreviewMode = false;
  bool _isSavingDraft = false;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _categories = const [
    {'id': 13, 'name': 'Di tích lịch sử - Văn hóa'},
    {'id': 7, 'name': 'Danh lam thắng cảnh'},
    {'id': 14, 'name': 'Điểm tham quan du lịch'},
    {'id': 15, 'name': 'Điểm chụp ảnh & Check-in'},
    {'id': 16, 'name': 'Ẩm thực & Nhà hàng'},
    {'id': 17, 'name': 'Quán cà phê & Giải trí'},
    {'id': 18, 'name': 'Khách sạn & Nghỉ dưỡng'},
    {'id': 19, 'name': 'Kinh nghiệm du lịch'},
    {'id': 20, 'name': 'Cẩm nang tự túc'},
    {'id': 21, 'name': 'Phượt & Khám phá'},
    {'id': 22, 'name': 'Đặc sản vùng miền'},
    {'id': 23, 'name': 'Mẹo & Kinh nghiệm'},
  ];

  static const List<Map<String, String>> _coverPresets = [
    {
      'label': 'Huế cố đô',
      'url': 'https://images.unsplash.com/photo-1569271532956-3fb81a207115?w=1000&h=600&fit=crop&auto=format',
    },
    {
      'label': 'Đà Nẵng biển',
      'url': 'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=1000&h=600&fit=crop&auto=format',
    },
    {
      'label': 'Hội An phố cổ',
      'url': 'https://images.unsplash.com/photo-1527997921830-de1cf1f9b430?w=1000&h=600&fit=crop&auto=format',
    },
    {
      'label': 'Vũng Tàu',
      'url': 'https://images.unsplash.com/photo-1718942900279-4711345169d3?w=1000&h=600&fit=crop&auto=format',
    },
    {
      'label': 'Nha Trang',
      'url': 'https://images.unsplash.com/photo-1763703686284-b63557b08a86?w=1000&h=600&fit=crop&auto=format',
    },
    {
      'label': 'Vịnh Hạ Long',
      'url': 'https://images.unsplash.com/photo-1528127269322-539801943592?w=1000&q=80',
    },
    {
      'label': 'Sương mờ Đà Lạt',
      'url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1000&q=80',
    },
    {
      'label': 'Tràng An Ninh Bình',
      'url': 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=1000&q=80',
    },
    {
      'label': 'Ruộng bậc thang Sa Pa',
      'url': 'https://images.unsplash.com/photo-1570168007204-dfb528c6958f?w=1000&q=80',
    },
    {
      'label': 'Biển đảo Phú Quốc',
      'url': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=1000&q=80',
    },
    {
      'label': 'Chợ đêm ẩm thực',
      'url': 'https://images.unsplash.com/photo-1509072619873-adb3dc289b50?w=1000&h=600&fit=crop&auto=format',
    },
  ];

  bool get _isPendingApproval => widget.initialStatus == 2;

  List<TocItem> get _tocItems {
    final text = _contentController.text;
    final lines = text.split('\n');
    final List<TocItem> items = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('### ')) {
        final heading = line.substring(4).trim();
        if (heading.isNotEmpty) {
          items.add(TocItem(level: 3, text: heading, lineIndex: i));
        }
      } else if (line.startsWith('## ')) {
        final heading = line.substring(3).trim();
        if (heading.isNotEmpty) {
          items.add(TocItem(level: 2, text: heading, lineIndex: i));
        }
      } else if (line.startsWith('# ')) {
        final heading = line.substring(2).trim();
        if (heading.isNotEmpty) {
          items.add(TocItem(level: 1, text: heading, lineIndex: i));
        }
      }
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _summaryController = TextEditingController(text: widget.initialSummary ?? '');
    _coverUrlController = TextEditingController(text: widget.initialCoverUrl ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');

    if (widget.initialCategoryId != null && widget.initialCategoryId! > 0) {
      final match = _categories.firstWhere(
        (c) => c['id'] == widget.initialCategoryId,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        _selectedCategory = match['name'] as String;
      } else {
        _selectedCategory = widget.initialCategory ?? 'Di tích lịch sử - Văn hóa';
      }
    } else {
      _selectedCategory = widget.initialCategory ?? 'Di tích lịch sử - Văn hóa';
    }

    final exists = _categories.any((c) => c['name'] == _selectedCategory);
    if (!exists) {
      final match = _categories.firstWhere(
        (c) => (c['name'] as String).toLowerCase() == _selectedCategory.toLowerCase(),
        orElse: () => _categories.first,
      );
      _selectedCategory = match['name'] as String;
    }

    _calculateReadTime();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _coverUrlController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _calculateReadTime() {
    final words = _contentController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final minutes = (words / 180).ceil();
    setState(() {
      _readTimeMinutes = minutes > 0 ? minutes : 3;
    });
  }

  void _insertMarkdown(String prefix, [String suffix = '']) {
    if (_isPendingApproval) return;
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final selectedText = text.substring(start, end);

    final replacement = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, replacement);
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(offset: start + replacement.length);
    _calculateReadTime();
  }

  int _getCategoryId() {
    final match = _categories.firstWhere(
      (c) => c['name'] == _selectedCategory,
      orElse: () => _categories.firstWhere(
        (c) => (c['name'] as String).toLowerCase() == _selectedCategory.toLowerCase(),
        orElse: () => _categories.first,
      ),
    );
    return match['id'] as int;
  }

  /// Kiểm tra xác thực & chuyển sang màn hình đăng nhập nếu mất token, đảm bảo giữ nguyên 100% nội dung form
  Future<bool> _ensureAuthenticated({required String reason}) async {
    final token = await AuthService().getAccessToken();
    final hasToken = token != null && token.isNotEmpty && !token.startsWith('google_session_token_');
    if (hasToken) return true;

    if (!mounted) return false;

    // Hiển thị thông báo giải thích rõ ràng cho người dùng
    final shouldLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_person_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Yêu cầu đăng nhập',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tất cả tiêu đề, mô tả, ảnh bìa và nội dung bài viết bạn đang nhập sẽ được giữ nguyên 100%!',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục viết (Chưa đăng nhập)', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (shouldLogin != true || !mounted) return false;

    // Chuyển sang màn hình Đăng nhập (giữ nguyên state của bài viết bên dưới trong widget stack)
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    if (loggedIn == true && mounted) {
      _showToast('Đăng nhập thành công! Đang tiếp tục xử lý...');
      return true;
    }

    return false;
  }

  /// 1. Xử lý LƯU BẢN NHÁP (status: 0)
  Future<void> _handleSaveDraft() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showToast('Vui lòng nhập ít nhất tiêu đề bài viết để lưu bản nháp!', isError: true);
      return;
    }

    final isAuthed = await _ensureAuthenticated(
      reason: 'Bạn cần đăng nhập tài khoản để lưu bản nháp bài viết vào hệ thống.',
    );
    if (!isAuthed) return;

    setState(() => _isSavingDraft = true);

    final result = widget.blogId != null
        ? await BlogApiService().updateBlog(
            widget.blogId,
            title: title,
            summary: _summaryController.text.trim(),
            category: _selectedCategory,
            categoryId: _getCategoryId(),
            coverUrl: _coverUrlController.text.trim(),
            content: _contentController.text.trim(),
            readTimeMinutes: _readTimeMinutes,
            status: 0, // 0 = Draft
          )
        : await BlogApiService().createBlog(
            title: title,
            summary: _summaryController.text.trim(),
            category: _selectedCategory,
            categoryId: _getCategoryId(),
            coverUrl: _coverUrlController.text.trim(),
            content: _contentController.text.trim(),
            readTimeMinutes: _readTimeMinutes,
            status: 0, // 0 = Draft
          );

    if (mounted) {
      setState(() => _isSavingDraft = false);

      if (result.savedToRemoteDatabase) {
        _showToast('Đã lưu bản nháp vào Database thành công!');
      } else {
        _showToast('Đã lưu bản nháp trên máy (Chưa kết nối Backend SQL)');
      }
      if (widget.onPublished != null) widget.onPublished!();
      Navigator.pop(context, true);
    }
  }

  /// 2. Xử lý GỬI DUYỆT (status: 2)
  Future<void> _handleSubmitForReview() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) {
      _showToast('Vui lòng nhập tiêu đề bài viết', isError: true);
      return;
    }
    if (content.isEmpty) {
      _showToast('Vui lòng nhập nội dung bài viết', isError: true);
      return;
    }

    final isAuthed = await _ensureAuthenticated(
      reason: 'Bạn cần đăng nhập tài khoản để gửi bài viết chờ duyệt và lưu trực tiếp vào cơ sở dữ liệu hệ thống.',
    );
    if (!isAuthed) return;

    setState(() => _isSubmitting = true);

    final result = widget.blogId != null
        ? await BlogApiService().updateBlog(
            widget.blogId,
            title: title,
            summary: _summaryController.text.trim(),
            category: _selectedCategory,
            categoryId: _getCategoryId(),
            coverUrl: _coverUrlController.text.trim(),
            content: content,
            readTimeMinutes: _readTimeMinutes,
            status: 2, // 2 = Pending Approval
          )
        : await BlogApiService().createBlog(
            title: title,
            summary: _summaryController.text.trim(),
            category: _selectedCategory,
            categoryId: _getCategoryId(),
            coverUrl: _coverUrlController.text.trim(),
            content: content,
            readTimeMinutes: _readTimeMinutes,
            status: 2, // 2 = Pending Approval
          );

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (result.savedToRemoteDatabase) {
        _showToast('Đã lưu bài viết vào Database và gửi chờ duyệt thành công!');
        if (widget.onPublished != null) widget.onPublished!();
        Navigator.pop(context, true);
      } else if (result.statusCode == 401) {
        // Phiên đăng nhập hết hạn
        final shouldRelogin = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Phiên đăng nhập hết hạn',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Phiên đăng nhập của bạn đã hết hạn. Hãy đăng nhập lại để hệ thống lưu trực tiếp bài viết vào Database SQL Server.\n\nToàn bộ tiêu đề, nội dung và ảnh bìa bạn đã nhập sẽ được giữ nguyên 100%!',
              style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF334155)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Đóng & Lưu tạm trên máy', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Đăng nhập lại ngay', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldRelogin == true && mounted) {
          final loggedIn = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          if (loggedIn == true && mounted) {
            _showToast('Đăng nhập thành công! Đang tự động gửi bài vào Database...');
            _handleSubmitForReview();
          }
        }
      } else {
        // Hiển thị thông báo chi tiết khi máy chủ chưa ghi được vào SQL
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Chưa lưu vào Database SQL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bài viết đã được lưu tạm trên ứng dụng, nhưng CHƯA thể ghi vào bảng Blogs trên Database SQL Server do máy chủ Backend chưa kết nối được.',
                  style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Phản hồi: ${result.message ?? "Không có kết nối trên cổng 5000"}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '👉 Hãy đảm bảo Backend Docker/ASP.NET Core đang hoạt động trên cổng 5000.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (widget.onPublished != null) widget.onPublished!();
                  Navigator.pop(context, true);
                },
                child: const Text('Đóng & Lưu tạm trên máy', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleSubmitForReview();
                },
                child: const Text('Thử gửi lại ngay', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF064E3B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Tải ảnh bìa từ máy (Gallery hoặc Camera)
  Future<void> _pickCoverFromDevice(ImageSource source, {BuildContext? dialogContext}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        _showToast('Kích thước ảnh bìa không được vượt quá 10MB.', isError: true);
        return;
      }

      final base64Str = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64Str';

      setState(() {
        _coverBytes = bytes;
        _coverUrlController.text = dataUri;
      });

      if (dialogContext != null && dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      _showToast('Đã tải ảnh bìa từ máy lên thành công!');
    } catch (e) {
      _showToast('Không thể tải ảnh từ thiết bị: $e', isError: true);
    }
  }

  /// Helper render widget ảnh bìa (hỗ trợ Memory Bytes, Base64 Data URI, và Network URL)
  Widget _buildCoverImageWidget({BoxFit fit = BoxFit.cover}) {
    if (_coverBytes != null) {
      return Image.memory(
        _coverBytes!,
        fit: fit,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Text('Không thể hiển thị ảnh bìa', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ),
        ),
      );
    }

    final cover = _coverUrlController.text.trim();
    if (cover.startsWith('data:image')) {
      try {
        final commaIndex = cover.indexOf(',');
        final b64 = commaIndex != -1 ? cover.substring(commaIndex + 1) : cover;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          fit: fit,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: Text('Không thể hiển thị ảnh bìa', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
          ),
        );
      } catch (_) {}
    }

    return Image.network(
      cover,
      fit: fit,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Text('Không thể tải ảnh bìa này', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ),
      ),
    );
  }

  /// Sheet chọn ảnh bìa (Tải từ máy + Presets + Custom URL)
  void _showCoverPickerSheet() {
    final customUrlController = TextEditingController(
      text: _coverUrlController.text.startsWith('data:image') ? '' : _coverUrlController.text,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.image_rounded, size: 20, color: Color(0xFF047857)),
                        SizedBox(width: 8),
                        Text(
                          'Cài đặt ảnh bìa bài viết',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 1. TẢI ẢNH TỪ THIẾT BỊ / MÁY (Local File Upload / Gallery)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.drive_folder_upload_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Tải ảnh từ máy lên',
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF047857),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Khuyên dùng', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Chọn ảnh có sẵn từ bộ nhớ máy hoặc chụp ảnh mới (JPG, PNG, WEBP tối đa 10MB)',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _pickCoverFromDevice(ImageSource.gallery, dialogContext: ctx),
                              icon: const Icon(Icons.photo_library_rounded, size: 16),
                              label: const Text('Thư viện máy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF047857),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickCoverFromDevice(ImageSource.camera, dialogContext: ctx),
                              icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Color(0xFF047857)),
                              label: const Text('Chụp Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF047857)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Custom URL Input
                const Text(
                  'Hoặc nhập liên kết ảnh trực tiếp (URL)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: customUrlController,
                          decoration: const InputDecoration(
                            hintText: 'https://images.unsplash.com/...',
                            hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      if (customUrlController.text.isNotEmpty)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _coverBytes = null;
                              _coverUrlController.text = customUrlController.text.trim();
                            });
                            Navigator.pop(ctx);
                            _showToast('Đã áp dụng ảnh bìa mới!');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Text('Áp dụng', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 3. Presets Grid
                const Text(
                  'Hoặc chọn nhanh từ bộ sưu tập mẫu:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: _coverPresets.length,
                  itemBuilder: (context, index) {
                    final preset = _coverPresets[index];
                    final isSelected = _coverUrlController.text.trim() == preset['url'];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _coverBytes = null;
                          _coverUrlController.text = preset['url']!;
                        });
                        Navigator.pop(ctx);
                        _showToast('Đã chọn ảnh bìa: ${preset['label']}');
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(preset['url']!, fit: BoxFit.cover),
                              Container(
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.all(3),
                                color: Colors.black.withValues(alpha: 0.5),
                                child: Text(
                                  preset['label']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: CircleAvatar(
                                    radius: 9,
                                    backgroundColor: Color(0xFF047857),
                                    child: Icon(Icons.check_rounded, size: 12, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sheet xem Mục lục bài viết (Table of Contents)
  void _showTocSheet() {
    final items = _tocItems;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, size: 20, color: Color(0xFF047857)),
                    const SizedBox(width: 8),
                    const Text(
                      'Điều hướng mục lục',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.format_list_bulleted_rounded, size: 32, color: Color(0xFF94A3B8)),
                    SizedBox(height: 8),
                    Text(
                      'Chưa có đề mục nào',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dùng thanh công cụ để thêm Tiêu đề (H1, H2, H3) và tự động tạo mục lục nhé!',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showToast('Đã chuyển tới: ${item.text}');
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: item.level == 1 ? 8 : (item.level == 2 ? 24 : 40),
                          top: 10,
                          bottom: 10,
                          right: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.level == 1
                                    ? const Color(0xFF064E3B)
                                    : item.level == 2
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'H${item.level}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: item.level == 1 ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.text,
                                style: TextStyle(
                                  fontSize: item.level == 1 ? 13 : 12,
                                  fontWeight: item.level == 1 ? FontWeight.w800 : FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Dialog chèn liên kết
  void _showInsertLinkDialog() {
    final textCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: Color(0xFF047857), size: 22),
            SizedBox(width: 8),
            Text('Chèn liên kết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textCtrl,
              decoration: const InputDecoration(
                labelText: 'Văn bản hiển thị',
                hintText: 'ví dụ: Xem thêm tại đây...',
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Đường dẫn (URL)',
                hintText: 'https://...',
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textCtrl.text.trim().isNotEmpty ? textCtrl.text.trim() : 'liên kết';
              final url = urlCtrl.text.trim().isNotEmpty ? urlCtrl.text.trim() : 'https://';
              _insertMarkdown('[$text]($url)');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Chèn link', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Dialog chèn hình ảnh vào nội dung
  void _showInsertImageDialog() {
    final altCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.image_outlined, color: Color(0xFF047857), size: 22),
            SizedBox(width: 8),
            Text('Chèn hình ảnh vào bài viết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                try {
                  final picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1600,
                    maxHeight: 1200,
                    imageQuality: 80,
                  );
                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    final b64 = base64Encode(bytes);
                    final dataUri = 'data:image/jpeg;base64,$b64';
                    final alt = altCtrl.text.trim().isNotEmpty ? altCtrl.text.trim() : 'Ảnh cẩm nang';
                    _insertMarkdown('\n![$alt]($dataUri)\n');
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showToast('Đã chèn ảnh từ thiết bị vào bài viết!');
                  }
                } catch (e) {
                  _showToast('Lỗi khi tải ảnh: $e', isError: true);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFF047857)),
                    SizedBox(width: 8),
                    Text('Tải ảnh từ thư viện máy', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('hoặc nhập link', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ),
                Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: altCtrl,
              decoration: const InputDecoration(
                labelText: 'Chú thích ảnh',
                hintText: 'ví dụ: Cảnh hoàng hôn trên biển...',
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Đường dẫn hình ảnh (URL)',
                hintText: 'https://images.unsplash.com/...',
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              final alt = altCtrl.text.trim().isNotEmpty ? altCtrl.text.trim() : 'Ảnh minh họa';
              final url = urlCtrl.text.trim().isNotEmpty ? urlCtrl.text.trim() : 'https://';
              _insertMarkdown('\n![$alt]($url)\n');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Chèn ảnh', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildHeaderAppBar(),
      body: Column(
        children: [
          // Banner cảnh báo nếu bài viết đang Chờ duyệt (Status = 2)
          if (_isPendingApproval) _buildPendingApprovalBanner(),

          // Sticky Rich Formatting Toolbar (nếu được phép sửa)
          if (!_isPendingApproval && !_isPreviewMode) _buildFormattingToolbar(),

          // Document Paper Canvas Body
          Expanded(
            child: _isPreviewMode ? _buildPreviewMode() : _buildEditorPaperCanvas(),
          ),
        ],
      ),
    );
  }

  /// 1. HEADER APP BAR (Thiết kế đồng bộ ArticleEditorView)
  PreferredSizeWidget _buildHeaderAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 44,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Mục lục Button
            InkWell(
              onTap: _showTocSheet,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.format_list_bulleted_rounded, size: 13, color: Color(0xFF065F46)),
                    const SizedBox(width: 4),
                    const Text('Mục lục', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                    if (_tocItems.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_tocItems.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Dropdown Chuyên mục (Tag Badge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c['name'] as String,
                            child: Text(c['name'] as String),
                          ))
                      .toList(),
                  onChanged: _isPendingApproval
                      ? null
                      : (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Cover Image Picker Button (Header Quick Access)
            if (!_isPendingApproval)
              InkWell(
                onTap: _showCoverPickerSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_camera_back_outlined, size: 13, color: Color(0xFF047857)),
                      const SizedBox(width: 4),
                      Text(
                        _coverUrlController.text.isNotEmpty ? 'Đổi ảnh bìa' : 'Chọn ảnh bìa',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        // Chế độ xem trước
        IconButton(
          icon: Icon(
            _isPreviewMode ? Icons.edit_note_rounded : Icons.visibility_outlined,
            color: const Color(0xFF047857),
            size: 20,
          ),
          tooltip: _isPreviewMode ? 'Chuyển sang soạn thảo' : 'Xem trước bài viết',
          onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
        ),

        // Action Buttons: Save / Publish
        if (_isPendingApproval) ...[
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: Color(0xFFB45309)),
                SizedBox(width: 4),
                Text('Đang chờ duyệt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
              ],
            ),
          ),
        ] else ...[
          // Nút Lưu Nháp
          TextButton.icon(
            onPressed: (_isSavingDraft || _isSubmitting) ? null : _handleSaveDraft,
            icon: _isSavingDraft
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF475569)))
                : const Icon(Icons.bookmark_border_rounded, size: 14, color: Color(0xFF475569)),
            label: Text(
              _isSavingDraft ? 'Lưu...' : 'Lưu nháp',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
          ),

          // Nút Gửi Duyệt
          Container(
            margin: const EdgeInsets.only(right: 12, left: 2),
            child: ElevatedButton.icon(
              onPressed: (_isSavingDraft || _isSubmitting) ? null : _handleSubmitForReview,
              icon: _isSubmitting
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 13, color: Colors.white),
              label: Text(
                _isSubmitting ? 'Gửi...' : 'Gửi duyệt',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
      ),
    );
  }

  /// 2. PENDING BANNER
  Widget _buildPendingApprovalBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFEF3C7),
        border: Border(bottom: BorderSide(color: Color(0xFFFDE68A))),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_filled_rounded, color: Color(0xFFB45309), size: 17),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Bài viết này đang ở trạng thái Chờ duyệt nên tạm thời bị khóa chỉnh sửa.',
              style: TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE68A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Đóng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF78350F))),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. STICKY FORMATTING TOOLBAR
  Widget _buildFormattingToolbar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Headings Pill Group
            _buildToolbarGroup([
              _buildToolBtn('H1', () => _insertMarkdown('\n# '), tooltip: 'Tiêu đề lớn'),
              _buildToolBtn('H2', () => _insertMarkdown('\n## '), tooltip: 'Tiêu đề đề mục'),
              _buildToolBtn('H3', () => _insertMarkdown('\n### '), tooltip: 'Tiểu mục chi tiết'),
            ]),
            _buildToolbarDivider(),

            // Text Styles Group
            _buildToolbarGroup([
              _buildToolBtn('B', () => _insertMarkdown('**', '**'), isBold: true, tooltip: 'In đậm'),
              _buildToolBtn('I', () => _insertMarkdown('*', '*'), isItalic: true, tooltip: 'In nghiêng'),
              _buildToolBtn('U', () => _insertMarkdown('<u>', '</u>'), tooltip: 'Gạch chân'),
              _buildToolBtn('S', () => _insertMarkdown('~~', '~~'), tooltip: 'Gạch ngang chữ'),
              _buildToolBtn('💡 Bôi sáng', () => _insertMarkdown('==', '=='), tooltip: 'Bôi sáng'),
              _buildToolBtn('</>', () => _insertMarkdown('`', '`'), tooltip: 'Mã code'),
            ]),
            _buildToolbarDivider(),

            // Lists & Tasks Group
            _buildToolbarGroup([
              _buildToolBtn('• List', () => _insertMarkdown('\n- '), tooltip: 'Danh sách gạch đầu dòng'),
              _buildToolBtn('1. Số', () => _insertMarkdown('\n1. '), tooltip: 'Danh sách đánh số'),
              _buildToolBtn('☑ Check', () => _insertMarkdown('\n- [ ] '), tooltip: 'Checklist công việc'),
            ]),
            _buildToolbarDivider(),

            // Extra Media & Tips
            _buildToolbarGroup([
              _buildToolBtn('❝ Trích dẫn', () => _insertMarkdown('\n> '), tooltip: 'Khung trích dẫn'),
              _buildToolBtn('➖ Phân cách', () => _insertMarkdown('\n\n---\n\n'), tooltip: 'Đường phân cách ngang'),
              _buildToolBtn('🖼️ Thêm ảnh', _showInsertImageDialog, tooltip: 'Chèn hình ảnh vào nội dung'),
              _buildToolBtn('🔗 Link', _showInsertLinkDialog, tooltip: 'Chèn liên kết'),
              _buildToolBtn('💡 Mẹo Thổ Địa', () => _insertMarkdown('\n### 💡 Mẹo từ Thổ Địa:\n- '), tooltip: 'Mẫu mẹo du lịch hữu ích'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarGroup(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: children),
    );
  }

  Widget _buildToolBtn(String label, VoidCallback onTap, {bool isBold = false, bool isItalic = false, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarDivider() {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFE2E8F0),
    );
  }

  /// 4. PAPER DOCUMENT CANVAS (Trang giấy soạn thảo cao cấp)
  Widget _buildEditorPaperCanvas() {
    final cover = _coverUrlController.text.trim();

    return Form(
      key: _formKey,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // White Paper Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Image Section
                if (cover.isNotEmpty) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 21 / 9,
                          child: _buildCoverImageWidget(),
                        ),
                      ),
                      if (!_isPendingApproval)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            children: [
                              InkWell(
                                onTap: _showCoverPickerSheet,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Đổi ảnh', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => setState(() {
                                  _coverBytes = null;
                                  _coverUrlController.clear();
                                }),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else if (!_isPendingApproval) ...[
                  InkWell(
                    onTap: _showCoverPickerSheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 20, color: Color(0xFF047857)),
                          SizedBox(width: 8),
                          Text(
                            'Thêm ảnh bìa cho bài viết (nhấn để chọn)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. Article Title (Large seamless input)
                TextFormField(
                  controller: _titleController,
                  enabled: !_isPendingApproval,
                  maxLines: null,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề bài viết' : null,
                  decoration: const InputDecoration(
                    hintText: 'Nhập tiêu đề cẩm nang du lịch (ví dụ: Top 5 Món Ăn Truyền Thống Đốn Tim Gen Z...)',
                    hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFCBD5E1)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Summary Excerpt Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextFormField(
                    controller: _summaryController,
                    enabled: !_isPendingApproval,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Mô tả tóm tắt ngắn về bài viết (1–2 câu thu hút người đọc)...',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),

                // 4. Markdown Content Editor (Document Area)
                TextFormField(
                  controller: _contentController,
                  enabled: !_isPendingApproval,
                  maxLines: null,
                  minLines: 14,
                  onChanged: (_) => _calculateReadTime(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập nội dung bài viết' : null,
                  decoration: const InputDecoration(
                    hintText: 'Bắt đầu viết cẩm nang du lịch của bạn... Nhập nội dung bài viết, tạo tiêu đề hoặc tải ảnh.',
                    hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8), height: 1.6),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // 5. Document Footer Metadata
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_contentController.text.length} ký tự',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '$_readTimeMinutes phút đọc',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 5. PREVIEW MODE (Đọc thử bài viết như người dùng thực tế)
  Widget _buildPreviewMode() {
    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Tiêu đề bài viết';
    final summary = _summaryController.text.trim();
    final content = _contentController.text.trim().isNotEmpty ? _contentController.text.trim() : 'Nội dung bài viết xem trước...';
    final cover = _coverUrlController.text.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 21 / 9,
                    child: _buildCoverImageWidget(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  _selectedCategory,
                  style: const TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.3),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text('$_readTimeMinutes phút đọc', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                  const SizedBox(width: 12),
                  const Text('Tác giả: Bạn', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                ],
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(left: BorderSide(color: Color(0xFF047857), width: 3.5)),
                  ),
                  child: Text(
                    summary,
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF475569), height: 1.5, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 20),
              Text(
                content,
                style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E293B), height: 1.7),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

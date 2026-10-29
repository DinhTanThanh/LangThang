import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/review_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/place_api_service.dart';
import '../../screens/auth/login_screen.dart';

class EditReviewModal extends StatefulWidget {
  final ReviewItemModel review;
  final Function(ReviewItemModel updatedReview)? onReviewUpdated;

  const EditReviewModal({
    super.key,
    required this.review,
    this.onReviewUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required ReviewItemModel review,
    Function(ReviewItemModel updatedReview)? onReviewUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: EditReviewModal(
          review: review,
          onReviewUpdated: onReviewUpdated,
        ),
      ),
    );
  }

  @override
  State<EditReviewModal> createState() => _EditReviewModalState();
}

class _EditReviewModalState extends State<EditReviewModal> {
  late int _rating;
  late TextEditingController _contentController;
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();

  late List<String> _existingImages;
  late List<String> _existingVideos;
  final List<XFile> _newPhotos = [];
  final List<XFile> _newVideos = [];

  bool _isSubmitting = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _rating = widget.review.rating;
    _contentController = TextEditingController(text: widget.review.content);
    _existingImages = List.from(widget.review.images);
    _existingVideos = List.from(widget.review.videos);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _imageUrlController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int val) {
    switch (val) {
      case 5:
        return 'Tuyệt vời';
      case 4:
        return 'Rất tốt';
      case 3:
        return 'Hài lòng';
      case 2:
        return 'Trung bình';
      case 1:
        return 'Không tốt';
      default:
        return '';
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        final total = _existingImages.length + _newPhotos.length;
        final remaining = 10 - total;
        if (remaining <= 0) {
          setState(() => _errorMessage = 'Bạn chỉ có thể lưu tối đa 10 hình ảnh.');
          return;
        }
        setState(() {
          _newPhotos.addAll(images.take(remaining));
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Không thể chọn ảnh: $e');
    }
  }

  void _addPhotoUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) return;
    if (_existingImages.length + _newPhotos.length >= 10) {
      setState(() => _errorMessage = 'Bạn chỉ có thể lưu tối đa 10 hình ảnh.');
      return;
    }
    setState(() {
      _existingImages.add(url);
      _imageUrlController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _pickVideo() async {
    try {
      if (_existingVideos.length + _newVideos.length >= 2) {
        setState(() => _errorMessage = 'Bạn chỉ có thể lưu tối đa 2 video.');
        return;
      }
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _newVideos.add(video);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Không thể chọn video: $e');
    }
  }

  void _addVideoUrl() {
    final url = _videoUrlController.text.trim();
    if (url.isEmpty) return;
    if (_existingVideos.length + _newVideos.length >= 2) {
      setState(() => _errorMessage = 'Bạn chỉ có thể lưu tối đa 2 video.');
      return;
    }
    setState(() {
      _existingVideos.add(url);
      _videoUrlController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _handleSubmit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập nội dung đánh giá của bạn.');
      return;
    }

    // 1. Kiểm tra trạng thái đăng nhập trước khi gửi
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục.'),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (loggedIn == true && mounted) {
        _handleSubmit();
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await PlaceApiService().updateReview(
        widget.review.id,
        rating: _rating,
        content: content,
        existingMediaUrls: _existingImages,
        videos: _existingVideos,
        photoFiles: _newPhotos,
        videoFiles: _newVideos,
      );

      if (mounted) {
        if (res.success && res.data != null) {
          widget.onReviewUpdated?.call(res.data!);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                  SizedBox(width: 8),
                  Text('Cập nhật đánh giá thành công!'),
                ],
              ),
              backgroundColor: Color(0xFF111827),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final msgLower = (res.message).toLowerCase();
          final isAuthError = msgLower.contains('đăng nhập') ||
              msgLower.contains('hết hạn') ||
              msgLower.contains('unauthorized') ||
              msgLower.contains('token') ||
              !await AuthService().isLoggedIn();

          if (isAuthError) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục.'),
                backgroundColor: Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
            final loggedIn = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
            if (loggedIn == true && mounted) {
              _handleSubmit();
              return;
            }
          }

          setState(() {
            _errorMessage = res.message.isNotEmpty ? res.message : 'Không thể cập nhật đánh giá.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Đã xảy ra lỗi khi cập nhật: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chỉnh sửa đánh giá',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFE4E6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9F1239)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Rating
                  const Text(
                    'MỨC ĐỘ HÀI LÒNG *',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...[1, 2, 3, 4, 5].map((star) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = star),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 34,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 10),
                      Text(
                        _getRatingLabel(_rating),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),


                  // Content
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NỘI DUNG CHIA SẺ CẢM NHẬN *',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _contentController,
                        builder: (context, value, _) {
                          return Text(
                            '${value.text.length}/2000',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF)),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    keyboardType: TextInputType.multiline,
                    autocorrect: true,
                    enableSuggestions: true,
                    maxLines: 4,
                    maxLength: 2000,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                    decoration: InputDecoration(
                      hintText: 'Cập nhật nội dung cảm nhận của bạn...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      counterText: '',
                      contentPadding: const EdgeInsets.all(14),
                      fillColor: const Color(0xFFF9FAFB),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Photos
                  const Text(
                    'HÌNH ẢNH ĐÍNH KÈM',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickPhotos,
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 15, color: Color(0xFF059669)),
                        label: const Text('Thêm ảnh', style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _imageUrlController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Hoặc dán link ảnh...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFF059669), size: 18),
                              onPressed: _addPhotoUrl,
                            ),
                          ),
                          onSubmitted: (_) => _addPhotoUrl(),
                        ),
                      ),
                    ],
                  ),

                  // Image list
                  if (_existingImages.isNotEmpty || _newPhotos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._existingImages.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final url = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(() => _existingImages.removeAt(idx)),
                                  child: const CircleAvatar(
                                    radius: 9,
                                    backgroundColor: Colors.black87,
                                    child: Icon(Icons.close, size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        ..._newPhotos.asMap().keys.map((idx) {
                          return Stack(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: const Color(0xFFF3F4F6),
                                ),
                                child: const Center(
                                  child: Icon(Icons.image, color: Color(0xFF059669), size: 28),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(() => _newPhotos.removeAt(idx)),
                                  child: const CircleAvatar(
                                    radius: 9,
                                    backgroundColor: Colors.black87,
                                    child: Icon(Icons.close, size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Videos
                  const Text(
                    'VIDEO ĐÍNH KÈM',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickVideo,
                        icon: const Icon(Icons.video_library_rounded, size: 15, color: Color(0xFF059669)),
                        label: const Text('Thêm video', style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _videoUrlController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Dán link video...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFF059669), size: 18),
                              onPressed: _addVideoUrl,
                            ),
                          ),
                          onSubmitted: (_) => _addVideoUrl(),
                        ),
                      ),
                    ],
                  ),

                  // Video list
                  if (_existingVideos.isNotEmpty || _newVideos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        ..._existingVideos.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final url = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 18, color: Color(0xFF059669)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    url,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => setState(() => _existingVideos.removeAt(idx)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                ),
                              ],
                            ),
                          );
                        }),
                        ..._newVideos.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final file = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.movie_creation_outlined, size: 18, color: Color(0xFF059669)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => setState(() => _newVideos.removeAt(idx)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Footer Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Hủy bỏ', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                  label: Text(
                    _isSubmitting ? 'Đang lưu...' : 'Lưu thay đổi',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

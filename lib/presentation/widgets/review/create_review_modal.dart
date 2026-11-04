import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/review_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/place_api_service.dart';
import '../../screens/auth/login_screen.dart';

class CreateReviewModal extends StatefulWidget {
  final int placeId;
  final String placeName;
  final Function(ReviewItemModel newReview)? onReviewAdded;

  const CreateReviewModal({
    super.key,
    required this.placeId,
    required this.placeName,
    this.onReviewAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required int placeId,
    required String placeName,
    Function(ReviewItemModel newReview)? onReviewAdded,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: CreateReviewModal(
          placeId: placeId,
          placeName: placeName,
          onReviewAdded: onReviewAdded,
        ),
      ),
    );
  }

  @override
  State<CreateReviewModal> createState() => _CreateReviewModalState();
}

class _CreateReviewModalState extends State<CreateReviewModal> {
  int _rating = 5;
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();

  final List<XFile> _selectedPhotos = [];
  final List<String> _photoUrls = [];

  final List<XFile> _selectedVideos = [];
  final List<String> _videoUrls = [];

  bool _isSubmitting = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

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
        final remaining = 10 - (_selectedPhotos.length + _photoUrls.length);
        if (remaining <= 0) {
          setState(() => _errorMessage = 'Bạn chỉ có thể tải lên tối đa 10 hình ảnh.');
          return;
        }
        setState(() {
          _selectedPhotos.addAll(images.take(remaining));
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Không thể chọn ảnh từ thiết bị: $e');
    }
  }

  void _addPhotoUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) return;
    if (_selectedPhotos.length + _photoUrls.length >= 10) {
      setState(() => _errorMessage = 'Bạn chỉ có thể thêm tối đa 10 hình ảnh.');
      return;
    }
    setState(() {
      _photoUrls.add(url);
      _imageUrlController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _pickVideo() async {
    try {
      if (_selectedVideos.length + _videoUrls.length >= 2) {
        setState(() => _errorMessage = 'Bạn chỉ có thể đính kèm tối đa 2 video.');
        return;
      }
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideos.add(video);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Không thể chọn video từ thiết bị: $e');
    }
  }

  void _addVideoUrl() {
    final url = _videoUrlController.text.trim();
    if (url.isEmpty) return;
    if (_selectedVideos.length + _videoUrls.length >= 2) {
      setState(() => _errorMessage = 'Bạn chỉ có thể đính kèm tối đa 2 video.');
      return;
    }
    setState(() {
      _videoUrls.add(url);
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
        // Tự động tiếp tục gửi đánh giá sau khi đăng nhập thành công
        _handleSubmit();
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await PlaceApiService().submitReview(
        widget.placeId,
        rating: _rating,
        content: content,
        images: _photoUrls,
        videos: _videoUrls,
        photoFiles: _selectedPhotos,
        videoFiles: _selectedVideos,
      );

      if (mounted) {
        if (res.success && res.data != null) {
          widget.onReviewAdded?.call(res.data!);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                  SizedBox(width: 8),
                  Text('Đăng đánh giá thành công! Cảm ơn bạn.'),
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
            _errorMessage = res.message.isNotEmpty ? res.message : 'Không thể gửi đánh giá lúc này.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Đã xảy ra lỗi khi gửi đánh giá: $e';
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
    final activeRating = _rating;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đánh giá trải nghiệm địa điểm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        widget.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          // Scrollable Body
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

                  // 1. Rating Stars
                  const Text(
                    'MỨC ĐỘ HÀI LÒNG *',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4B5563),
                      letterSpacing: 0.5,
                    ),
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
                              star <= activeRating ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 34,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 10),
                      Text(
                        _getRatingLabel(activeRating),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),


                  // 3. Content textarea
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NỘI DUNG CHIA SẺ CẢM NHẬN *',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4B5563),
                          letterSpacing: 0.5,
                        ),
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
                      hintText: 'Chia sẻ chi tiết trải nghiệm thực tế của bạn (không gian, dịch vụ, giá vé, lời khuyên cho người đến sau)...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      counterText: '',
                      contentPadding: const EdgeInsets.all(14),
                      fillColor: const Color(0xFFF9FAFB),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Photos Section
                  const Text(
                    'HÌNH ẢNH ĐÍNH KÈM (TỐI ĐA 10 ẢNH)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4B5563),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Photo action bar (Choose file + Paste URL)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickPhotos,
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 15, color: Color(0xFF059669)),
                        label: const Text('Chọn ảnh', style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF059669)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _imageUrlController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Hoặc dán link ảnh trực tiếp...',
                            hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
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

                  // Photo Previews Grid
                  if (_selectedPhotos.isNotEmpty || _photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._selectedPhotos.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final file = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  color: const Color(0xFFF3F4F6),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: const Center(
                                  child: Icon(Icons.image, color: Color(0xFF059669), size: 28),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedPhotos.removeAt(idx)),
                                  child: const CircleAvatar(
                                    radius: 9,
                                    backgroundColor: Colors.black87,
                                    child: Icon(Icons.close, size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                left: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                  color: Colors.black54,
                                  child: Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 8),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        ..._photoUrls.asMap().entries.map((entry) {
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
                                  color: const Color(0xFFF3F4F6),
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
                                  onTap: () => setState(() => _photoUrls.removeAt(idx)),
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

                  // 5. Video Section
                  const Text(
                    'VIDEO ĐÍNH KÈM / LINK VIDEO (TỐI ĐA 2 VIDEO)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4B5563),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickVideo,
                        icon: const Icon(Icons.video_library_rounded, size: 15, color: Color(0xFF059669)),
                        label: const Text('Chọn video', style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF059669)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _videoUrlController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Dán link video (MP4/YouTube)...',
                            hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
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

                  // Video preview items
                  if (_selectedVideos.isNotEmpty || _videoUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        ..._selectedVideos.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final file = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                                  onPressed: () => setState(() => _selectedVideos.removeAt(idx)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                ),
                              ],
                            ),
                          );
                        }),
                        ..._videoUrls.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final url = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                                  onPressed: () => setState(() => _videoUrls.removeAt(idx)),
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
                      : const Icon(Icons.send_rounded, size: 15, color: Colors.white),
                  label: Text(
                    _isSubmitting ? 'Đang gửi...' : 'Đăng đánh giá',
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

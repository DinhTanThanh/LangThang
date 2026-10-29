import 'package:flutter/material.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/report_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/place_api_service.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/profile/user_profile_screen.dart';
import '../report/report_modal_sheet.dart';
import 'edit_review_modal.dart';
import 'media_lightbox_modal.dart';
import 'review_comment_thread.dart';

class ReviewItemCard extends StatefulWidget {
  final ReviewItemModel review;
  final bool isAuthenticated;
  final UserModel? currentUser;
  final Function(ReviewItemModel updatedReview)? onReviewUpdated;
  final Function(int reviewId)? onReviewDeleted;

  const ReviewItemCard({
    super.key,
    required this.review,
    required this.isAuthenticated,
    this.currentUser,
    this.onReviewUpdated,
    this.onReviewDeleted,
  });

  @override
  State<ReviewItemCard> createState() => _ReviewItemCardState();
}

class _ReviewItemCardState extends State<ReviewItemCard> {
  bool _isCommentsOpen = false;
  late int _likesCount;
  bool _isLiked = false;
  late int _commentsCount;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.review.likesCount;
    _isLiked = widget.review.isLiked;
    _commentsCount = widget.review.commentsCount;
  }

  @override
  void didUpdateWidget(covariant ReviewItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.likesCount != widget.review.likesCount) {
      _likesCount = widget.review.likesCount;
    }
    if (oldWidget.review.isLiked != widget.review.isLiked) {
      _isLiked = widget.review.isLiked;
    }
    if (oldWidget.review.commentsCount != widget.review.commentsCount) {
      _commentsCount = widget.review.commentsCount;
    }
  }

  bool get _isOwner {
    if (!widget.isAuthenticated || widget.currentUser == null) return false;
    final currentId = widget.currentUser!.id;
    return currentId == widget.review.userId ||
        widget.currentUser!.username == widget.review.userName ||
        (widget.review.userId == 'u_current');
  }

  Future<void> _handleLikeToggle() async {
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để thích bài đánh giá.'),
          backgroundColor: Color(0xFF1F2937),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final didLogin = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if ((didLogin == true || await AuthService().isLoggedIn()) && mounted) {
        // Tiếp tục tự động like sau khi đăng nhập thành công
        await _handleLikeToggle();
        return;
      }
      return;
    }

    final prevLiked = _isLiked;
    final prevLikes = _likesCount;

    // Optimistic UI update
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount = (_likesCount - 1).clamp(0, 999999);
      } else {
        _isLiked = true;
        _likesCount += 1;
      }
    });

    try {
      final res = await PlaceApiService().toggleReviewLike(widget.review.id);
      if (res.success && res.data != null) {
        if (mounted) {
          setState(() {
            _isLiked = res.data!['isLiked'] == true;
            if (res.data!['likesCount'] != null) {
              _likesCount = (res.data!['likesCount'] as num).toInt();
            }
          });
        }
      } else {
        final msgLower = (res.message).toLowerCase();
        final isAuthError = res.message == 'AUTH_REQUIRED' ||
            msgLower.contains('auth_required') ||
            msgLower.contains('đăng nhập') ||
            msgLower.contains('unauthorized') ||
            msgLower.contains('token') ||
            msgLower.contains('hết hạn') ||
            !await AuthService().isLoggedIn();

        // Revert on failure
        if (mounted) {
          setState(() {
            _isLiked = prevLiked;
            _likesCount = prevLikes;
          });
        }

        if (isAuthError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng đăng nhập để tiếp tục thích bài đánh giá.'),
              backgroundColor: Color(0xFF1F2937),
              behavior: SnackBarBehavior.floating,
            ),
          );
          final didLogin = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          if ((didLogin == true || await AuthService().isLoggedIn()) && mounted) {
            await _handleLikeToggle();
            return;
          }
        } else if (mounted && res.message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = prevLiked;
          _likesCount = prevLikes;
        });
      }
    }
  }


  Future<void> _handleDeleteReview() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bạn có chắc chắn muốn xóa bài đánh giá này không? Thao tác này không thể hoàn tác.',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final res = await PlaceApiService().deleteReview(widget.review.id);
      if (res.success && mounted) {
        widget.onReviewDeleted?.call(widget.review.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bài đánh giá thành công.')),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message.isNotEmpty ? res.message : 'Không thể xóa bài đánh giá.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xảy ra lỗi khi xóa bài đánh giá.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final hasAvatar = review.userAvatar != null &&
        review.userAvatar!.trim().isNotEmpty &&
        review.userAvatar!.startsWith('http');
    final hasPhotos = review.images.isNotEmpty;
    final hasVideos = review.videos.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          // Header: Avatar, Name, Time, Star, Owner Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  UserProfileScreen.navigate(
                    context,
                    userId: review.userId.isNotEmpty ? review.userId : null,
                    userName: review.userName,
                    userAvatar: review.userAvatar,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: hasAvatar ? Colors.transparent : const Color(0xFFD1FAE5),
                      backgroundImage: hasAvatar ? NetworkImage(review.userAvatar!) : null,
                      child: !hasAvatar
                          ? Text(
                              review.userInitials,
                              style: const TextStyle(
                                color: Color(0xFF065F46),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.userName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          review.timeAgo,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  if (_isOwner) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF4B5563)),
                            onPressed: () => EditReviewModal.show(
                              context,
                              review: review,
                              onReviewUpdated: widget.onReviewUpdated,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            tooltip: 'Chỉnh sửa',
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: _isDeleting
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFE11D48)),
                                  )
                                : const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFE11D48)),
                            onPressed: _isDeleting ? null : _handleDeleteReview,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            tooltip: 'Xóa đánh giá',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Rating pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          '${review.rating}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Content
          if (review.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.content,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ],

          // Media (Photos & Videos)
          if (hasPhotos || hasVideos) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhotos)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: review.images.map((img) {
                        return GestureDetector(
                          onTap: () => MediaLightboxModal.show(context, mediaUrl: img, mediaType: 'image'),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: const Color(0xFFF3F4F6), child: const Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                if (hasVideos) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: review.videos.map((vid) {
                        return GestureDetector(
                          onTap: () => MediaLightboxModal.show(context, mediaUrl: vid, mediaType: 'video'),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 120,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF374151)),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 36),
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF059669).withValues(alpha: 0.9),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Footer Action Bar: Helpful Like, Comments Toggle, Share
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _handleLikeToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isLiked ? const Color(0xFFD1FAE5) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isLiked ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                            size: 13,
                            color: _isLiked ? const Color(0xFF059669) : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _likesCount > 0 ? '$_likesCount' : 'Hữu ích',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _isLiked ? const Color(0xFF065F46) : const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: () => setState(() => _isCommentsOpen = !_isCommentsOpen),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isCommentsOpen ? const Color(0xFFD1FAE5) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isCommentsOpen ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: _isCommentsOpen ? const Color(0xFF059669) : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _commentsCount > 0 ? '$_commentsCount phản hồi' : 'Bình luận',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _isCommentsOpen ? const Color(0xFF065F46) : const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (!_isOwner)
                IconButton(
                  icon: const Icon(Icons.flag_outlined, size: 16, color: Color(0xFF9CA3AF)),
                  onPressed: () {
                    ReportModalSheet.show(
                      context,
                      targetInfo: ReportTargetInfo.forReview(
                        id: review.id,
                        userName: review.userName,
                        reviewContent: review.content,
                        rating: review.rating > 0 ? review.rating.toDouble() : null,
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Báo cáo vi phạm',
                ),
            ],
          ),

          // Nested Comment Thread (Expandable)
          if (_isCommentsOpen) ...[
            const SizedBox(height: 6),
            ReviewCommentThread(
              reviewId: review.id,
              onCommentsCountChange: (newCount) {
                if (mounted) {
                  setState(() => _commentsCount = newCount);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

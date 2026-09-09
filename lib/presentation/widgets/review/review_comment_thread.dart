import 'package:flutter/material.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/place_api_service.dart';
import 'review_comment_item.dart';

class ReviewCommentThread extends StatefulWidget {
  final int reviewId;
  final Function(int newCount)? onCommentsCountChange;

  const ReviewCommentThread({
    super.key,
    required this.reviewId,
    this.onCommentsCountChange,
  });

  @override
  State<ReviewCommentThread> createState() => _ReviewCommentThreadState();
}

class _ReviewCommentThreadState extends State<ReviewCommentThread> {
  final TextEditingController _rootController = TextEditingController();
  List<ReviewCommentModel> _comments = [];
  int _totalComments = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  UserModel? _currentUser;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchComments();
  }

  @override
  void dispose() {
    _rootController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService().isLoggedIn();
    final user = await AuthService().getCachedUser();
    if (mounted) {
      setState(() {
        _isAuthenticated = loggedIn;
        _currentUser = user;
      });
    }
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await PlaceApiService().getReviewComments(widget.reviewId);
      if (mounted) {
        if (res.data != null) {
          setState(() {
            _comments = res.data!.items;
            _totalComments = res.data!.totalComments;
            widget.onCommentsCountChange?.call(_totalComments);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tải bình luận lúc này.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRootSubmit() async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để gửi bình luận.')),
      );
      return;
    }

    final text = _rootController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await PlaceApiService().createReviewComment(
        widget.reviewId,
        content: text,
      );

      if (mounted) {
        if (res.data != null) {
          setState(() {
            _comments = [res.data!, ..._comments];
            _totalComments += 1;
            widget.onCommentsCountChange?.call(_totalComments);
            _rootController.clear();
          });
        } else {
          setState(() {
            _errorMessage = res.message.isNotEmpty ? res.message : 'Không thể gửi bình luận.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Đã xảy ra lỗi khi gửi bình luận.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _handleReplySubmit(int parentId, String content) async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để gửi phản hồi.')),
      );
      return false;
    }

    try {
      final res = await PlaceApiService().createReviewComment(
        widget.reviewId,
        content: content,
        parentId: parentId,
      );

      if (res.data != null && mounted) {
        setState(() {
          _comments = _comments.map((c) {
            if (c.id == parentId) {
              return c.copyWith(replies: [...c.replies, res.data!]);
            }
            return c;
          }).toList();
          _totalComments += 1;
          widget.onCommentsCountChange?.call(_totalComments);
        });
        return true;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message.isNotEmpty ? res.message : 'Không thể gửi phản hồi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi: $e')),
        );
      }
    }
    return false;
  }

  Future<bool> _handleCommentUpdate(int commentId, String content) async {
    try {
      final res = await PlaceApiService().updateReviewComment(
        commentId,
        content: content,
      );

      if (res.data != null && mounted) {
        setState(() {
          _comments = _comments.map((c) {
            if (c.id == commentId) {
              return c.copyWith(content: res.data?.content ?? content);
            }
            if (c.replies.isNotEmpty) {
              return c.copyWith(
                replies: c.replies.map((r) {
                  if (r.id == commentId) {
                    return r.copyWith(content: res.data?.content ?? content);
                  }
                  return r;
                }).toList(),
              );
            }
            return c;
          }).toList();
        });
        return true;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message.isNotEmpty ? res.message : 'Không thể cập nhật bình luận.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi: $e')),
        );
      }
    }
    return false;
  }

  Future<bool> _handleCommentDelete(int commentId) async {
    try {
      final res = await PlaceApiService().deleteReviewComment(commentId);
      if (res.success && mounted) {
        int removedCount = 0;
        final next = <ReviewCommentModel>[];
        for (final c in _comments) {
          if (c.id == commentId) {
            removedCount += 1 + c.replies.length;
            continue;
          }
          if (c.replies.any((r) => r.id == commentId)) {
            removedCount += 1;
            next.add(c.copyWith(replies: c.replies.filter((r) => r.id != commentId)));
          } else {
            next.add(c);
          }
        }
        setState(() {
          _comments = next;
          _totalComments = (_totalComments - (removedCount > 0 ? removedCount : 1)).clamp(0, 999999);
          widget.onCommentsCountChange?.call(_totalComments);
        });
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasUserAvatar = _currentUser?.avatarUrl != null &&
        _currentUser!.avatarUrl.isNotEmpty &&
        _currentUser!.avatarUrl.startsWith('http');

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Root input form
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: hasUserAvatar ? Colors.transparent : const Color(0xFFD1FAE5),
                backgroundImage: hasUserAvatar ? NetworkImage(_currentUser!.avatarUrl) : null,
                child: !hasUserAvatar
                    ? Text(
                        _currentUser != null && _currentUser!.fullName.isNotEmpty
                            ? _currentUser!.fullName[0].toUpperCase()
                            : 'B',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _rootController,
                          enabled: !_isSubmitting,
                          keyboardType: TextInputType.text,
                          autocorrect: true,
                          enableSuggestions: true,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: _isAuthenticated
                                ? 'Viết bình luận của bạn...'
                                : 'Đăng nhập để bình luận...',
                            hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 7),
                          ),
                          onSubmitted: (_) => _handleRootSubmit(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _isSubmitting ? null : _handleRootSubmit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.send_rounded, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Gửi',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE4E6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFE11D48)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFF9F1239), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Comments List
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                  ),
                ),
              ),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'Chưa có bình luận nào. Hãy là người đầu tiên để lại phản hồi!',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ..._comments.map(
              (c) => ReviewCommentItem(
                key: ValueKey(c.id),
                comment: c,
                isAuthenticated: _isAuthenticated,
                currentUser: _currentUser,
                onReplySubmit: _handleReplySubmit,
                onCommentUpdate: _handleCommentUpdate,
                onCommentDelete: _handleCommentDelete,
              ),
            ),
        ],
      ),
    );
  }
}

extension _IterableExt<T> on Iterable<T> {
  List<T> filter(bool Function(T) test) => where(test).toList();
}

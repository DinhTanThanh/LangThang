import 'package:flutter/material.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';

class ReviewCommentItem extends StatefulWidget {
  final ReviewCommentModel comment;
  final bool isAuthenticated;
  final UserModel? currentUser;
  final Future<bool> Function(int parentId, String content) onReplySubmit;
  final Future<bool> Function(int commentId, String content) onCommentUpdate;
  final Future<bool> Function(int commentId) onCommentDelete;

  const ReviewCommentItem({
    super.key,
    required this.comment,
    required this.isAuthenticated,
    this.currentUser,
    required this.onReplySubmit,
    required this.onCommentUpdate,
    required this.onCommentDelete,
  });

  @override
  State<ReviewCommentItem> createState() => _ReviewCommentItemState();
}

class _ReviewCommentItemState extends State<ReviewCommentItem> {
  bool _isReplying = false;
  final TextEditingController _replyController = TextEditingController();
  bool _isSubmittingReply = false;

  bool _isEditing = false;
  late TextEditingController _editController;
  bool _isSubmittingEdit = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.comment.content);
  }

  @override
  void didUpdateWidget(covariant ReviewCommentItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.content != widget.comment.content && !_isEditing) {
      _editController.text = widget.comment.content;
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  bool get _isOwner {
    if (!widget.isAuthenticated || widget.currentUser == null) return false;
    final currentId = widget.currentUser!.id;
    return currentId == widget.comment.userId ||
        widget.currentUser!.username == widget.comment.userName ||
        (widget.comment.userId == 'u_current');
  }

  void _handleOpenReply({String? mentionName}) {
    if (!widget.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để gửi phản hồi.')),
      );
      return;
    }
    setState(() {
      _isReplying = true;
      if (mentionName != null && mentionName != widget.comment.userName) {
        _replyController.text = '@$mentionName ';
      } else {
        _replyController.clear();
      }
    });
  }

  Future<void> _handleSendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmittingReply = true);
    final success = await widget.onReplySubmit(widget.comment.id, text);
    if (mounted) {
      setState(() {
        _isSubmittingReply = false;
        if (success) {
          _replyController.clear();
          _isReplying = false;
        }
      });
    }
  }

  Future<void> _handleSaveEdit() async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmittingEdit = true);
    final success = await widget.onCommentUpdate(widget.comment.id, text);
    if (mounted) {
      setState(() {
        _isSubmittingEdit = false;
        if (success) {
          _isEditing = false;
        }
      });
    }
  }

  Future<void> _handleDeleteComment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bạn có chắc chắn muốn xóa bình luận này cùng tất cả phản hồi liên quan?',
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

    if (confirm == true) {
      await widget.onCommentDelete(widget.comment.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final hasAvatar = comment.userAvatar != null &&
        comment.userAvatar!.trim().isNotEmpty &&
        comment.userAvatar!.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Parent Comment Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: hasAvatar ? Colors.transparent : const Color(0xFFD1FAE5),
                backgroundImage: hasAvatar ? NetworkImage(comment.userAvatar!) : null,
                child: !hasAvatar
                    ? Text(
                        comment.userInitials,
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEditing)
                      _buildEditForm()
                    else
                      _buildCommentBubble(comment),

                    if (!_isEditing) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _handleOpenReply(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.reply_rounded, size: 13, color: Color(0xFF059669)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Phản hồi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isOwner) ...[
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                _isEditing = true;
                                _editController.text = comment.content;
                              }),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  'Sửa',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _handleDeleteComment,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  'Xóa',
                                  style: TextStyle(fontSize: 11, color: Color(0xFFE11D48), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Inline Reply Form (when replying to this comment)
          if (_isReplying)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 8, bottom: 4),
              child: _buildReplyForm(),
            ),

          // Nested Replies List (with vertical branch tree indentation)
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 8),
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                ),
                child: Column(
                  children: comment.replies.map((reply) {
                    return _ReplyItemRow(
                      reply: reply,
                      parentComment: comment,
                      isAuthenticated: widget.isAuthenticated,
                      currentUser: widget.currentUser,
                      onReplySubmit: widget.onReplySubmit,
                      onCommentUpdate: widget.onCommentUpdate,
                      onCommentDelete: widget.onCommentDelete,
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(ReviewCommentModel comment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                comment.userName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                comment.timeAgo,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            comment.content,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF374151),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF059669)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _editController,
            keyboardType: TextInputType.text,
            autocorrect: true,
            enableSuggestions: true,
            maxLines: 2,
            maxLength: 1000,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _isEditing = false;
                  _editController.text = widget.comment.content;
                }),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('Hủy', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: _isSubmittingEdit ? null : _handleSaveEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: _isSubmittingEdit
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                      )
                    : const Text('Lưu', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyForm() {
    final userAvatar = widget.currentUser?.avatarUrl;
    final hasUserAvatar = userAvatar != null && userAvatar.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFFD1FAE5),
            backgroundImage: hasUserAvatar ? NetworkImage(userAvatar) : null,
            child: !hasUserAvatar
                ? Text(
                    widget.currentUser != null && widget.currentUser!.fullName.isNotEmpty
                        ? widget.currentUser!.fullName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _replyController,
              keyboardType: TextInputType.text,
              autocorrect: true,
              enableSuggestions: true,
              autofocus: true,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: 'Trả lời ${widget.comment.userName}...',
                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 7),
              ),
              onSubmitted: (_) => _handleSendReply(),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _isReplying = false),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Hủy',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isSubmittingReply ? null : _handleSendReply,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isSubmittingReply
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'Gửi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyItemRow extends StatefulWidget {
  final ReviewCommentModel reply;
  final ReviewCommentModel parentComment;
  final bool isAuthenticated;
  final UserModel? currentUser;
  final Future<bool> Function(int parentId, String content) onReplySubmit;
  final Future<bool> Function(int commentId, String content) onCommentUpdate;
  final Future<bool> Function(int commentId) onCommentDelete;

  const _ReplyItemRow({
    required this.reply,
    required this.parentComment,
    required this.isAuthenticated,
    this.currentUser,
    required this.onReplySubmit,
    required this.onCommentUpdate,
    required this.onCommentDelete,
  });

  @override
  State<_ReplyItemRow> createState() => _ReplyItemRowState();
}

class _ReplyItemRowState extends State<_ReplyItemRow> {
  bool _isEditing = false;
  late TextEditingController _editController;
  bool _isSubmittingEdit = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.reply.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  bool get _isOwner {
    if (!widget.isAuthenticated || widget.currentUser == null) return false;
    final currentId = widget.currentUser!.id;
    return currentId == widget.reply.userId ||
        widget.currentUser!.username == widget.reply.userName ||
        (widget.reply.userId == 'u_current');
  }

  Future<void> _handleSaveEdit() async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmittingEdit = true);
    final success = await widget.onCommentUpdate(widget.reply.id, text);
    if (mounted) {
      setState(() {
        _isSubmittingEdit = false;
        if (success) {
          _isEditing = false;
        }
      });
    }
  }

  Future<void> _handleDeleteReply() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Xóa phản hồi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bạn có chắc chắn muốn xóa phản hồi này?',
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

    if (confirm == true) {
      await widget.onCommentDelete(widget.reply.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.reply;
    final hasAvatar = reply.userAvatar != null &&
        reply.userAvatar!.trim().isNotEmpty &&
        reply.userAvatar!.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: hasAvatar ? Colors.transparent : const Color(0xFFE0E7FF),
            backgroundImage: hasAvatar ? NetworkImage(reply.userAvatar!) : null,
            child: !hasAvatar
                ? Text(
                    reply.userInitials,
                    style: const TextStyle(
                      color: Color(0xFF3730A3),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditing)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF059669)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          controller: _editController,
                          keyboardType: TextInputType.text,
                          autocorrect: true,
                          enableSuggestions: true,
                          maxLines: 2,
                          maxLength: 1000,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            counterText: '',
                          ),
                          autofocus: true,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _isEditing = false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Hủy', style: TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
                            ),
                            ElevatedButton(
                              onPressed: _isSubmittingEdit ? null : _handleSaveEdit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: _isSubmittingEdit
                                  ? const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                    )
                                  : const Text('Lưu', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              reply.userName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              reply.timeAgo,
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reply.content,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF374151),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!_isEditing && _isOwner) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _isEditing = true;
                          _editController.text = reply.content;
                        }),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Sửa',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 10)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _handleDeleteReply,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Xóa',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFFE11D48), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

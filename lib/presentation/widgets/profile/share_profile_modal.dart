import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/models/user_profile_data_models.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_api_service.dart';
import '../../../data/services/friend_api_service.dart';
import '../../screens/chat/chat_room_screen.dart';

class ShareProfileContactItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final int? roomId;
  final int? userId;
  final bool isGroup;

  const ShareProfileContactItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.roomId,
    this.userId,
    this.isGroup = false,
  });
}

class ShareProfileModal extends StatefulWidget {
  final PublicUserProfileModel profile;

  const ShareProfileModal({
    super.key,
    required this.profile,
  });

  static Future<void> show(BuildContext context, {required PublicUserProfileModel profile}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ShareProfileModal(profile: profile),
      ),
    );
  }

  @override
  State<ShareProfileModal> createState() => _ShareProfileModalState();
}

class _ShareProfileModalState extends State<ShareProfileModal> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isAuthenticated = false;
  bool _isLoadingContacts = false;
  List<ShareProfileContactItem> _contacts = [];
  String _searchQuery = '';

  String? _sendingContactId;
  final Set<String> _sentContactIds = {};
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _loadAuthAndContacts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthAndContacts() async {
    final loggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;

    setState(() {
      _isAuthenticated = loggedIn;
    });

    if (!loggedIn) return;

    setState(() => _isLoadingContacts = true);

    try {
      final inboxRes = await ChatApiService().getInbox();
      final friendsRes = await FriendApiService().getFriends();
      if (!mounted) return;

      final inboxList = inboxRes.data ?? <InboxItem>[];
      final friendsList = friendsRes.data?.friends ?? <FriendUser>[];

      final List<ShareProfileContactItem> combined = [];
      final Set<String> seenKeys = {};

      // 1. Add active rooms
      for (final room in inboxList) {
        final key = 'room-${room.roomId}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          combined.add(
            ShareProfileContactItem(
              id: key,
              name: room.name.isNotEmpty ? room.name : (room.isGroup ? 'Nhóm trò chuyện' : 'Bạn bè'),
              avatarUrl: (room.avatarUrl != null && room.avatarUrl!.isNotEmpty) ? room.avatarUrl : null,
              roomId: room.roomId,
              userId: room.otherUserId,
              isGroup: room.isGroup,
            ),
          );
        }
      }

      // 2. Add friends
      for (final f in friendsList) {
        final hasExisting = combined.any((c) => c.userId == f.id && !c.isGroup);
        if (!hasExisting) {
          final key = 'user-${f.id}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            combined.add(
              ShareProfileContactItem(
                id: key,
                name: f.fullName.isNotEmpty ? f.fullName : 'Người dùng',
                avatarUrl: f.avatarUrl.isNotEmpty ? f.avatarUrl : null,
                userId: f.id,
                isGroup: false,
              ),
            );
          }
        }
      }

      setState(() {
        _contacts = combined;
        _isLoadingContacts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingContacts = false);
    }
  }

  List<ShareProfileContactItem> get _filteredContacts {
    if (_searchQuery.trim().isEmpty) return _contacts;
    final q = _searchQuery.toLowerCase().trim();
    return _contacts.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  String get _profileUrl => 'https://langthang.vn/users/${widget.profile.id}';

  String _buildShareMessage() {
    final note = _noteController.text.trim();
    if (note.isNotEmpty) {
      return '$note\n\nXem trang cá nhân của ${widget.profile.fullName} trên Lãng Thang: $_profileUrl';
    }
    return 'Xem trang cá nhân của ${widget.profile.fullName} trên Lãng Thang: $_profileUrl';
  }

  Future<void> _handleSendToChat(ShareProfileContactItem contact) async {
    if (!_isAuthenticated) {
      _showToast('Vui lòng đăng nhập để gửi qua tin nhắn!');
      return;
    }

    if (_sentContactIds.contains(contact.id) || _sendingContactId != null) return;

    setState(() => _sendingContactId = contact.id);

    try {
      int? targetRoomId = contact.roomId;

      if (targetRoomId == null && contact.userId != null) {
        final directRoomRes = await ChatApiService().getOrCreateDirectRoom(
          contact.userId!,
          targetUserName: contact.name,
          targetUserAvatar: contact.avatarUrl,
        );
        targetRoomId = directRoomRes.data;
      }

      if (targetRoomId == null) {
        throw Exception('Không tìm thấy phòng trò chuyện');
      }

      final msg = _buildShareMessage();

      final res = await ChatApiService().sendMessage(
        roomId: targetRoomId,
        content: msg,
      );

      if (res.success && mounted) {
        setState(() {
          _sentContactIds.add(contact.id);
          _sendingContactId = null;
        });
        _showToast('Đã gửi trang cá nhân tới ${contact.name}!');
      } else if (!res.success && mounted) {
        setState(() => _sendingContactId = null);
        _showToast('Không thể gửi: ${res.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingContactId = null);
        _showToast('Không thể gửi lúc này: $e');
      }
    }
  }

  Future<void> _handleOpenChatWithProfile(ShareProfileContactItem contact) async {
    if (!_isAuthenticated) {
      _showToast('Vui lòng đăng nhập để gửi qua tin nhắn!');
      return;
    }

    try {
      int? targetRoomId = contact.roomId;

      if (targetRoomId == null && contact.userId != null) {
        final directRoomRes = await ChatApiService().getOrCreateDirectRoom(
          contact.userId!,
          targetUserName: contact.name,
          targetUserAvatar: contact.avatarUrl,
        );
        targetRoomId = directRoomRes.data;
      }

      if (targetRoomId == null) {
        throw Exception('Không tìm thấy phòng trò chuyện');
      }

      if (!mounted) return;
      Navigator.pop(context); // Close share modal

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            roomId: targetRoomId!,
            roomName: contact.name,
            roomAvatar: contact.avatarUrl,
            isGroup: contact.isGroup,
            otherUserId: contact.userId,
            initialText: _buildShareMessage(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showToast('Không thể mở cuộc trò chuyện: $e');
      }
    }
  }

  Future<void> _handleCopyLink() async {
    try {
      await Clipboard.setData(ClipboardData(text: _profileUrl));
      setState(() => _isCopied = true);
      _showToast('Đã sao chép liên kết trang cá nhân!');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isCopied = false);
      });
    } catch (_) {
      _showToast('Không thể sao chép liên kết.');
    }
  }

  Future<void> _handleShareFacebook() async {
    final encodedUrl = Uri.encodeComponent(_profileUrl);
    final encodedQuote = Uri.encodeComponent('Xem hồ sơ của ${widget.profile.fullName} trên Lãng Thang');
    final fbWebSharerUri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$encodedUrl&quote=$encodedQuote');

    try {
      final launched = await launchUrl(fbWebSharerUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Xem hồ sơ của ${widget.profile.fullName} trên Lãng Thang: $_profileUrl',
            subject: widget.profile.fullName,
          ),
        );
      }
    } catch (_) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Xem hồ sơ của ${widget.profile.fullName} trên Lãng Thang: $_profileUrl',
            subject: widget.profile.fullName,
          ),
        );
      } catch (e) {
        _handleCopyLink();
      }
    }
  }

  Future<void> _handleSystemShare() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Xem trang cá nhân của ${widget.profile.fullName} trên Lãng Thang: $_profileUrl',
          subject: widget.profile.fullName,
        ),
      );
    } catch (_) {
      _handleCopyLink();
    }
  }

  Future<void> _handleShareMessenger() async {
    final encodedUrl = Uri.encodeComponent(_profileUrl);
    final msgrAppUri = Uri.parse('fb-messenger://share/?link=$encodedUrl');
    final msgrWebUri = Uri.parse('https://m.me');

    try {
      final launched = await launchUrl(msgrAppUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(msgrWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(msgrWebUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await _handleSystemShare();
      }
    }
  }

  Future<void> _handleShareWhatsApp() async {
    final text = 'Xem hồ sơ của ${widget.profile.fullName} trên Lãng Thang: $_profileUrl';
    final waUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final waWebUri = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');

    try {
      final launched = await launchUrl(waUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        await _handleSystemShare();
      }
    }
  }

  Future<void> _handleShareTelegram() async {
    final text = 'Xem hồ sơ của ${widget.profile.fullName} trên Lãng Thang';
    final tgUri = Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(_profileUrl)}&text=${Uri.encodeComponent(text)}');
    try {
      final launched = await launchUrl(tgUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await _handleSystemShare();
      }
    } catch (_) {
      await _handleSystemShare();
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== HEADER =====
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.share_outlined,
                        color: Color(0xFF059669),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Chia sẻ trang cá nhân',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== PROFILE PREVIEW CARD =====
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 62,
                              height: 62,
                              child: (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
                                  ? Image.network(
                                      profile.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xFFE2E8F0),
                                        child: const Icon(Icons.person, color: Color(0xFF94A3B8), size: 30),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(Icons.person, color: Color(0xFF94A3B8), size: 30),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        profile.rankLevel,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF065F46),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${profile.reputationScore} điểm',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profile.bio != null && profile.bio!.isNotEmpty
                                      ? profile.bio!
                                      : (profile.joinedDate != null ? 'Tham gia từ ${profile.joinedDate}' : 'Thành viên Lãng Thang'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== LỜI NHẮN GỬI KÈM =====
                    const Text(
                      'Lời nhắn gửi kèm',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noteController,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Giới thiệu bạn một người bạn du lịch tuyệt vời!...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ===== SECTION 1: GỬI QUA TIN NHẮN LÃNG THANG =====
                    Row(
                      children: const [
                        Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 6),
                        Text(
                          'GỬI QUA TIN NHẮN LÃNG THANG',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (!_isAuthenticated)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFEF3C7)),
                        ),
                        child: const Text(
                          'Bạn chưa đăng nhập. Vui lòng đăng nhập để gửi trực tiếp trang cá nhân này qua tin nhắn.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (_isLoadingContacts)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                          ),
                        ),
                      )
                    else if (_contacts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: const Center(
                          child: Text(
                            'Chưa có cuộc trò chuyện hoặc bạn bè nào để gửi.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          if (_contacts.length > 5) ...[
                            TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              style: const TextStyle(fontSize: 11.5),
                              decoration: InputDecoration(
                                hintText: 'Tìm bạn bè hoặc nhóm trò chuyện...',
                                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search, size: 14, color: Color(0xFF94A3B8)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          SizedBox(
                            height: 90,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _filteredContacts.take(8).length,
                              separatorBuilder: (context, index) => const SizedBox(width: 12),
                              itemBuilder: (ctx, idx) {
                                final contact = _filteredContacts[idx];
                                final isSent = _sentContactIds.contains(contact.id);
                                final isSending = _sendingContactId == contact.id;

                                return SizedBox(
                                  width: 60,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _handleOpenChatWithProfile(contact),
                                        child: Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: const Color(0xFFE2E8F0),
                                              backgroundImage: contact.avatarUrl != null
                                                  ? NetworkImage(contact.avatarUrl!)
                                                  : null,
                                              child: contact.avatarUrl == null
                                                  ? Text(
                                                      contact.name.isNotEmpty
                                                          ? contact.name.characters.first.toUpperCase()
                                                          : 'U',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            if (contact.isGroup)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF059669),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.group, size: 8, color: Colors.white),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        contact.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        height: 20,
                                        child: ElevatedButton(
                                          onPressed: isSent ? null : () => _handleSendToChat(contact),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isSent ? const Color(0xFFE2E8F0) : const Color(0xFF059669),
                                            foregroundColor: isSent ? const Color(0xFF64748B) : Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: isSending
                                              ? const SizedBox(
                                                  width: 10,
                                                  height: 10,
                                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                                )
                                              : Text(
                                                  isSent ? 'Đã gửi' : 'Gửi',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSent ? const Color(0xFF64748B) : Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 18),

                    // ===== SECTION 2: CHIA SẺ RA MẠNG XÃ HỘI =====
                    Row(
                      children: const [
                        Icon(Icons.public_rounded, size: 14, color: Color(0xFF0284C7)),
                        SizedBox(width: 6),
                        Text(
                          'CHIA SẺ RA MẠNG XÃ HỘI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSocialButton(
                          icon: Icons.facebook,
                          color: const Color(0xFF1877F2),
                          label: 'Facebook',
                          onTap: _handleShareFacebook,
                        ),
                        _buildSocialButton(
                          icon: Icons.chat_bubble_rounded,
                          color: const Color(0xFF0084FF),
                          label: 'Messenger',
                          onTap: _handleShareMessenger,
                        ),
                        _buildSocialButton(
                          icon: Icons.send_rounded,
                          color: const Color(0xFF229ED9),
                          label: 'Telegram',
                          onTap: _handleShareTelegram,
                        ),
                        _buildSocialButton(
                          icon: Icons.phone_android_rounded,
                          color: const Color(0xFF25D366),
                          label: 'WhatsApp',
                          onTap: _handleShareWhatsApp,
                        ),
                        _buildSocialButton(
                          icon: Icons.share_rounded,
                          color: const Color(0xFF475569),
                          label: 'Khác',
                          onTap: _handleSystemShare,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ===== COPY LINK BAR =====
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _profileUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: _handleCopyLink,
                              icon: Icon(
                                _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              label: Text(
                                _isCopied ? 'Đã chép' : 'Sao chép',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isCopied ? const Color(0xFF059669) : const Color(0xFF0F172A),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
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
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }
}

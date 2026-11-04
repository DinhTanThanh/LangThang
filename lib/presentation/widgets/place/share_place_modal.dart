import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_api_service.dart';
import '../../../data/services/friend_api_service.dart';
import '../../screens/chat/chat_room_screen.dart';

class ShareContactItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final int? roomId;
  final int? userId;
  final bool isGroup;

  const ShareContactItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.roomId,
    this.userId,
    this.isGroup = false,
  });
}

class SharePlaceModal extends StatefulWidget {
  final PlaceModel place;

  const SharePlaceModal({
    super.key,
    required this.place,
  });

  static Future<void> show(BuildContext context, {required PlaceModel place}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SharePlaceModal(place: place),
      ),
    );
  }

  @override
  State<SharePlaceModal> createState() => _SharePlaceModalState();
}

class _SharePlaceModalState extends State<SharePlaceModal> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isAuthenticated = false;
  bool _isLoadingContacts = false;
  List<ShareContactItem> _contacts = [];
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

      final List<ShareContactItem> combined = [];
      final Set<String> seenKeys = {};

      // 1. Add active rooms
      for (final room in inboxList) {
        final key = 'room-${room.roomId}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          combined.add(
            ShareContactItem(
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
              ShareContactItem(
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

  List<ShareContactItem> get _filteredContacts {
    if (_searchQuery.trim().isEmpty) return _contacts;
    final q = _searchQuery.toLowerCase().trim();
    return _contacts.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  String get _placeUrl => 'https://langthang.vn/places/${widget.place.id}';

  String get _coverImage {
    if (widget.place.mediaUrls.isNotEmpty) return widget.place.mediaUrls.first;
    if (widget.place.img.isNotEmpty) return widget.place.img;
    return '';
  }

  Future<void> _handleSendToChat(ShareContactItem contact) async {
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

      final note = _noteController.text.trim();
      final contentText = note.isNotEmpty ? note : null;

      final res = await ChatApiService().sendMessage(
        roomId: targetRoomId,
        content: contentText,
        placeId: widget.place.id,
        placeName: widget.place.name,
        placeCoverUrl: _coverImage,
        placeProvince: widget.place.province.isNotEmpty
            ? widget.place.province
            : (widget.place.location.isNotEmpty ? widget.place.location : widget.place.region),
        placeRating: widget.place.rating > 0 ? widget.place.rating : 5.0,
        placePrice: widget.place.priceRange.isNotEmpty
            ? widget.place.priceRange
            : (widget.place.price.isNotEmpty ? widget.place.price : 'Miễn phí'),
      );

      if (res.success && mounted) {
        setState(() {
          _sentContactIds.add(contact.id);
          _sendingContactId = null;
        });
        _showToast('Đã gửi địa điểm tới ${contact.name}!');
      } else if (!res.success && mounted) {
        setState(() => _sendingContactId = null);
        _showToast('Không thể gửi địa điểm: ${res.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingContactId = null);
        _showToast('Không thể gửi địa điểm lúc này: $e');
      }
    }
  }

  Future<void> _handleOpenChatWithPlace(ShareContactItem contact) async {
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
            initialAttachedPlace: widget.place,
            initialText: _noteController.text.trim(),
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
      await Clipboard.setData(ClipboardData(text: _placeUrl));
      setState(() => _isCopied = true);
      _showToast('Đã sao chép liên kết địa điểm!');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isCopied = false);
      });
    } catch (_) {
      _showToast('Không thể sao chép liên kết.');
    }
  }

  Future<void> _handleShareFacebook() async {
    final encodedUrl = Uri.encodeComponent(_placeUrl);
    final encodedQuote = Uri.encodeComponent('Khám phá địa điểm "${widget.place.name}" trên Lãng Thang');
    final fbWebSharerUri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$encodedUrl&quote=$encodedQuote');

    try {
      final launched = await launchUrl(fbWebSharerUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Khám phá địa điểm "${widget.place.name}" trên Lãng Thang: $_placeUrl',
            subject: widget.place.name,
          ),
        );
      }
    } catch (_) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Khám phá địa điểm "${widget.place.name}" trên Lãng Thang: $_placeUrl',
            subject: widget.place.name,
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
          text: 'Khám phá địa điểm "${widget.place.name}" trên Lãng Thang: $_placeUrl',
          subject: widget.place.name,
        ),
      );
    } catch (_) {
      _handleCopyLink();
    }
  }

  Future<void> _handleShareMessenger() async {
    final encodedUrl = Uri.encodeComponent(_placeUrl);
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
    final text = 'Khám phá địa điểm "${widget.place.name}" trên Lãng Thang: $_placeUrl';
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

  Future<void> _handleShareX() async {
    final text = 'Khám phá địa điểm "${widget.place.name}" trên Lãng Thang';
    final xUri = Uri.parse('https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(_placeUrl)}');
    try {
      final launched = await launchUrl(xUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await _handleSystemShare();
      }
    } catch (_) {
      await _handleSystemShare();
    }
  }

  Future<void> _handleShareEmail() async {
    final subject = 'Địa điểm du lịch thú vị: ${widget.place.name}';
    final body = 'Chào bạn,\n\nMình muốn chia sẻ với bạn địa điểm "${widget.place.name}" rất thú vị này trên Lãng Thang:\n$_placeUrl\n\nChúc bạn có chuyến đi vui vẻ!';
    final mailUri = Uri.parse('mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    try {
      final launched = await launchUrl(mailUri, mode: LaunchMode.externalApplication);
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
    final place = widget.place;
    final categoryText = place.category.isNotEmpty
        ? place.category
        : (place.type.isNotEmpty ? place.type : 'Nhà hàng & Quán ăn');
    final locationText = place.location.isNotEmpty
        ? place.location
        : (place.province.isNotEmpty ? place.province : 'Việt Nam');

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
                      'Chia sẻ địa điểm',
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
                    // ===== PLACE PREVIEW CARD =====
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
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 62,
                              height: 62,
                              child: _coverImage.isNotEmpty
                                  ? Image.network(
                                      _coverImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xFFE2E8F0),
                                        child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    categoryText,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  place.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        locationText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 3),
                                    Text(
                                      place.rating > 0 ? place.rating.toStringAsFixed(1) : '5.0',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
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
                        hintText: 'Ví dụ: Điểm này đẹp quá, hôm nào cùng đi nhé!...',
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
                          'Bạn chưa đăng nhập. Vui lòng đăng nhập để gửi trực tiếp địa điểm này qua tin nhắn.',
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
                                        onTap: () => _handleOpenChatWithPlace(contact),
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
                                            if (isSent)
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF059669),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.check, size: 8, color: Colors.white),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      GestureDetector(
                                        onTap: () => _handleOpenChatWithPlace(contact),
                                        child: Text(
                                          contact.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      GestureDetector(
                                        onTap: isSent || isSending ? null : () => _handleSendToChat(contact),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSent ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isSent ? 'Đã gửi' : isSending ? '...' : 'Gửi',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isSent ? const Color(0xFF065F46) : const Color(0xFF475569),
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
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 14),

                    // ===== SECTION 2: CHIA SẺ LÊN =====
                    const Text(
                      'CHIA SẺ LÊN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildSocialButton(
                            icon: _isCopied ? Icons.check_rounded : Icons.link_rounded,
                            label: _isCopied ? 'Đã chép' : 'Sao chép\nlink',
                            bgColor: _isCopied ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            iconColor: _isCopied ? const Color(0xFF059669) : const Color(0xFF334155),
                            onTap: _handleCopyLink,
                          ),
                          const SizedBox(width: 12),
                          _buildSocialButton(
                            customIcon: _buildSvgFacebook(),
                            label: 'Facebook\n',
                            bgColor: const Color(0xFFEBF5FF),
                            onTap: _handleShareFacebook,
                          ),
                          const SizedBox(width: 12),
                          _buildSocialButton(
                            customIcon: _buildSvgMessenger(),
                            label: 'Messenger\n',
                            bgColor: const Color(0xFFE0F2FE),
                            onTap: _handleShareMessenger,
                          ),
                          const SizedBox(width: 12),
                          _buildSocialButton(
                            customIcon: _buildSvgWhatsApp(),
                            label: 'WhatsApp\n',
                            bgColor: const Color(0xFFECFDF5),
                            onTap: _handleShareWhatsApp,
                          ),
                          const SizedBox(width: 12),
                          _buildSocialButton(
                            customIcon: _buildSvgX(),
                            label: 'X\n',
                            bgColor: const Color(0xFFF1F5F9),
                            onTap: _handleShareX,
                          ),
                          const SizedBox(width: 12),
                          _buildSocialButton(
                            icon: Icons.mail_outline_rounded,
                            label: 'Email\n',
                            bgColor: const Color(0xFFFEF2F2),
                            iconColor: const Color(0xFFDC2626),
                            onTap: _handleShareEmail,
                          ),
                          const SizedBox(width: 12),
                          _buildSocialButton(
                            icon: Icons.ios_share_rounded,
                            label: 'Khác\n',
                            bgColor: const Color(0xFFF8FAFC),
                            iconColor: const Color(0xFF475569),
                            onTap: _handleSystemShare,
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
    IconData? icon,
    Widget? customIcon,
    required String label,
    required Color bgColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: customIcon ?? Icon(icon, size: 20, color: iconColor ?? const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSvgFacebook() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  Widget _buildSvgMessenger() {
    return const Icon(
      Icons.chat_bubble_rounded,
      color: Color(0xFF0084FF),
      size: 20,
    );
  }

  Widget _buildSvgWhatsApp() {
    return const Icon(
      Icons.call_rounded,
      color: Color(0xFF25D366),
      size: 20,
    );
  }

  Widget _buildSvgX() {
    return const Text(
      '𝕏',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Color(0xFF0F172A),
      ),
    );
  }
}

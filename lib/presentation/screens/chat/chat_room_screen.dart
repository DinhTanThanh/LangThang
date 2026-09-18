import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/chat_api_service.dart';
import '../../widgets/chat/chat_place_picker_sheet.dart';
import '../../widgets/chat/chat_food_picker_sheet.dart';
import '../../widgets/chat/chat_itinerary_picker_sheet.dart';
import '../../widgets/chat/chat_image_lightbox.dart';
import '../../widgets/chat/chat_call_dialog.dart';
import '../destinations/place_detail_screen.dart';
import '../itineraries/itinerary_detail_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final int roomId;
  final String roomName;
  final String? roomAvatar;
  final bool isGroup;
  final int? otherUserId;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.roomAvatar,
    this.isGroup = false,
    this.otherUserId,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatApiService _chatService = ChatApiService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  ChatMessage? _replyingToMessage;
  bool _isAudioPlaying = false;
  int? _playingAudioId;

  StreamSubscription<ChatMessage>? _messageSub;

  final List<String> _quickEmojis = ['❤️', '👍', '😂', '😮', '😢', '🔥', '🎉', '✈️'];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markRead();

    // Listen to real-time incoming messages
    _messageSub = _chatService.onMessageReceived.listen((newMsg) {
      if (newMsg.roomId == widget.roomId && mounted) {
        setState(() {
          final exists = _messages.any((m) => m.id == newMsg.id);
          if (!exists) {
            _messages.add(newMsg);
          }
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final res = await _chatService.getRoomMessages(widget.roomId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _messages = res.data!;
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _markRead() async {
    await _chatService.markRoomAsRead(widget.roomId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage({
    PlaceModel? attachedPlace,
    FoodModel? attachedFood,
    ItineraryModel? attachedItinerary,
    String? imageUrl,
    String? fileName,
    int? fileSizeBytes,
    int? durationSeconds,
  }) async {
    final text = _textController.text.trim();
    if (text.isEmpty &&
        attachedPlace == null &&
        attachedFood == null &&
        attachedItinerary == null &&
        imageUrl == null &&
        fileName == null &&
        durationSeconds == null) {
      return;
    }

    final replyMsg = _replyingToMessage;
    _textController.clear();
    setState(() {
      _replyingToMessage = null;
      _isSending = true;
    });

    final res = await _chatService.sendMessage(
      roomId: widget.roomId,
      content: text.isNotEmpty ? text : null,
      replyToMessageId: replyMsg?.id,
      replySnippet: replyMsg?.content ?? (replyMsg?.attachments.isNotEmpty == true ? '[Đính kèm]' : null),
      replySenderName: replyMsg?.senderName,
      placeId: attachedPlace?.id,
      placeName: attachedPlace?.name,
      placeCoverUrl: attachedPlace?.img,
      placeProvince: attachedPlace?.province,
      placeRating: attachedPlace?.rating,
      placePrice: attachedPlace?.price,
      foodId: attachedFood?.id,
      foodName: attachedFood?.name,
      foodCoverUrl: attachedFood?.imageUrl,
      foodProvince: attachedFood?.province,
      foodPrice: attachedFood?.priceRange,
      foodRating: attachedFood?.rating,
      tripId: attachedItinerary?.id,
      tripTitle: attachedItinerary?.title,
      tripCoverUrl: attachedItinerary?.imageUrl,
      tripDuration: attachedItinerary?.duration,
      tripDestination: attachedItinerary?.destination,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      durationSeconds: durationSeconds,
      imageUrls: imageUrl != null ? [imageUrl] : null,
    );

    if (mounted) {
      setState(() {
        _isSending = false;
        if (res.success && res.data != null) {
          final exists = _messages.any((m) => m.id == res.data!.id);
          if (!exists) {
            _messages.add(res.data!);
          }
        }
      });
      _scrollToBottom();
    }
  }

  void _openAttachmentActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Nội dung đính kèm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 14),

            // Grid of 6 options
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: [
                _buildAttachmentOption(
                  icon: Icons.location_on_rounded,
                  label: 'Địa điểm',
                  bgColor: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF059669),
                  onTap: () {
                    Navigator.pop(context);
                    _openPlacePicker();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Đặc sản',
                  bgColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                  onTap: () {
                    Navigator.pop(context);
                    _openFoodPicker();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.alt_route_rounded,
                  label: 'Lịch trình',
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.pop(context);
                    _openItineraryPicker();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.image_rounded,
                  label: 'Hình ảnh',
                  bgColor: const Color(0xFFFDF4FF),
                  iconColor: const Color(0xFFC026D3),
                  onTap: () {
                    Navigator.pop(context);
                    _openImageDialog();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Tài liệu',
                  bgColor: const Color(0xFFF1F5F9),
                  iconColor: const Color(0xFF475569),
                  onTap: () {
                    Navigator.pop(context);
                    _sendFileAttachment();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.mic_rounded,
                  label: 'Ghi âm',
                  bgColor: const Color(0xFFFEF2F2),
                  iconColor: const Color(0xFFEF4444),
                  onTap: () {
                    Navigator.pop(context);
                    _sendVoiceNote();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlacePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatPlacePickerSheet(
        onPlaceSelected: (place) {
          _handleSendMessage(attachedPlace: place);
        },
      ),
    );
  }

  void _openFoodPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatFoodPickerSheet(
        onFoodSelected: (food) {
          _handleSendMessage(attachedFood: food);
        },
      ),
    );
  }

  void _openItineraryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatItineraryPickerSheet(
        onItinerarySelected: (itinerary) {
          _handleSendMessage(attachedItinerary: itinerary);
        },
      ),
    );
  }

  void _openImageDialog() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gửi hình ảnh', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập đường dẫn (URL) ảnh để gửi nhanh vào phòng chat:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'https://images.unsplash.com/...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Ảnh Hà Giang', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlController.text = 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800&fit=crop',
                ),
                ActionChip(
                  label: const Text('Ảnh Hội An', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlController.text = 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800&fit=crop',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final url = urlController.text.trim();
              Navigator.pop(dialogContext);
              if (url.isNotEmpty) {
                _handleSendMessage(imageUrl: url);
              }
            },
            child: const Text('Gửi ảnh'),
          ),
        ],
      ),
    );
  }

  void _sendFileAttachment() {
    _handleSendMessage(
      fileName: 'Ke_hoach_chuyen_di_Tay_Bac.pdf',
      fileSizeBytes: 3450000,
    );
  }

  void _sendVoiceNote() {
    _handleSendMessage(
      durationSeconds: 24,
    );
  }

  void _startCall({required bool isVideo}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChatCallDialog(
        partnerName: widget.roomName,
        partnerAvatar: widget.roomAvatar,
        isVideoCall: isVideo,
      ),
    );
  }

  void _showRoomInfo() async {
    final res = await _chatService.getRoomMembers(widget.roomId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: widget.roomAvatar != null ? NetworkImage(widget.roomAvatar!) : null,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: widget.roomAvatar == null
                      ? Icon(widget.isGroup ? Icons.groups_rounded : Icons.person, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.roomName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        widget.isGroup ? 'Phòng chat cộng đồng' : 'Cuộc trò chuyện cá nhân',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),
            const Text(
              'Thành viên',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            if (res.data != null)
              ...res.data!.map(
                (m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: m.avatarUrl != null ? NetworkImage(m.avatarUrl!) : null,
                        child: m.avatarUrl == null ? Text(m.name[0]) : null,
                      ),
                      const SizedBox(width: 10),
                      Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showReactionMenu(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thả cảm xúc', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _quickEmojis.map((emoji) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _chatService.addMessageReaction(widget.roomId, msg.id, emoji);
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPlaceDetail(int placeId, String name, String cover, String province, double rating, String price) {
    final place = PlaceModel(
      id: placeId,
      name: name,
      category: 'Điểm tham quan',
      location: province,
      region: 'Việt Nam',
      province: province,
      type: 'Điểm tham quan',
      rating: rating,
      reviews: 0,
      price: price,
      priceMax: 0,
      priceRange: price,
      hours: '07:30 – 17:30',
      status: 'Đang mở cửa',
      desc: '',
      detailedDescription: '',
      phoneNumber: '',
      website: '',
      img: cover,
      mediaUrls: cover.isNotEmpty ? [cover] : [],
      latitude: 21.0285,
      longitude: 105.8542,
      tags: const ['Điểm tham quan'],
      amenities: const [],
      isSaved: false,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlaceDetailScreen(place: place)),
    );
  }

  void _navigateToItineraryDetail(int tripId, String title, String cover) {
    final itinerary = ItineraryModel(
      id: tripId,
      title: title,
      duration: '3 ngày 2 đêm',
      daysCount: 3,
      nightsCount: 2,
      destination: 'Việt Nam',
      estimatedCost: '3.500.000đ',
      rating: 4.9,
      coverUrl: cover,
      author: const ItineraryAuthorModel(name: 'Lang Thang'),
      overview: 'Lịch trình khám phá được chia sẻ qua khung chat.',
      tags: const ['Phượt', 'Khám phá'],
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItineraryDetailScreen(itinerary: itinerary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages Feed
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.isSentByMe;
                          final showAvatar = !isMe && (index == 0 || _messages[index - 1].senderId != msg.senderId);

                          return _buildMessageRow(msg, isMe, showAvatar);
                        },
                      ),
          ),

          // Bottom Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 19),
        onPressed: () => Navigator.pop(context),
      ),
      title: InkWell(
        onTap: _showRoomInfo,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundImage: widget.roomAvatar != null ? NetworkImage(widget.roomAvatar!) : null,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: widget.roomAvatar == null
                      ? Icon(widget.isGroup ? Icons.groups_rounded : Icons.person, color: AppColors.primary, size: 20)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.roomName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    'Đang hoạt động',
                    style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 22),
          onPressed: () => _startCall(isVideo: false),
        ),
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: AppColors.primary, size: 24),
          onPressed: () => _startCall(isVideo: true),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 22),
          onPressed: _showRoomInfo,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            'Hãy gửi lời chào đến ${widget.roomName}!',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bắt đầu chia sẻ những chuyến đi, địa điểm và món ngon.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(ChatMessage msg, bool isMe, bool showAvatar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left Avatar if partner
          if (!isMe)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              child: showAvatar
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: msg.senderAvatarUrl != null ? NetworkImage(msg.senderAvatarUrl!) : null,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: msg.senderAvatarUrl == null
                          ? Text(msg.senderName.isNotEmpty ? msg.senderName[0] : 'U', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
                          : null,
                    )
                  : const SizedBox(),
            ),

          // Message Bubble & Content
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showReactionMenu(msg),
              onDoubleTap: () {
                _chatService.addMessageReaction(widget.roomId, msg.id, '❤️');
                setState(() {});
              },
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender name if in group
                  if (!isMe && widget.isGroup && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        msg.senderName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    ),

                  // Quoted Reply Banner
                  if (msg.replyToMessageSnippet != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF047857).withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(left: BorderSide(color: isMe ? Colors.white70 : AppColors.primary, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.replyToSenderName ?? 'Tin nhắn',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isMe ? Colors.white70 : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            msg.replyToMessageSnippet!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: isMe ? Colors.white60 : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                  // Main Speech Bubble
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF047857)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text message
                        if (msg.content != null && msg.content!.isNotEmpty)
                          Text(
                            msg.content!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: isMe ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),

                        // Attachments (Place / Food / Trip / Image / File / Audio)
                        if (msg.attachments.isNotEmpty) ...[
                          if (msg.content != null && msg.content!.isNotEmpty) const SizedBox(height: 8),
                          ...msg.attachments.map((attach) => _buildAttachmentWidget(attach, isMe)),
                        ],
                      ],
                    ),
                  ),

                  // Reactions & Time
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reactions Chips
                      if (msg.reactions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4, right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(msg.reactions.map((r) => r.emoji).toSet().join(' '), style: const TextStyle(fontSize: 11)),
                              if (msg.reactions.length > 1) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '${msg.reactions.length}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                        ),

                      // Time
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentWidget(MessageAttachment attach, bool isMe) {
    // 1. PLACE ATTACHMENT
    if (attach.attachmentType == MessageAttachmentType.place) {
      return Container(
        width: 250,
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? Colors.white24 : const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attach.placeCoverUrl != null && attach.placeCoverUrl!.isNotEmpty)
              Image.network(
                attach.placeCoverUrl!,
                height: 115,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 90,
                  color: const Color(0xFFCBD5E1),
                  child: const Center(child: Icon(Icons.landscape, color: Colors.white)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white24 : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ĐIỂM ĐẾN',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isMe ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attach.placeName ?? 'Địa điểm du lịch',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isMe ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: isMe ? Colors.white70 : const Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(
                        attach.placeProvince ?? 'Việt Nam',
                        style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      if (attach.placeRating != null) ...[
                        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          '${attach.placeRating}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? Colors.white : const Color(0xFFD97706)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMe ? Colors.white : AppColors.primary,
                      foregroundColor: isMe ? AppColors.primary : Colors.white,
                      minimumSize: const Size(double.infinity, 32),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (attach.placeId != null) {
                        _navigateToPlaceDetail(
                          attach.placeId!,
                          attach.placeName ?? '',
                          attach.placeCoverUrl ?? '',
                          attach.placeProvince ?? '',
                          attach.placeRating ?? 5.0,
                          attach.placePrice ?? 'Miễn phí',
                        );
                      }
                    },
                    child: const Text('Xem chi tiết địa điểm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. FOOD SPECIALTY ATTACHMENT
    if (attach.attachmentType == MessageAttachmentType.food) {
      return Container(
        width: 250,
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? Colors.white24 : const Color(0xFFFED7AA)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attach.foodCoverUrl != null && attach.foodCoverUrl!.isNotEmpty)
              Image.network(
                attach.foodCoverUrl!,
                height: 115,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 90,
                  color: const Color(0xFFCBD5E1),
                  child: const Center(child: Icon(Icons.restaurant, color: Colors.white)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white24 : const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ĐẶC SẢN ẨM THỰC',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isMe ? Colors.white : const Color(0xFFEA580C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attach.foodName ?? 'Món ăn đặc sản',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isMe ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: isMe ? Colors.white70 : const Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(
                        attach.foodProvince ?? 'Việt Nam',
                        style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      if (attach.foodPrice != null)
                        Text(
                          attach.foodPrice!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white : const Color(0xFFEA580C),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMe ? Colors.white : const Color(0xFFEA580C),
                      foregroundColor: isMe ? const Color(0xFFEA580C) : Colors.white,
                      minimumSize: const Size(double.infinity, 32),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đặc sản: ${attach.foodName} (${attach.foodProvince})'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text('Khám phá món ăn', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 3. TRIP / ITINERARY ATTACHMENT
    if (attach.attachmentType == MessageAttachmentType.trip) {
      return Container(
        width: 250,
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? Colors.white24 : const Color(0xFFBFDBFE)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attach.tripCoverUrl != null && attach.tripCoverUrl!.isNotEmpty)
              Image.network(
                attach.tripCoverUrl!,
                height: 115,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 90,
                  color: const Color(0xFFCBD5E1),
                  child: const Center(child: Icon(Icons.map, color: Colors.white)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white24 : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LỊCH TRÌNH TOUR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isMe ? Colors.white : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attach.tripTitle ?? 'Lịch trình khám phá',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isMe ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 12, color: isMe ? Colors.white70 : const Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(
                        attach.tripDestination ?? 'Việt Nam',
                        style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      if (attach.tripDuration != null)
                        Text(
                          attach.tripDuration!,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? Colors.white : const Color(0xFF2563EB)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMe ? Colors.white : const Color(0xFF2563EB),
                      foregroundColor: isMe ? const Color(0xFF2563EB) : Colors.white,
                      minimumSize: const Size(double.infinity, 32),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _navigateToItineraryDetail(
                        attach.tripId ?? 1,
                        attach.tripTitle ?? 'Lịch trình du lịch',
                        attach.tripCoverUrl ?? '',
                      );
                    },
                    child: const Text('Xem chi tiết lịch trình', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4. IMAGE ATTACHMENT
    if (attach.attachmentType == MessageAttachmentType.image && attach.mediaUrl != null) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatImageLightbox(
                imageUrl: attach.mediaUrl!,
                title: attach.fileName ?? 'Hình ảnh đính kèm',
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            attach.mediaUrl!,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 220,
              height: 120,
              color: const Color(0xFFCBD5E1),
              child: const Icon(Icons.broken_image, color: Colors.white),
            ),
          ),
        ),
      );
    }

    // 5. FILE / DOCUMENT ATTACHMENT
    if (attach.attachmentType == MessageAttachmentType.file) {
      return Container(
        width: 230,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isMe ? Colors.white24 : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe ? Colors.white24 : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.insert_drive_file_rounded, size: 20, color: isMe ? Colors.white : AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attach.fileName ?? 'Tai_lieu_dinh_kem.pdf',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isMe ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${((attach.fileSizeBytes ?? 2048576) / 1048576).toStringAsFixed(1)} MB · PDF',
                    style: TextStyle(fontSize: 10.5, color: isMe ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_rounded, size: 18, color: isMe ? Colors.white70 : const Color(0xFF64748B)),
          ],
        ),
      );
    }

    // 6. AUDIO / VOICE NOTE ATTACHMENT
    if (attach.attachmentType == MessageAttachmentType.audio) {
      final isPlayingThis = _isAudioPlaying && _playingAudioId == attach.id;

      return Container(
        width: 210,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isPlayingThis) {
                    _isAudioPlaying = false;
                    _playingAudioId = null;
                  } else {
                    _isAudioPlaying = true;
                    _playingAudioId = attach.id;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 18,
                  color: isMe ? AppColors.primary : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(12, (index) {
                  final heights = [8, 16, 22, 12, 18, 24, 14, 20, 10, 16, 22, 12];
                  return Container(
                    width: 3,
                    height: heights[index].toDouble() * (isPlayingThis ? 1.0 : 0.7),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white : (index < 5 ? AppColors.primary : const Color(0xFF94A3B8)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '0:${(attach.durationSeconds ?? 24).toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isMe ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Replying Quote Bar
            if (_replyingToMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF1F5F9),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trả lời ${_replyingToMessage!.senderName}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            _replyingToMessage!.content ?? '[Đính kèm]',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                      onPressed: () => setState(() => _replyingToMessage = null),
                    ),
                  ],
                ),
              ),

            // Input Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Attachment Action Sheet Button (+)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                    ),
                    tooltip: 'Đính kèm nội dung',
                    onPressed: _openAttachmentActionSheet,
                  ),

                  // Text Field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _textController,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _handleSendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Send Button
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(10),
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    onPressed: _isSending ? null : () => _handleSendMessage(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

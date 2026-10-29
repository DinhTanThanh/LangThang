import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_api_service.dart';
import '../../../data/services/friend_api_service.dart';
import '../../widgets/chat/chat_place_picker_sheet.dart';
import '../../widgets/chat/chat_food_picker_sheet.dart';
import '../../widgets/chat/chat_itinerary_picker_sheet.dart';
import '../../widgets/chat/chat_image_lightbox.dart';
import '../destinations/place_detail_screen.dart';
import '../itineraries/itinerary_detail_screen.dart';
import '../auth/login_screen.dart';
import '../blog/blog_detail_screen.dart';
import '../../../data/models/blog_model.dart';

class ChatRoomScreen extends StatefulWidget {
  final int roomId;
  final String roomName;
  final String? roomAvatar;
  final bool isGroup;
  final int? otherUserId;
  final PlaceModel? initialAttachedPlace;
  final BlogModel? initialAttachedBlog;
  final String? initialText;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.roomAvatar,
    this.isGroup = false,
    this.otherUserId,
    this.initialAttachedPlace,
    this.initialAttachedBlog,
    this.initialText,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatApiService _chatService = ChatApiService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late int _currentRoomId;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  final bool _partnerTyping = false;
  ChatMessage? _replyingToMessage;
  PlaceModel? _pendingAttachedPlace;
  BlogModel? _pendingAttachedBlog;
  String _currentRoomName = '';

  // Inline editing state
  int? _editingMessageId;
  final TextEditingController _editController = TextEditingController();

  StreamSubscription<ChatMessage>? _messageSub;

  // Share_Locations Messenger Color Palette
  static const Color messengerBlue = Color(0xFF0084FF);
  static const Color messengerBlueLight = Color(0xFFEBF5FF);
  static const Color messengerBgGray = Color(0xFFF0F2F5);
  static const Color messengerDark = Color(0xFF050505);
  static const Color messengerSub = Color(0xFF65676B);
  static const Color messengerBorder = Color(0xFFE4E6EB);

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _currentRoomId = widget.roomId;
    _currentRoomName = widget.roomName;
    if (widget.initialAttachedPlace != null) {
      _pendingAttachedPlace = widget.initialAttachedPlace;
    }
    if (widget.initialAttachedBlog != null) {
      _pendingAttachedBlog = widget.initialAttachedBlog;
    }
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
    }
    _initRoomAndLoadMessages();

    // Listen to real-time incoming messages
    _messageSub = _chatService.onMessageReceived.listen((newMsg) {
      if (newMsg.roomId == _currentRoomId && mounted) {
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
    _inputFocusNode.dispose();
    _textController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initRoomAndLoadMessages() async {
    final isLoggedIn = await AuthService().isLoggedIn();
    final token = await AuthService().getAccessToken();
    if (!isLoggedIn || token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để xem tin nhắn.'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        final didLogin = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        if (didLogin != true) {
          if (mounted) Navigator.pop(context);
          return;
        }
        if (!mounted) return;
      }
    }

    if (_currentRoomId <= 0 && widget.otherUserId != null && widget.otherUserId! > 0) {
      setState(() => _isLoading = true);
      final directRes = await _chatService.getOrCreateDirectRoom(
        widget.otherUserId!,
        targetUserName: widget.roomName,
        targetUserAvatar: widget.roomAvatar,
      );
      if (!directRes.success && (directRes.message.contains('UNAUTHORIZED') || directRes.message.contains('đăng nhập'))) {
        if (mounted) {
          final didLogin = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          if (didLogin == true && mounted) {
            _initRoomAndLoadMessages();
          } else if (mounted) {
            Navigator.pop(context);
          }
        }
        return;
      }
      if (directRes.success && directRes.data != null && directRes.data! > 0) {
        _currentRoomId = directRes.data!;
      }
    }

    if (_currentRoomId > 0) {
      await _loadMessages();
      await _markRead();
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_currentRoomId <= 0) return;
    setState(() => _isLoading = true);
    final res = await _chatService.getRoomMessages(_currentRoomId);
    if (mounted) {
      if (!res.success && (res.message.contains('UNAUTHORIZED') || res.message.contains('đăng nhập'))) {
        setState(() => _isLoading = false);
        final didLogin = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        if (didLogin == true && mounted) {
          _initRoomAndLoadMessages();
        } else if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

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
    if (_currentRoomId > 0) {
      await _chatService.markRoomAsRead(_currentRoomId);
    }
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
    BlogModel? attachedBlog,
    String? imageUrl,
    String? fileName,
    int? fileSizeBytes,
    int? durationSeconds,
  }) async {
    final placeToSend = attachedPlace ?? _pendingAttachedPlace;
    final blogToSend = attachedBlog ?? _pendingAttachedBlog;
    final text = _textController.text.trim();
    if (text.isEmpty &&
        placeToSend == null &&
        blogToSend == null &&
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
      _pendingAttachedPlace = null;
      _pendingAttachedBlog = null;
      _isSending = true;
    });

    // Ensure we have a valid room before sending
    if (_currentRoomId <= 0) {
      if (widget.otherUserId != null && widget.otherUserId! > 0) {
        final directRes = await _chatService.getOrCreateDirectRoom(
          widget.otherUserId!,
          targetUserName: widget.roomName,
          targetUserAvatar: widget.roomAvatar,
        );
        if (directRes.success && directRes.data != null && directRes.data! > 0) {
          _currentRoomId = directRes.data!;
        } else {
          if (mounted) {
            setState(() => _isSending = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(directRes.message.isNotEmpty ? directRes.message : 'Không thể khởi tạo phòng chat.'),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          return;
        }
      } else {
        if (mounted) {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Phòng trò chuyện không hợp lệ.'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }
    }

    final res = await _chatService.sendMessage(
      roomId: _currentRoomId,
      content: text.isNotEmpty ? text : null,
      replyToMessageId: replyMsg?.id,
      replySnippet: replyMsg?.content ?? (replyMsg?.attachments.isNotEmpty == true ? '[Đính kèm]' : null),
      replySenderName: replyMsg?.senderName,
      placeId: placeToSend?.id,
      placeName: placeToSend?.name,
      placeCoverUrl: placeToSend != null
          ? (placeToSend.mediaUrls.isNotEmpty ? placeToSend.mediaUrls.first : placeToSend.img)
          : null,
      placeProvince: placeToSend?.province.isNotEmpty == true
          ? placeToSend?.province
          : (placeToSend?.location.isNotEmpty == true ? placeToSend?.location : placeToSend?.region),
      placeRating: (placeToSend?.rating != null && placeToSend!.rating > 0) ? placeToSend.rating : 5.0,
      placePrice: placeToSend?.priceRange.isNotEmpty == true
          ? placeToSend?.priceRange
          : (placeToSend?.price.isNotEmpty == true ? placeToSend?.price : 'Miễn phí'),
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
      blogId: blogToSend?.id,
      blogTitle: blogToSend?.title,
      blogCoverUrl: blogToSend?.imageUrl,
      blogCategory: blogToSend?.category,
      blogAuthorName: blogToSend?.authorName,
      blogAuthorAvatar: blogToSend?.authorAvatar,
      blogReadTimeMinutes: blogToSend?.readTimeMinutes,
      blogSummary: blogToSend?.summary,
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
        } else if (!res.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message.isNotEmpty ? res.message : 'Gửi tin nhắn thất bại.'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleSaveEdit(int messageId) async {
    final newText = _editController.text.trim();
    if (newText.isEmpty) return;

    final res = await _chatService.editMessage(_currentRoomId, messageId, newText);
    if (mounted) {
      setState(() {
        _editingMessageId = null;
        if (res.success) {
          final idx = _messages.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(content: newText);
          }
        }
      });
    }
  }

  Future<void> _handleDeleteMessage(int messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xóa tin nhắn?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text('Bạn có chắc chắn muốn xóa tin nhắn này không? Tin nhắn sẽ bị gỡ bỏ khỏi cuộc trò chuyện.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: messengerSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xóa tin nhắn'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _chatService.deleteMessage(_currentRoomId, messageId);
      if (mounted && res.success) {
        setState(() {
          _messages.removeWhere((m) => m.id == messageId);
        });
      }
    }
  }

  void _handleCopyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Đã sao chép tin nhắn vào bộ nhớ tạm'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: messengerDark,
        duration: const Duration(seconds: 2),
      ),
    );
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
                'Nội dung chia sẻ trong đoạn chat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: messengerDark),
              ),
            ),
            const SizedBox(height: 14),

            // Grid of 4 options
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
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
                  iconColor: messengerBlue,
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
              ],
            ),
            const SizedBox(height: 8),
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
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: messengerDark,
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
              'Nhập đường dẫn (URL) ảnh để chia sẻ vào đoạn chat:',
              style: TextStyle(fontSize: 13, color: messengerSub),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'https://images.unsplash.com/...',
                filled: true,
                fillColor: messengerBgGray,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy', style: TextStyle(color: messengerSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: messengerBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(dialogContext);
                _handleSendMessage(imageUrl: url);
              }
            },
            child: const Text('Gửi ảnh'),
          ),
        ],
      ),
    );
  }

  void _openChatDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _ChatDrawerModal(
          roomId: _currentRoomId,
          roomName: _currentRoomName,
          roomAvatar: widget.roomAvatar,
          isGroup: widget.isGroup,
          messages: _messages,
          onRoomNameChanged: (newName) {
            setState(() => _currentRoomName = newName);
          },
          onPreviewImage: (url) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatImageLightbox(imageUrl: url),
              ),
            );
          },
        );
      },
    );
  }

  void _showMessageOptionsSheet(ChatMessage msg) {
    final isMe = msg.isSentByMe;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),

            // 1. Phản hồi
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: messengerBlue),
              title: const Text('Phản hồi tin nhắn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(sheetCtx);
                setState(() => _replyingToMessage = msg);
              },
            ),

            // 2. Sao chép
            if (msg.content != null && msg.content!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: messengerSub),
                title: const Text('Sao chép văn bản', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _handleCopyText(msg.content!);
                },
              ),

            // 3. Chỉnh sửa (Nếu là tin nhắn của mình)
            if (isMe && msg.content != null && msg.content!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706)),
                title: const Text('Sửa tin nhắn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() {
                    _editingMessageId = msg.id;
                    _editController.text = msg.content ?? '';
                  });
                },
              ),

            // 4. Xóa tin nhắn (Nếu là của mình)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                title: const Text('Xóa tin nhắn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _handleDeleteMessage(msg.id);
                },
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

  void _navigateToBlogDetail(
    String blogId,
    String title,
    String cover,
    String category,
    String authorName,
    String authorAvatar,
    int readTimeMinutes,
  ) {
    final blog = BlogModel(
      id: blogId,
      title: title,
      summary: '',
      category: category,
      imageUrl: cover,
      author: BlogAuthorModel(name: authorName, avatar: authorAvatar),
      publishedDate: 'Hôm nay',
      readTimeMinutes: readTimeMinutes,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BlogDetailScreen(blog: blog)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages Feed
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: messengerBlue, strokeWidth: 2.5),
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
                          final isEditingThis = _editingMessageId == msg.id;

                          return _buildMessageRow(msg, isMe, showAvatar, isEditingThis);
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
      scrolledUnderElevation: 1,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: messengerDark, size: 19),
        onPressed: () => Navigator.pop(context),
      ),
      title: InkWell(
        onTap: _openChatDrawer,
        child: Row(
          children: [
            Stack(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: widget.isGroup && (widget.roomAvatar == null || widget.roomAvatar!.isEmpty || !widget.roomAvatar!.startsWith('http'))
                        ? Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF0084FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.groups_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          )
                        : (widget.roomAvatar != null && widget.roomAvatar!.isNotEmpty
                            ? buildAppImage(widget.roomAvatar, width: 40, height: 40, fit: BoxFit.cover)
                            : Container(
                                color: widget.isGroup ? const Color(0xFF0084FF) : messengerBlueLight,
                                child: Icon(
                                  widget.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                                  color: widget.isGroup ? Colors.white : messengerBlue,
                                  size: 22,
                                ),
                              )),
                  ),
                ),
                if (!widget.isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
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
                    _currentRoomName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: messengerDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    _partnerTyping
                        ? 'Đang nhập...'
                        : (widget.isGroup ? 'Nhóm trò chuyện' : 'Đang hoạt động'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _partnerTyping ? messengerBlue : messengerSub,
                      fontWeight: _partnerTyping ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: messengerBlue, size: 22),
          tooltip: 'Thông tin đoạn chat',
          onPressed: _openChatDrawer,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: messengerBorder, height: 1),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: messengerBlueLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: messengerBlue, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            'Hãy gửi lời chào đến $_currentRoomName!',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: messengerDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bắt đầu chia sẻ những chuyến đi, địa điểm và món ngon.',
            style: TextStyle(fontSize: 12.5, color: messengerSub),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(ChatMessage msg, bool isMe, bool showAvatar, bool isEditingThis) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left Avatar if partner
          if (!isMe)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              child: showAvatar
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: msg.senderAvatarUrl != null && msg.senderAvatarUrl!.isNotEmpty
                          ? buildAppImage(msg.senderAvatarUrl, width: 28, height: 28, fit: BoxFit.cover)
                          : Container(
                              color: messengerBlueLight,
                              child: Center(
                                child: Text(
                                  msg.senderName.isNotEmpty ? msg.senderName[0] : 'U',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: messengerBlue),
                                ),
                              ),
                            ),
                    )
                  : const SizedBox(),
            ),

          // Message Bubble & Actions
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name if in group
                if (!isMe && widget.isGroup && showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      msg.senderName,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: messengerSub),
                    ),
                  ),

                // Quoted Reply Banner
                if (msg.replyToMessageSnippet != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: messengerBgGray,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isMe ? Colors.white.withValues(alpha: 0.4) : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          size: 12,
                          color: isMe ? Colors.white : messengerBlue,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${msg.replyToSenderName ?? 'Tin nhắn'}: "${msg.replyToMessageSnippet!}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isMe ? Colors.white.withValues(alpha: 0.9) : messengerSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Inline Edit Box OR Normal Bubble
                if (isEditingThis)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: messengerBlue, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sửa tin nhắn:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: messengerSub)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _editController,
                          maxLines: 3,
                          minLines: 1,
                          style: const TextStyle(fontSize: 14, color: messengerDark),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: messengerBgGray,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _editingMessageId = null),
                              child: const Text('Hủy', style: TextStyle(color: messengerSub, fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed: () => _handleSaveEdit(msg.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: messengerBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Lưu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onLongPress: () => _showMessageOptionsSheet(msg),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left 3-dots if message is mine
                        if (isMe)
                          IconButton(
                            icon: const Icon(Icons.more_horiz_rounded, size: 16, color: messengerSub),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            onPressed: () => _showMessageOptionsSheet(msg),
                          ),

                        // Main Speech Bubble (Full viền & Bo tròn góc)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? messengerBlue : messengerBgGray,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isMe ? const Color(0xFF0070DF) : const Color(0xFFCBD5E1),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (msg.content != null && msg.content!.isNotEmpty)
                                  Text(
                                    msg.content!,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      height: 1.35,
                                      color: isMe ? Colors.white : messengerDark,
                                    ),
                                  ),

                                // Attachments
                                if (msg.attachments.isNotEmpty) ...[
                                  if (msg.content != null && msg.content!.isNotEmpty) const SizedBox(height: 8),
                                  ...msg.attachments.map((attach) => _buildAttachmentWidget(attach, isMe)),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Right 3-dots if message is partner's
                        if (!isMe)
                          IconButton(
                            icon: const Icon(Icons.more_horiz_rounded, size: 16, color: messengerSub),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            onPressed: () => _showMessageOptionsSheet(msg),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentWidget(MessageAttachment attach, bool isMe) {
    if (attach.attachmentType == MessageAttachmentType.image && attach.mediaUrl != null) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatImageLightbox(imageUrl: attach.mediaUrl!),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe ? Colors.white.withValues(alpha: 0.4) : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: buildAppImage(
              attach.mediaUrl,
              width: 220,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    if (attach.attachmentType == MessageAttachmentType.place && attach.placeId != null) {
      return GestureDetector(
        onTap: () {
          _navigateToPlaceDetail(
            attach.placeId!,
            attach.placeName ?? 'Địa điểm',
            attach.placeCoverUrl ?? '',
            attach.placeProvince ?? '',
            attach.placeRating ?? 5.0,
            attach.placePrice ?? '',
          );
        },
        child: Container(
          width: 230,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (attach.placeCoverUrl != null && attach.placeCoverUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: buildAppImage(
                    attach.placeCoverUrl,
                    width: 230,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attach.placeName ?? 'Địa điểm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: messengerDark),
                    ),
                    const SizedBox(height: 3),
                    const Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFEF4444)),
                        SizedBox(width: 3),
                        Text(
                          'Xem chi tiết điểm đến',
                          style: TextStyle(fontSize: 11, color: messengerBlue, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (attach.attachmentType == MessageAttachmentType.food && attach.foodId != null) {
      return Container(
        width: 230,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attach.foodCoverUrl != null && attach.foodCoverUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: buildAppImage(
                  attach.foodCoverUrl,
                  width: 230,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attach.foodName ?? 'Đặc sản',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: messengerDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attach.foodProvince ?? 'Món ngon địa phương',
                    style: const TextStyle(fontSize: 11, color: messengerSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (attach.attachmentType == MessageAttachmentType.trip && attach.tripId != null) {
      return GestureDetector(
        onTap: () {
          _navigateToItineraryDetail(
            attach.tripId!,
            attach.tripTitle ?? 'Lịch trình',
            attach.tripCoverUrl ?? '',
          );
        },
        child: Container(
          width: 230,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (attach.tripCoverUrl != null && attach.tripCoverUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: buildAppImage(
                    attach.tripCoverUrl,
                    width: 230,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attach.tripTitle ?? 'Lịch trình khám phá',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: messengerDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      attach.tripDestination ?? 'Xem lịch trình chi tiết',
                      style: const TextStyle(fontSize: 11, color: messengerBlue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (attach.attachmentType == MessageAttachmentType.blog &&
        (attach.blogId != null || (attach.blogTitle != null && attach.blogTitle!.isNotEmpty))) {
      return GestureDetector(
        onTap: () {
          _navigateToBlogDetail(
            attach.blogId ?? '',
            attach.blogTitle ?? 'Cẩm nang du lịch',
            attach.blogCoverUrl ?? '',
            attach.blogCategory ?? 'Kinh nghiệm du lịch',
            attach.blogAuthorName ?? 'Tác giả',
            attach.blogAuthorAvatar ?? '',
            attach.blogReadTimeMinutes ?? 5,
          );
        },
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (attach.blogCoverUrl != null && attach.blogCoverUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: buildAppImage(
                    attach.blogCoverUrl,
                    width: 240,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (attach.blogCategory != null && attach.blogCategory!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          attach.blogCategory!,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    Text(
                      attach.blogTitle ?? 'Cẩm nang du lịch',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: messengerDark,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: const [
                        Icon(Icons.menu_book_rounded, size: 13, color: Color(0xFF047857)),
                        SizedBox(width: 4),
                        Text(
                          'Đọc tiếp cẩm nang',
                          style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Replying Banner (Full viền & Bo tròn)
            if (_replyingToMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: messengerBgGray,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 16, color: messengerBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đang trả lời ${_replyingToMessage!.senderName}: "${_replyingToMessage!.content ?? 'Đính kèm'}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: messengerDark, fontWeight: FontWeight.w600),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _replyingToMessage = null),
                      child: const Icon(Icons.close_rounded, size: 16, color: messengerSub),
                    ),
                  ],
                ),
              ),

            // Pending Attached Place Banner
            if (_pendingAttachedPlace != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
                ),
                child: Row(
                  children: [
                    if (_pendingAttachedPlace!.mediaUrls.isNotEmpty || _pendingAttachedPlace!.img.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: buildAppImage(
                          _pendingAttachedPlace!.mediaUrls.isNotEmpty
                              ? _pendingAttachedPlace!.mediaUrls.first
                              : _pendingAttachedPlace!.img,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Color(0xFF16A34A), size: 20),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ĐỊA ĐIỂM ĐÍNH KÈM',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pendingAttachedPlace!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: messengerDark),
                          ),
                          Text(
                            _pendingAttachedPlace!.province.isNotEmpty
                                ? _pendingAttachedPlace!.province
                                : (_pendingAttachedPlace!.location.isNotEmpty ? _pendingAttachedPlace!.location : 'Việt Nam'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: messengerSub),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _pendingAttachedPlace = null),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: messengerDark),
                      ),
                    ),
                  ],
                ),
              ),

            // Pending Attached Blog Banner
            if (_pendingAttachedBlog != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                ),
                child: Row(
                  children: [
                    if (_pendingAttachedBlog!.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: buildAppImage(
                          _pendingAttachedBlog!.imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.article_outlined, size: 20, color: Color(0xFF047857)),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CẨM NANG ĐÍNH KÈM',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pendingAttachedBlog!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: messengerDark),
                          ),
                          Text(
                            '${_pendingAttachedBlog!.category} • ${_pendingAttachedBlog!.readTimeMinutes} phút đọc',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: messengerSub),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _pendingAttachedBlog = null),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: messengerDark),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Input Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Attachment Sheet trigger
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: messengerBlue, size: 24),
                    tooltip: 'Đính kèm nội dung',
                    onPressed: _openAttachmentActionSheet,
                  ),

                  // Image picker quick button
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: messengerBlue, size: 24),
                    tooltip: 'Gửi ảnh',
                    onPressed: _openImageDialog,
                  ),

                  // Text Field (Full viền & Bo tròn góc)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: messengerBgGray,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _inputFocusNode.hasFocus
                              ? const Color(0xFF059669)
                              : const Color(0xFFCBD5E1),
                          width: _inputFocusNode.hasFocus ? 1.5 : 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _inputFocusNode,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _handleSendMessage(),
                        style: const TextStyle(fontSize: 14, color: messengerDark),
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          hintStyle: TextStyle(fontSize: 13.5, color: messengerSub),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Send Button
                  IconButton(
                    icon: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (_textController.text.trim().isNotEmpty || _pendingAttachedPlace != null) && !_isSending
                            ? messengerBlue
                            : messengerBgGray,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (_textController.text.trim().isNotEmpty || _pendingAttachedPlace != null) && !_isSending
                              ? const Color(0xFF0070DF)
                              : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: (_textController.text.trim().isNotEmpty || _pendingAttachedPlace != null)
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                    ),
                    onPressed: (_textController.text.trim().isNotEmpty || _pendingAttachedPlace != null) && !_isSending
                        ? () => _handleSendMessage()
                        : null,
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

/// Chat Drawer / Modal for room details matching Share_Locations ChatDrawer
class _ChatDrawerModal extends StatefulWidget {
  final int roomId;
  final String roomName;
  final String? roomAvatar;
  final bool isGroup;
  final List<ChatMessage> messages;
  final Function(String newName) onRoomNameChanged;
  final Function(String url) onPreviewImage;

  const _ChatDrawerModal({
    required this.roomId,
    required this.roomName,
    this.roomAvatar,
    required this.isGroup,
    required this.messages,
    required this.onRoomNameChanged,
    required this.onPreviewImage,
  });

  @override
  State<_ChatDrawerModal> createState() => _ChatDrawerModalState();
}

class _ChatDrawerModalState extends State<_ChatDrawerModal> {
  final ChatApiService _chatService = ChatApiService();

  List<ChatRoomMember> _members = [];
  bool _isLoadingMembers = false;
  bool _isCustomizationOpen = true;
  bool _isMembersOpen = true;
  bool _isMediaOpen = true;

  @override
  void initState() {
    super.initState();
    if (widget.isGroup) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    final res = await _chatService.getRoomMembers(widget.roomId);
    if (mounted) {
      setState(() {
        _isLoadingMembers = false;
        if (res.success && res.data != null) {
          _members = res.data!;
        }
      });
    }
  }

  void _openRenameModal() {
    final controller = TextEditingController(text: widget.roomName);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Đổi tên đoạn chat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Nhập tên mới cho nhóm...',
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF65676B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0084FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(dialogCtx);
                final res = await _chatService.renameRoom(widget.roomId, newName);
                if (res.success) {
                  widget.onRoomNameChanged(newName);
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _openAddMembersModal() {
    final existingMemberIds = _members.map((m) => m.userId).toSet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMembersToGroupModalSheet(
        roomId: widget.roomId,
        existingMemberIds: existingMemberIds,
        onMembersAdded: () {
          _loadMembers();
        },
      ),
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Rời khỏi nhóm?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text('Bạn sẽ không còn nhận được tin nhắn từ nhóm trò chuyện này nữa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF65676B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _chatService.leaveRoom(widget.roomId);
              if (mounted) {
                Navigator.pop(context); // Close Drawer
                Navigator.pop(context); // Close Room Screen
              }
            },
            child: const Text('Rời nhóm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaImages = <String>[];
    for (final m in widget.messages) {
      for (final att in m.attachments) {
        if (att.attachmentType == MessageAttachmentType.image && att.mediaUrl != null) {
          mediaImages.add(att.mediaUrl!);
        }
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Top Center Info
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: widget.isGroup && (widget.roomAvatar == null || widget.roomAvatar!.isEmpty || !widget.roomAvatar!.startsWith('http'))
                            ? Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0084FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.groups_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              )
                            : (widget.roomAvatar != null && widget.roomAvatar!.isNotEmpty
                                ? buildAppImage(widget.roomAvatar, width: 72, height: 72, fit: BoxFit.cover)
                                : Container(
                                    width: 72,
                                    height: 72,
                                    color: widget.isGroup ? const Color(0xFF0084FF) : const Color(0xFFEBF5FF),
                                    child: Icon(
                                      widget.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                                      color: widget.isGroup ? Colors.white : const Color(0xFF0084FF),
                                      size: 38,
                                    ),
                                  )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.roomName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF050505)),
                  ),
                  const SizedBox(height: 18),

                  const Divider(height: 1, color: Color(0xFFE4E6EB)),

                  // ── ACCORDION 1: TÙY CHỈNH ĐOẠN CHAT (CHỈ CHO GROUP) ──
                  if (widget.isGroup) ...[
                    InkWell(
                      onTap: () => setState(() => _isCustomizationOpen = !_isCustomizationOpen),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tùy chỉnh đoạn chat',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF050505)),
                            ),
                            Icon(
                              _isCustomizationOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: const Color(0xFF65676B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isCustomizationOpen) ...[
                      ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFF0F2F5), shape: BoxShape.circle),
                          child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF050505)),
                        ),
                        title: const Text('Đổi tên đoạn chat', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        onTap: _openRenameModal,
                      ),
                      ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                          child: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFDC2626)),
                        ),
                        title: const Text('Rời khỏi nhóm', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                        onTap: _confirmLeaveGroup,
                      ),
                    ],
                    const Divider(height: 1, color: Color(0xFFE4E6EB)),
                  ],

                  // ── ACCORDION 2: THÀNH VIÊN TRONG ĐOẠN CHAT (CHỈ CHO GROUP) ──
                  if (widget.isGroup) ...[
                    InkWell(
                      onTap: () => setState(() => _isMembersOpen = !_isMembersOpen),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Thành viên trong đoạn chat ${_members.isNotEmpty ? "(${_members.length})" : ""}',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF050505)),
                            ),
                            Icon(
                              _isMembersOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: const Color(0xFF65676B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isMembersOpen) ...[
                      // Add member button
                      ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFEBF5FF), shape: BoxShape.circle),
                          child: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Color(0xFF0084FF)),
                        ),
                        title: const Text('Thêm người', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0084FF))),
                        onTap: _openAddMembersModal,
                      ),

                      if (_isLoadingMembers)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0084FF))),
                        )
                      else
                        ..._members.map((m) {
                          final isMemberAdmin = m.role == 'Admin' || m.role == 'admin' || m.isAdmin;
                          return ListTile(
                            dense: true,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: m.avatarUrl != null && m.avatarUrl!.isNotEmpty
                                  ? buildAppImage(m.avatarUrl, width: 32, height: 32, fit: BoxFit.cover)
                                  : Container(
                                      width: 32,
                                      height: 32,
                                      color: const Color(0xFFEBF5FF),
                                      child: Center(child: Text(m.name[0], style: const TextStyle(fontWeight: FontWeight.bold))),
                                    ),
                            ),
                            title: Text(m.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                            trailing: isMemberAdmin
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEBF5FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Quản trị viên', style: TextStyle(fontSize: 10, color: Color(0xFF0084FF), fontWeight: FontWeight.w700)),
                                  )
                                : null,
                          );
                        }),
                    ],
                    const Divider(height: 1, color: Color(0xFFE4E6EB)),
                  ],

                  // ── ACCORDION 3: FILE PHƯƠNG TIỆN & ẢNH ──
                  InkWell(
                    onTap: () => setState(() => _isMediaOpen = !_isMediaOpen),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'File phương tiện & Ảnh (${mediaImages.length})',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF050505)),
                          ),
                          Icon(
                            _isMediaOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF65676B),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isMediaOpen) ...[
                    if (mediaImages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Chưa có hình ảnh nào được chia sẻ.', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          childAspectRatio: 1,
                        ),
                        itemCount: mediaImages.length,
                        itemBuilder: (ctx, i) {
                          final imgUrl = mediaImages[i];
                          return GestureDetector(
                            onTap: () => widget.onPreviewImage(imgUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: buildAppImage(imgUrl, fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet tìm kiếm và thêm thành viên từ CSDL vào nhóm chat hiện tại
class _AddMembersToGroupModalSheet extends StatefulWidget {
  final int roomId;
  final Set<int> existingMemberIds;
  final VoidCallback onMembersAdded;

  const _AddMembersToGroupModalSheet({
    required this.roomId,
    required this.existingMemberIds,
    required this.onMembersAdded,
  });

  @override
  State<_AddMembersToGroupModalSheet> createState() => _AddMembersToGroupModalSheetState();
}

class _AddMembersToGroupModalSheetState extends State<_AddMembersToGroupModalSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FriendApiService _friendService = FriendApiService();
  final ChatApiService _chatService = ChatApiService();
  final AuthService _authService = AuthService();
  final Set<int> _selectedMemberIds = {};
  final Map<int, FriendUser> _userCache = {};

  int? _currentUserId;
  String? _currentUserEmail;
  List<FriendUser> _friendsList = [];
  List<FriendUser> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isAdding = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadInitialFriends();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCachedUser();
      if (user != null && mounted) {
        setState(() {
          _currentUserId = int.tryParse(user.id);
          _currentUserEmail = user.email.toLowerCase().trim();
          if (_currentUserId != null) {
            _selectedMemberIds.remove(_currentUserId);
          }
        });
      }
    } catch (_) {}
  }

  bool _isSelf(FriendUser u) {
    if (_currentUserId != null && u.id == _currentUserId) return true;
    if (_currentUserEmail != null &&
        _currentUserEmail!.isNotEmpty &&
        u.email.trim().toLowerCase() == _currentUserEmail) {
      return true;
    }
    return false;
  }

  Future<void> _loadInitialFriends() async {
    try {
      final res = await _friendService.getFriends();
      if (mounted && res.success && res.data != null) {
        setState(() {
          _friendsList = res.data!.friends;
          for (final f in _friendsList) {
            _userCache[f.id] = f;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    final query = val.trim();
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final res = await _friendService.searchUsers(query);
        if (mounted) {
          setState(() {
            _isSearching = false;
            if (res.success && res.data != null) {
              _searchResults = res.data!.where((u) => !_isSelf(u)).toList();
              for (final u in _searchResults) {
                _userCache[u.id] = u;
              }
            } else {
              _searchResults = [];
            }
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  List<FriendUser> get _displayUsers {
    final query = _searchCtrl.text.trim().toLowerCase();
    
    // Filter out existing room members and self
    if (query.isEmpty) {
      return _friendsList
          .where((f) => !_isSelf(f) && !widget.existingMemberIds.contains(f.id))
          .toList();
    }

    final localMatches = _friendsList.where((f) {
      return !_isSelf(f) &&
          !widget.existingMemberIds.contains(f.id) &&
          (f.fullName.toLowerCase().contains(query) || f.email.toLowerCase().contains(query));
    }).toList();

    final seenIds = localMatches.map((e) => e.id).toSet();
    final combined = List<FriendUser>.from(localMatches);

    for (final u in _searchResults) {
      if (!_isSelf(u) && !widget.existingMemberIds.contains(u.id) && !seenIds.contains(u.id)) {
        seenIds.add(u.id);
        combined.add(u);
      }
    }

    return combined;
  }

  Future<void> _handleAddMembers() async {
    if (_selectedMemberIds.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng chọn ít nhất 1 thành viên');
      return;
    }

    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });

    try {
      for (final id in _selectedMemberIds) {
        await _chatService.addMemberToRoom(widget.roomId, id);
      }
      widget.onMembersAdded();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm ${_selectedMemberIds.length} thành viên vào nhóm'),
            backgroundColor: const Color(0xFF0084FF),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể thêm thành viên. Vui lòng thử lại.';
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _displayUsers;
    final query = _searchCtrl.text.trim();
    final selectedUsers = _selectedMemberIds.map((id) {
      return _userCache[id] ?? FriendUser(id: id, fullName: 'Người dùng #$id');
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0084FF), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thêm thành viên vào nhóm',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Selected Chips
          if (selectedUsers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedUsers.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final f = selectedUsers[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF5FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCCE5FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            f.fullName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0084FF),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              setState(() => _selectedMemberIds.remove(f.id));
                            },
                            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF0084FF)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc email người dùng...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : (_isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0084FF)),
                              ),
                            )
                          : null),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // User list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0084FF), strokeWidth: 2.5),
                  )
                : list.isEmpty && !_isSearching
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_search_rounded, size: 40, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              query.isNotEmpty
                                  ? 'Không tìm thấy người dùng nào khớp với "$query"'
                                  : 'Tất cả bạn bè đã ở trong nhóm này',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final user = list[index];
                          final isSelected = _selectedMemberIds.contains(user.id);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedMemberIds.remove(user.id);
                                } else {
                                  _selectedMemberIds.add(user.id);
                                  _userCache[user.id] = user;
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Avatar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: user.avatarUrl.isNotEmpty
                                        ? buildAppImage(user.avatarUrl, width: 40, height: 40, fit: BoxFit.cover)
                                        : Container(
                                            width: 40,
                                            height: 40,
                                            color: const Color(0xFFEBF5FF),
                                            child: Center(
                                              child: Text(
                                                (user.fullName.isNotEmpty ? user.fullName[0] : 'U').toUpperCase(),
                                                style: const TextStyle(color: Color(0xFF0084FF), fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Name & Bio / Email
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (user.email.isNotEmpty || user.bio.isNotEmpty)
                                          Text(
                                            user.email.isNotEmpty ? user.email : user.bio,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Checkbox
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF0084FF) : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF0084FF) : const Color(0xFFCBD5E1),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          if (_errorMessage != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Footer Action Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE4E6EB))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: (_isAdding || _selectedMemberIds.isEmpty) ? null : _handleAddMembers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _selectedMemberIds.isEmpty
                            ? 'Chọn thành viên'
                            : 'Thêm ${_selectedMemberIds.length} thành viên vào nhóm',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


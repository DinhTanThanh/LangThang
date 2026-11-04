import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/services/friend_api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_api_service.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/chat/chat_room_screen.dart';
import '../../screens/profile/user_profile_screen.dart';
import 'unfriend_confirm_dialog.dart';

class FriendsSectionWidget extends StatefulWidget {
  final bool isDrawer;
  final VoidCallback? onClose;
  final Function(String message)? onToast;
  final VoidCallback? onFriendsCountChanged;

  const FriendsSectionWidget({
    super.key,
    this.isDrawer = false,
    this.onClose,
    this.onToast,
    this.onFriendsCountChanged,
  });

  @override
  State<FriendsSectionWidget> createState() => _FriendsSectionWidgetState();
}

class _FriendsSectionWidgetState extends State<FriendsSectionWidget> {
  final FriendApiService _friendService = FriendApiService();

  // Tab values: 'accepted', 'incoming', 'outgoing', 'search'
  String _activeTab = 'accepted';
  bool _isLoading = true;

  // Lists from getFriends API
  List<FriendUser> _friends = [];
  List<FriendUser> _incomingRequests = [];
  List<FriendUser> _outgoingRequests = [];

  // Search inside friend list (accepted tab)
  final TextEditingController _localSearchController = TextEditingController();

  // Global user search in 'search' tab
  final TextEditingController _globalSearchController = TextEditingController();
  List<FriendUser> _searchResults = [];
  bool _isSearchingGlobal = false;
  final List<int> _sentRequestIds = [];
  Timer? _debounceTimer;

  bool _isActionPending = false;

  @override
  void initState() {
    super.initState();
    _fetchFriendsData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _localSearchController.dispose();
    _globalSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFriendsData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _friendService.getFriends();
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (res.success && res.data != null) {
            _friends = res.data!.friends;
            _incomingRequests = res.data!.pendingRequestsReceived;
            _outgoingRequests = res.data!.pendingRequestsSent;
          } else {
            _friends = [];
            _incomingRequests = [];
            _outgoingRequests = [];
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _friends = [];
          _incomingRequests = [];
          _outgoingRequests = [];
        });
      }
    }
  }

  void _onGlobalSearchChanged(String val) {
    _debounceTimer?.cancel();
    final query = val.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchingGlobal = false;
      });
      return;
    }

    setState(() => _isSearchingGlobal = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final res = await _friendService.searchUsers(query);
        if (mounted) {
          setState(() {
            _isSearchingGlobal = false;
            _searchResults = (res.success && res.data != null) ? res.data! : [];
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSearchingGlobal = false;
            _searchResults = [];
          });
        }
      }
    });
  }

  void _showToast(String message) {
    if (widget.onToast != null) {
      widget.onToast!(message);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Open Direct Chat
  Future<void> _handleOpenChat(FriendUser friend) async {
    final isLoggedIn = await AuthService().isLoggedIn();
    final token = await AuthService().getAccessToken();
    if (!isLoggedIn || token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để gửi tin nhắn.'),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final didLogin = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (didLogin != true || !mounted) return;
    }

    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    widget.onClose?.call();

    try {
      final res = await ChatApiService().getOrCreateDirectRoom(
        friend.id,
        targetUserName: friend.fullName,
        targetUserAvatar: friend.avatarUrl,
      );

      final roomId = (res.success && res.data != null && res.data! > 0) ? res.data! : 0;

      nav.push(
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            roomId: roomId,
            roomName: friend.fullName,
            roomAvatar: friend.avatarUrl,
            otherUserId: friend.id,
          ),
        ),
      );
    } catch (_) {
      nav.push(
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            roomId: 0,
            roomName: friend.fullName,
            roomAvatar: friend.avatarUrl,
            otherUserId: friend.id,
          ),
        ),
      );
    }
  }

  // Accept or Decline Friend Request
  Future<void> _handleRespondRequest(FriendUser reqUser, bool accept) async {
    setState(() => _isActionPending = true);
    try {
      final res = await _friendService.respondFriendRequest(reqUser.id, accept ? 'accept' : 'reject');
      if (mounted) {
        if (res.success) {
          setState(() {
            _incomingRequests.removeWhere((f) => f.id == reqUser.id);
            if (accept) {
              _friends.insert(0, reqUser.copyWith(status: FriendshipStatus.accepted));
              _showToast('Đã chấp nhận lời mời từ ${reqUser.fullName}.');
            } else {
              _showToast('Đã từ chối lời mời kết bạn.');
            }
          });
          widget.onFriendsCountChanged?.call();
        } else {
          _showToast(res.message);
        }
      }
    } catch (_) {
      _showToast('Có lỗi xảy ra khi xử lý lời mời.');
    } finally {
      if (mounted) setState(() => _isActionPending = false);
    }
  }

  // Send Friend Request
  Future<void> _handleSendRequest(int userId, String userName) async {
    try {
      final res = await _friendService.sendFriendRequest(userId);
      if (mounted) {
        if (res.success) {
          setState(() {
            _sentRequestIds.add(userId);
          });
          _showToast('Đã gửi lời mời kết bạn đến $userName!');
          _fetchFriendsData();
        } else {
          _showToast(res.message);
        }
      }
    } catch (_) {
      _showToast('Có lỗi xảy ra khi gửi lời mời.');
    }
  }

  // Cancel Outgoing Request
  Future<void> _handleCancelOutgoing(FriendUser friend) async {
    try {
      final res = await _friendService.unfriend(friend.id);
      if (mounted) {
        if (res.success) {
          setState(() {
            _outgoingRequests.removeWhere((f) => f.id == friend.id);
            _sentRequestIds.remove(friend.id);
          });
          _showToast('Đã hủy lời mời gửi đến ${friend.fullName}.');
        } else {
          _showToast(res.message);
        }
      }
    } catch (_) {
      _showToast('Có lỗi xảy ra khi hủy lời mời.');
    }
  }

  // Confirm Unfriend Modal
  void _promptUnfriend(FriendUser friend) {
    showDialog(
      context: context,
      builder: (context) => UnfriendConfirmDialog(
        user: friend,
        onConfirm: () async {
          setState(() => _isActionPending = true);
          try {
            final res = await _friendService.unfriend(friend.id);
            if (mounted) {
              if (res.success) {
                setState(() {
                  _friends.removeWhere((f) => f.id == friend.id);
                });
                _showToast('Đã hủy kết bạn với ${friend.fullName}.');
                widget.onFriendsCountChanged?.call();
              } else {
                _showToast('Không thể hủy kết bạn lúc này.');
              }
            }
          } catch (_) {
            _showToast('Có lỗi xảy ra khi hủy kết bạn.');
          } finally {
            if (mounted) setState(() => _isActionPending = false);
          }
        },
      ),
    );
  }

  // Filter friends list by local search
  List<FriendUser> get _filteredFriends {
    final q = _localSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends.where((f) {
      return f.fullName.toLowerCase().contains(q) || f.email.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'id': 'accepted', 'label': 'Bạn bè', 'count': _friends.length},
      {'id': 'incoming', 'label': 'Lời mời', 'count': _incomingRequests.length},
      {'id': 'outgoing', 'label': 'Đã gửi', 'count': _outgoingRequests.length},
      {'id': 'search', 'label': 'Tìm bạn mới'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub Tabs Header (Exact Share_Locations layout)
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isDrawer ? 16 : 0,
            vertical: widget.isDrawer ? 12 : 8,
          ),
          decoration: BoxDecoration(
            color: widget.isDrawer ? Colors.white : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: widget.isDrawer ? const Color(0xFFE2E8F0) : Colors.transparent,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: tabs.map((tab) {
                    final id = tab['id'] as String;
                    final isSelected = _activeTab == id;
                    final count = tab['count'] as int?;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() => _activeTab = id);
                          if (id != 'search') {
                            _fetchFriendsData();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF3730A3) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF3730A3).withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tab['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                              if (count != null) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF312E81) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? const Color(0xFFE0E7FF) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Local Search Field (when in 'accepted' tab and not drawer)
              if (!widget.isDrawer && _activeTab == 'accepted') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 340),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _localSearchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm bạn bè...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                      suffixIcon: _localSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _localSearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Main Content
        if (_isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 50),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF3730A3),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Đang tải danh sách bạn bè...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          _buildActiveTabBody(),
      ],
    );
  }

  Widget _buildActiveTabBody() {
    switch (_activeTab) {
      case 'accepted':
        return _buildAcceptedFriendsTab();
      case 'incoming':
        return _buildIncomingRequestsTab();
      case 'outgoing':
        return _buildOutgoingRequestsTab();
      case 'search':
        return _buildSearchUsersTab();
      default:
        return const SizedBox();
    }
  }

  // ==================== 1. TAB BẠN BÈ (ACCEPTED) ====================
  Widget _buildAcceptedFriendsTab() {
    final list = _filteredFriends;

    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Chưa có bạn bè nào',
        subtitle: 'Kết nối với những người đam mê xê dịch để cùng chia sẻ kinh nghiệm và đồng hành trên mọi nẻo đường.',
        actionLabel: 'Tìm bạn mới',
        onAction: () => setState(() => _activeTab = 'search'),
      );
    }

    if (widget.isDrawer) {
      // Drawer list mode
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final friend = list[index];
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar & Info Clickable to UserProfileScreen
                Expanded(
                  child: InkWell(
                    onTap: () {
                      UserProfileScreen.navigate(
                        context,
                        userId: friend.id,
                        userName: friend.fullName,
                        userAvatar: friend.avatarUrl,
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(shape: BoxShape.circle),
                          clipBehavior: Clip.antiAlias,
                          child: friend.avatarUrl.isNotEmpty
                              ? buildAppImage(
                                  friend.avatarUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: _buildAvatarFallback(friend.fullName),
                                )
                              : _buildAvatarFallback(friend.fullName),
                        ),
                        const SizedBox(width: 10),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                friend.email.isNotEmpty ? friend.email : 'Thành viên',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _handleOpenChat(friend),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 15,
                          color: Color(0xFF0084FF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _promptUnfriend(friend),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_remove_rounded,
                          size: 15,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    // Full page Grid Mode (Exact Share_Locations grid layout)
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 650) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 420) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.88,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final friend = list[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clickable Avatar & Info -> UserProfileScreen
                  InkWell(
                    onTap: () {
                      UserProfileScreen.navigate(
                        context,
                        userId: friend.id,
                        userName: friend.fullName,
                        userAvatar: friend.avatarUrl,
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE0E7FF), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: friend.avatarUrl.isNotEmpty
                              ? buildAppImage(
                                  friend.avatarUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: _buildAvatarFallback(friend.fullName, size: 22),
                                )
                              : _buildAvatarFallback(friend.fullName, size: 22),
                        ),
                        const SizedBox(height: 10),

                        // Name
                        Text(
                          friend.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),

                        // Subtitle / Email
                        const SizedBox(height: 2),
                        Text(
                          friend.email.isNotEmpty ? friend.email : 'Thành viên du lịch',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),

                  // Mutual friends count if > 0
                  if (friend.mutualFriendsCount > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${friend.mutualFriendsCount} bạn chung',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Bottom Action Buttons
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        // Message button
                        Expanded(
                          child: InkWell(
                            onTap: () => _handleOpenChat(friend),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 13,
                                    color: Color(0xFF0084FF),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Nhắn tin',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0084FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Unfriend button
                        InkWell(
                          onTap: () => _promptUnfriend(friend),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(7.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person_remove_rounded,
                              size: 15,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== 2. TAB LỜI MỜI (INCOMING) ====================
  Widget _buildIncomingRequestsTab() {
    if (_incomingRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.how_to_reg_outlined,
        title: 'Không có lời mời kết bạn nào',
        subtitle: 'Khi ai đó gửi lời mời kết bạn cho bạn, yêu cầu sẽ hiển thị tại đây.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _incomingRequests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final req = _incomingRequests[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: req.avatarUrl.isNotEmpty
                    ? buildAppImage(
                        req.avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: _buildAvatarFallback(req.fullName),
                      )
                    : _buildAvatarFallback(req.fullName),
              ),
              const SizedBox(width: 12),

              // Name & Note
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      req.email.isNotEmpty ? req.email : 'Muốn kết bạn với bạn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // Actions: Đồng ý & Xóa
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isActionPending ? null : () => _handleRespondRequest(req, true),
                    icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    label: const Text(
                      'Đồng ý',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _isActionPending ? null : () => _handleRespondRequest(req, false),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Xóa',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== 3. TAB ĐÃ GỬI (OUTGOING) ====================
  Widget _buildOutgoingRequestsTab() {
    if (_outgoingRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.schedule_rounded,
        title: 'Chưa gửi lời mời nào',
        subtitle: 'Tìm kiếm bạn bè mới và mở rộng mạng lưới phượt thủ cùng sở thích.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _outgoingRequests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final req = _outgoingRequests[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: req.avatarUrl.isNotEmpty
                    ? buildAppImage(
                        req.avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: _buildAvatarFallback(req.fullName),
                      )
                    : _buildAvatarFallback(req.fullName),
              ),
              const SizedBox(width: 12),

              // Name & Status Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Đã gửi lời mời kết bạn',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // "Đang chờ..." badge & Cancel action
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Đang chờ...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                    tooltip: 'Hủy lời mời',
                    onPressed: () => _handleCancelOutgoing(req),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== 4. TAB TÌM BẠN MỚI (SEARCH) ====================
  Widget _buildSearchUsersTab() {
    final searchInput = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _globalSearchController,
              onChanged: _onGlobalSearchChanged,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                hintText: 'Nhập tên hoặc email người dùng để tìm kiếm...',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_globalSearchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
              onPressed: () {
                _globalSearchController.clear();
                _onGlobalSearchChanged('');
              },
            ),
        ],
      ),
    );

    if (_isSearchingGlobal) {
      return Column(
        children: [
          searchInput,
          const SizedBox(height: 30),
          const Column(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3730A3)),
              ),
              SizedBox(height: 10),
              Text(
                'Đang tìm kiếm người dùng...',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      );
    }

    if (_searchResults.isNotEmpty) {
      return Column(
        children: [
          searchInput,
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _searchResults.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              final isAlreadyFriend = _friends.any((f) => f.id == user.id);
              final isSent = _sentRequestIds.contains(user.id) ||
                  _outgoingRequests.any((f) => f.id == user.id) ||
                  user.status == FriendshipStatus.pendingOutgoing;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      clipBehavior: Clip.antiAlias,
                      child: user.avatarUrl.isNotEmpty
                          ? buildAppImage(
                              user.avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: _buildAvatarFallback(user.fullName),
                            )
                          : _buildAvatarFallback(user.fullName),
                    ),
                    const SizedBox(width: 12),

                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            user.email.isNotEmpty ? user.email : 'Thành viên',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),

                    // Right Button/Badge
                    if (isAlreadyFriend)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Bạn bè',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF047857),
                          ),
                        ),
                      )
                    else if (isSent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Đã gửi',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _handleSendRequest(user.id, user.fullName),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 14, color: Colors.white),
                        label: const Text(
                          'Kết bạn',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3730A3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    }

    if (_globalSearchController.text.trim().isNotEmpty) {
      return Column(
        children: [
          searchInput,
          const SizedBox(height: 20),
          _buildEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Không tìm thấy người dùng',
            subtitle: 'Không có người dùng nào khớp với từ khóa tìm kiếm.',
          ),
        ],
      );
    }

    return Column(
      children: [
        searchInput,
        const SizedBox(height: 20),
        _buildEmptyState(
          icon: Icons.person_search_rounded,
          title: 'Khám phá bạn bè mới',
          subtitle: 'Nhập từ khóa để tìm kiếm và kết bạn với mọi người trên hệ thống.',
        ),
      ],
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildAvatarFallback(String name, {double size = 16}) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      color: const Color(0xFF3730A3),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: const Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 14, color: Colors.white),
              label: Text(
                actionLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3730A3),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

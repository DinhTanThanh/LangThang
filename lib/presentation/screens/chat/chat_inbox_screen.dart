import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_api_service.dart';
import '../../../data/services/friend_api_service.dart';
import '../auth/login_screen.dart';
import 'chat_room_screen.dart';

const Color messengerBlue = Color(0xFF0084FF);
const Color messengerBlueLight = Color(0xFFEBF5FF);
const Color messengerBgGray = Color(0xFFF0F2F5);
const Color messengerDark = Color(0xFF050505);
const Color messengerSub = Color(0xFF65676B);
const Color messengerBorder = Color(0xFFE4E6EB);

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final ChatApiService _chatService = ChatApiService();
  final FriendApiService _friendService = FriendApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<InboxItem> _inboxList = [];
  bool _isLoading = true;
  bool _isLoggedIn = true;
  String _filter = 'all'; // 'all', 'unread', 'group'

  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<int>? _unreadSub;

  @override
  void initState() {
    super.initState();
    _loadInbox();

    // Listen to real-time events to keep inbox updated
    _msgSub = _chatService.onMessageReceived.listen((_) => _loadInbox(silent: true));
    _unreadSub = _chatService.onTotalUnreadCountChanged.listen((_) => _loadInbox(silent: true));
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _unreadSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInbox({bool silent = false}) async {
    final loggedIn = await _authService.isLoggedIn();
    final token = await _authService.getAccessToken();
    if (!loggedIn || token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
          _inboxList = [];
        });
        if (!silent) {
          final didLogin = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          if (didLogin == true && mounted) {
            _loadInbox();
          }
        }
      }
      return;
    }

    if (!silent) setState(() => _isLoading = true);
    final res = await _chatService.getInbox();
    if (mounted) {
      if (!res.success && (res.message.contains('UNAUTHORIZED') || res.message.contains('đăng nhập'))) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
          _inboxList = [];
        });
        if (!silent) {
          final didLogin = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          if (didLogin == true && mounted) {
            _loadInbox();
          }
        }
        return;
      }

      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
        if (res.success && res.data != null) {
          _inboxList = res.data!;
        } else {
          _inboxList = [];
        }
      });
    }
  }

  List<InboxItem> get _filteredList {
    var list = _inboxList;
    if (_filter == 'unread') {
      list = list.where((i) => i.unreadCount > 0).toList();
    } else if (_filter == 'group') {
      list = list.where((i) => i.isGroup).toList();
    }

    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((i) =>
          i.name.toLowerCase().contains(q) ||
          (i.lastMessage?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    try {
      final now = DateTime.now();
      final diff = now.difference(dt);
      final diffMins = diff.inMinutes;
      final diffHours = diff.inHours;
      final diffDays = diff.inDays;

      if (diffMins < 1) return 'Vừa xong';
      if (diffMins < 60) return '$diffMins phút';
      if (diffHours < 24) return '$diffHours giờ';
      if (diffDays < 7) return '$diffDays ngày';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  void _openNewChatModal() async {
    List<FriendUser> friends = [];
    try {
      final friendRes = await _friendService.getFriends();
      if (friendRes.success && friendRes.data != null) {
        friends = friendRes.data!.friends;
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _NewChatWithFriendModalSheet(
          friends: friends,
          onSelectFriend: (friend) async {
            final res = await _chatService.getOrCreateDirectRoom(
              friend.id,
              targetUserName: friend.fullName,
              targetUserAvatar: friend.avatarUrl,
            );
            if (res.success && res.data != null) {
              await _loadInbox(silent: true);
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRoomScreen(
                      roomId: res.data!,
                      roomName: friend.fullName,
                      roomAvatar: friend.avatarUrl,
                      isGroup: false,
                      otherUserId: friend.id,
                    ),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  void _openCreateGroupModal() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      final loginRes = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (loginRes != true && !await _authService.isLoggedIn()) {
        return;
      }
    }

    List<FriendUser> friends = [];
    try {
      final friendRes = await _friendService.getFriends();
      if (friendRes.success && friendRes.data != null) {
        friends = friendRes.data!.friends;
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _CreateGroupModalSheet(
          initialFriends: friends,
          onCreateGroup: (name, memberIds) async {
            try {
              var res = await _chatService.createGroupRoom(name, memberIds);
              if (!res.success && res.message == 'AUTH_REQUIRED') {
                if (modalCtx.mounted) {
                  final loginRes = await Navigator.push(
                    modalCtx,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                  if (loginRes == true || await _authService.isLoggedIn()) {
                    res = await _chatService.createGroupRoom(name, memberIds);
                  }
                }
              }

              if (res.success && res.data != null) {
                await _loadInbox(silent: true);
                if (modalCtx.mounted) {
                  Navigator.pop(modalCtx);
                }
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatRoomScreen(
                        roomId: res.data!,
                        roomName: name,
                        isGroup: true,
                      ),
                    ),
                  );
                }
                return true;
              }
            } catch (e) {
              debugPrint('Error creating group room: $e');
            }
            return false;
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: const Text(
            'Đoạn chat',
            style: TextStyle(
              color: messengerDark,
              fontWeight: FontWeight.w900,
              fontSize: 23,
              letterSpacing: -0.6,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: messengerBlueLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 32,
                    color: messengerBlue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Yêu cầu đăng nhập',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: messengerDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Vui lòng đăng nhập để xem tin nhắn và trò chuyện cùng bạn bè.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: messengerSub),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    final loggedIn = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                    if (loggedIn == true && mounted) {
                      _loadInbox();
                    }
                  },
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: messengerBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = _filteredList;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        title: const Text(
          'Đoạn chat',
          style: TextStyle(
            color: messengerDark,
            fontWeight: FontWeight.w900,
            fontSize: 23,
            letterSpacing: -0.6,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: messengerBgGray,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: messengerDark,
                size: 19,
              ),
            ),
            tooltip: 'Nhắn tin với bạn bè',
            onPressed: _openNewChatModal,
          ),
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: messengerBgGray,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_add_rounded,
                color: messengerDark,
                size: 20,
              ),
            ),
            tooltip: 'Tạo nhóm trò chuyện mới',
            onPressed: _openCreateGroupModal,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: messengerBorder, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // 1. Search Bar
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: messengerBgGray,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14, color: messengerDark),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm cuộc trò chuyện, bạn bè...',
                      hintStyle: const TextStyle(fontSize: 13.5, color: messengerSub),
                      prefixIcon: const Icon(Icons.search_rounded, color: messengerSub, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: messengerSub),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Filter Tabs
                Row(
                  children: [
                    _buildFilterPill('all', 'Tất cả'),
                    const SizedBox(width: 8),
                    _buildFilterPill('unread', 'Chưa đọc'),
                    const SizedBox(width: 8),
                    _buildFilterPill('group', 'Nhóm'),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: messengerBorder),

          // Inbox List Feed
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: messengerBlue,
                      strokeWidth: 2.5,
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: const BoxDecoration(
                                color: messengerBlueLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 28,
                                color: messengerBlue,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _filter == 'group'
                                  ? 'Chưa có nhóm trò chuyện nào'
                                  : 'Không tìm thấy cuộc trò chuyện nào',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: messengerDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _filter == 'group'
                                  ? 'Hãy tạo nhóm để cùng bạn bè trao đổi và chia sẻ địa điểm nhé!'
                                  : 'Bắt đầu kết nối cùng bạn bè trên LangThang.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12.5, color: messengerSub),
                            ),
                            if (_filter == 'group') ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _openCreateGroupModal,
                                icon: const Icon(Icons.group_add_rounded, size: 16),
                                label: const Text('Tạo nhóm ngay'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: messengerBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: messengerBlue,
                        onRefresh: () => _loadInbox(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            indent: 76,
                            endIndent: 16,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final hasUnread = item.unreadCount > 0;

                            return InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatRoomScreen(
                                      roomId: item.roomId,
                                      roomName: item.name,
                                      roomAvatar: item.avatarUrl,
                                      isGroup: item.isGroup,
                                      otherUserId: item.otherUserId,
                                    ),
                                  ),
                                );
                                _loadInbox(silent: true);
                              },
                              child: Container(
                                color: hasUnread
                                    ? messengerBlueLight.withValues(alpha: 0.3)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    // Avatar with Online dot or Group badge
                                    Stack(
                                      children: [
                                        SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(25),
                                            child: item.isGroup && (item.avatarUrl == null || item.avatarUrl!.isEmpty || !item.avatarUrl!.startsWith('http'))
                                                ? Container(
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF0084FF),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.groups_rounded,
                                                        color: Colors.white,
                                                        size: 28,
                                                      ),
                                                    ),
                                                  )
                                                : (item.avatarUrl != null && item.avatarUrl!.isNotEmpty
                                                    ? buildAppImage(
                                                        item.avatarUrl,
                                                        width: 50,
                                                        height: 50,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Container(
                                                        color: item.isGroup ? const Color(0xFF0084FF) : messengerBlueLight,
                                                        child: Center(
                                                          child: Icon(
                                                            item.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                                                            color: item.isGroup ? Colors.white : messengerBlue,
                                                            size: item.isGroup ? 28 : 26,
                                                          ),
                                                        ),
                                                      )),
                                          ),
                                        ),
                                        if (item.isOnline && !item.isGroup)
                                          Positioned(
                                            right: 1,
                                            bottom: 1,
                                            child: Container(
                                              width: 13,
                                              height: 13,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 14),

                                    // Conversation Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                                                    color: messengerDark,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _formatTimestamp(item.lastMessageAt),
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                                                  color: hasUnread ? messengerBlue : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.lastMessage ?? 'Bắt đầu cuộc trò chuyện',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                                                    color: hasUnread ? messengerDark : messengerSub,
                                                  ),
                                                ),
                                              ),
                                              if (hasUnread) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: const BoxDecoration(
                                                    color: messengerBlue,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String key, String label) {
    final isSelected = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? messengerBlueLight : messengerBgGray,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? messengerBlue : messengerDark,
          ),
        ),
      ),
    );
  }
}

/// Create Group Modal with live database user search & checkbox selection
class _CreateGroupModalSheet extends StatefulWidget {
  final List<FriendUser> initialFriends;
  final Future<bool> Function(String name, List<int> memberIds) onCreateGroup;

  const _CreateGroupModalSheet({
    required this.initialFriends,
    required this.onCreateGroup,
  });

  @override
  State<_CreateGroupModalSheet> createState() => _CreateGroupModalSheetState();
}

class _CreateGroupModalSheetState extends State<_CreateGroupModalSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FriendApiService _friendService = FriendApiService();
  final AuthService _authService = AuthService();
  final Set<int> _selectedMemberIds = {};
  final Map<int, FriendUser> _userCache = {};
  
  int? _currentUserId;
  String? _currentUserEmail;
  List<FriendUser> _searchResults = [];
  bool _isSearching = false;
  bool _isCreating = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    for (final f in widget.initialFriends) {
      _userCache[f.id] = f;
    }
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _searchController.dispose();
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

    setState(() {
      _isSearching = true;
    });

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
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  List<FriendUser> get _displayMembers {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.initialFriends.where((f) => !_isSelf(f)).toList();
    }

    // Local friends matching
    final localMatches = widget.initialFriends.where((f) =>
        !_isSelf(f) &&
        (f.fullName.toLowerCase().contains(q) ||
            f.email.toLowerCase().contains(q))).toList();

    final seenIds = localMatches.map((e) => e.id).toSet();
    final combined = List<FriendUser>.from(localMatches);

    for (final u in _searchResults) {
      if (!_isSelf(u) && !seenIds.contains(u.id)) {
        seenIds.add(u.id);
        combined.add(u);
      }
    }

    return combined;
  }

  void _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập tên nhóm trò chuyện');
      return;
    }

    // Đảm bảo không chứa chính mình trong danh sách thành viên được chọn
    if (_currentUserId != null) {
      _selectedMemberIds.remove(_currentUserId);
    }

    if (_selectedMemberIds.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng chọn ít nhất 1 bạn bè hoặc thành viên khác để tạo nhóm');
      return;
    }

    // 1. Kiểm tra trạng thái token / đăng nhập
    final isLoggedIn = await _authService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      // Chuyển sang màn hình đăng nhập, khi đăng nhập xong thì quay lại đúng trang tạo nhóm
      final loginSuccess = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );

      if (loginSuccess == true || await _authService.isLoggedIn()) {
        await _loadCurrentUser();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Bạn cần đăng nhập để tạo nhóm trò chuyện';
            _isCreating = false;
          });
        }
        return;
      }
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onCreateGroup(name, _selectedMemberIds.toList());
      if (mounted) {
        if (!success) {
          setState(() {
            _errorMessage = 'Không thể tạo nhóm. Vui lòng thử lại sau.';
            _isCreating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tạo nhóm. Vui lòng thử lại sau.';
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _displayMembers;
    final selectedMembers = _selectedMemberIds
        .where((id) => id != _currentUserId)
        .map((id) {
      return _userCache[id] ?? FriendUser(id: id, fullName: 'Người dùng #$id');
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE4E6EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.groups_rounded, color: Color(0xFF0084FF), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Tạo nhóm trò chuyện mới',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF050505),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF65676B)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Body Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Name
                  const Text(
                    'TÊN NHÓM *',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF65676B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'VD: Hội Phượt Miền Tây, Team Đà Lạt...',
                      hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Chips
                  if (selectedMembers.isNotEmpty) ...[
                    Text(
                      'ĐÃ CHỌN (${selectedMembers.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0084FF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedMembers.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final f = selectedMembers[index];
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
                    const SizedBox(height: 16),
                  ],

                  // Member Search Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CHỌN THÀNH VIÊN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF65676B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (_isSearching)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0084FF)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên hoặc email trong hệ thống...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Members list
                  if (members.isEmpty && !_isSearching)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.person_search_rounded, size: 36, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.trim().isNotEmpty
                                  ? 'Không tìm thấy người dùng nào khớp với "${_searchController.text.trim()}"'
                                  : 'Chưa có thành viên nào trong danh sách',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF65676B), fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final isSelected = _selectedMemberIds.contains(member.id);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedMemberIds.remove(member.id);
                              } else {
                                _selectedMemberIds.add(member.id);
                                _userCache[member.id] = member;
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                // Avatar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: member.avatarUrl.isNotEmpty
                                      ? buildAppImage(member.avatarUrl, width: 40, height: 40, fit: BoxFit.cover)
                                      : Container(
                                          width: 40,
                                          height: 40,
                                          color: const Color(0xFFEBF5FF),
                                          child: Center(
                                            child: Text(
                                              (member.fullName.isNotEmpty ? member.fullName[0] : 'U').toUpperCase(),
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
                                        member.fullName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF050505),
                                        ),
                                      ),
                                      if (member.email.isNotEmpty || member.bio.isNotEmpty)
                                        Text(
                                          member.email.isNotEmpty ? member.email : member.bio,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF65676B)),
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

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
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
                  ],
                ],
              ),
            ),
          ),

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
                onPressed: _isCreating ? null : _handleCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Tạo nhóm ngay',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet chọn người dùng từ database để mở cuộc trò chuyện 1-1
class _NewChatWithFriendModalSheet extends StatefulWidget {
  final List<FriendUser> friends;
  final ValueChanged<FriendUser> onSelectFriend;

  const _NewChatWithFriendModalSheet({
    required this.friends,
    required this.onSelectFriend,
  });

  @override
  State<_NewChatWithFriendModalSheet> createState() => _NewChatWithFriendModalSheetState();
}

class _NewChatWithFriendModalSheetState extends State<_NewChatWithFriendModalSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FriendApiService _friendService = FriendApiService();
  final AuthService _authService = AuthService();
  List<FriendUser> _friendList = [];
  List<FriendUser> _searchResults = [];
  int? _currentUserId;
  String? _currentUserEmail;
  bool _isLoading = false;
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _friendList = List.from(widget.friends);
    _loadCurrentUser();
    if (_friendList.isEmpty) {
      _loadFriendsFromDb();
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCachedUser();
      if (user != null && mounted) {
        setState(() {
          _currentUserId = int.tryParse(user.id);
          _currentUserEmail = user.email.toLowerCase().trim();
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

  Future<void> _loadFriendsFromDb() async {
    setState(() => _isLoading = true);
    try {
      final res = await _friendService.getFriends();
      if (mounted && res.success && res.data != null) {
        setState(() {
          _friendList = res.data!.friends;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
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
            _searchResults = (res.success && res.data != null)
                ? res.data!.where((u) => !_isSelf(u)).toList()
                : [];
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FriendUser> get _displayUsers {
    final query = _searchCtrl.text.trim().toLowerCase();
    final nonSelfFriends = _friendList.where((f) => !_isSelf(f)).toList();
    if (query.isEmpty) return nonSelfFriends;

    final localMatches = nonSelfFriends.where((f) {
      return f.fullName.toLowerCase().contains(query) ||
          f.email.toLowerCase().contains(query);
    }).toList();

    final seenIds = localMatches.map((e) => e.id).toSet();
    final combined = List<FriendUser>.from(localMatches);

    for (final u in _searchResults) {
      if (!_isSelf(u) && !seenIds.contains(u.id)) {
        seenIds.add(u.id);
        combined.add(u);
      }
    }

    return combined;
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _displayUsers;
    final query = _searchCtrl.text.trim();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
                const Expanded(
                  child: Text(
                    'Tin nhắn mới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
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

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: messengerBgGray,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc email người dùng...',
                  hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Users List from database
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: messengerBlue, strokeWidth: 2.5),
                  )
                : displayList.isEmpty && !_isSearching
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_search_rounded, size: 40, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              query.isNotEmpty
                                  ? 'Không tìm thấy người dùng nào khớp với "$query"'
                                  : 'Chưa có người dùng nào trong danh sách',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: displayList.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final friend = displayList[index];
                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelectFriend(friend);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: ClipOval(
                                      child: buildAppImage(
                                        friend.avatarUrl,
                                        width: 46,
                                        height: 46,
                                        fit: BoxFit.cover,
                                        errorWidget: Container(
                                          color: messengerBlue,
                                          child: Center(
                                            child: Text(
                                              (friend.fullName.isNotEmpty ? friend.fullName[0] : 'U').toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
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
                                          friend.fullName,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (friend.email.isNotEmpty || friend.bio.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            friend.email.isNotEmpty ? friend.email : friend.bio,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Chat icon action
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: messengerBlueLight,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_rounded,
                                      size: 16,
                                      color: messengerBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

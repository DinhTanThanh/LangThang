import 'package:flutter/material.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/services/friend_api_service.dart';
import '../../../data/services/chat_api_service.dart';
import '../../screens/chat/chat_room_screen.dart';
import 'unfriend_confirm_dialog.dart';

class FriendsSectionWidget extends StatefulWidget {
  final VoidCallback? onFriendsCountChanged;

  const FriendsSectionWidget({
    super.key,
    this.onFriendsCountChanged,
  });

  @override
  State<FriendsSectionWidget> createState() => _FriendsSectionWidgetState();
}

class _FriendsSectionWidgetState extends State<FriendsSectionWidget> {
  final FriendApiService _friendService = FriendApiService();

  List<FriendUser> _allFriends = [];
  bool _isLoading = true;

  // 'accepted', 'suggestions', 'incoming', 'outgoing', 'blocked'
  String _activeTab = 'accepted';

  final TextEditingController _filterSearchController = TextEditingController();
  final TextEditingController _suggestionSearchController = TextEditingController();

  List<FriendUser> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  @override
  void dispose() {
    _filterSearchController.dispose();
    _suggestionSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFriends() async {
    setState(() => _isLoading = true);
    final res = await _friendService.getFriends();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _allFriends = [
            ...res.data!.friends,
            ...res.data!.pendingRequestsReceived,
            ...res.data!.pendingRequestsSent,
            ...res.data!.blockedUsers,
          ];
        }
      });
    }
  }

  List<FriendUser> get _acceptedFriends =>
      _allFriends.where((f) => f.status == FriendshipStatus.accepted).toList();

  List<FriendUser> get _incomingRequests =>
      _allFriends.where((f) => f.status == FriendshipStatus.pendingIncoming).toList();

  List<FriendUser> get _outgoingRequests =>
      _allFriends.where((f) => f.status == FriendshipStatus.pendingOutgoing).toList();

  List<FriendUser> get _blockedUsers =>
      _allFriends.where((f) => f.status == FriendshipStatus.blocked).toList();

  List<FriendUser> _filterList(List<FriendUser> source) {
    final q = _filterSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((u) {
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();
  }

  void _showToast(String message) {
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

  Future<void> _handleSearchUsers() async {
    final query = _suggestionSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final res = await _friendService.searchUsers(query);
    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchResults = res.success && res.data != null ? res.data! : [];
      });
    }
  }

  Future<void> _handleAccept(FriendUser friend) async {
    await _friendService.respondFriendRequest(friend.id, 'accept');
    setState(() {
      _allFriends = _allFriends.map((f) {
        if (f.id == friend.id) {
          return f.copyWith(
            status: FriendshipStatus.accepted,
            connectedDate: 'Vừa kết bạn',
          );
        }
        return f;
      }).toList();

      _searchResults = _searchResults.map((f) {
        if (f.id == friend.id) {
          return f.copyWith(
            status: FriendshipStatus.accepted,
            connectedDate: 'Vừa kết bạn',
          );
        }
        return f;
      }).toList();
    });
    _showToast('Đã kết bạn với ${friend.fullName}.');
    widget.onFriendsCountChanged?.call();
  }

  Future<void> _handleDecline(FriendUser friend) async {
    await _friendService.respondFriendRequest(friend.id, 'reject');
    setState(() {
      _allFriends.removeWhere((f) => f.id == friend.id);
      _searchResults = _searchResults.map((f) {
        if (f.id == friend.id) {
          return f.copyWith(status: FriendshipStatus.suggestion);
        }
        return f;
      }).toList();
    });
    _showToast('Đã gỡ lời mời từ ${friend.fullName}.');
    widget.onFriendsCountChanged?.call();
  }

  Future<void> _handleSendRequest(FriendUser friend) async {
    await _friendService.sendFriendRequest(friend.id);
    setState(() {
      final exists = _allFriends.any((f) => f.id == friend.id);
      if (exists) {
        _allFriends = _allFriends.map((f) {
          if (f.id == friend.id) {
            return f.copyWith(status: FriendshipStatus.pendingOutgoing);
          }
          return f;
        }).toList();
      } else {
        _allFriends.add(friend.copyWith(status: FriendshipStatus.pendingOutgoing));
      }

      _searchResults = _searchResults.map((f) {
        if (f.id == friend.id) {
          return f.copyWith(status: FriendshipStatus.pendingOutgoing);
        }
        return f;
      }).toList();
    });
    _showToast('Đã gửi lời mời kết bạn đến ${friend.fullName}.');
  }

  Future<void> _handleCancelOutgoing(FriendUser friend) async {
    await _friendService.unfriend(friend.id);
    setState(() {
      _allFriends.removeWhere((f) => f.id == friend.id);
      _searchResults = _searchResults.map((f) {
        if (f.id == friend.id) {
          return f.copyWith(status: FriendshipStatus.suggestion);
        }
        return f;
      }).toList();
    });
    _showToast('Đã hủy lời mời gửi đến ${friend.fullName}.');
  }

  void _promptUnfriend(FriendUser friend) {
    showDialog(
      context: context,
      builder: (context) => UnfriendConfirmDialog(
        user: friend,
        onConfirm: () async {
          await _friendService.unfriend(friend.id);
          setState(() {
            _allFriends.removeWhere((f) => f.id == friend.id);
            _searchResults = _searchResults.map((f) {
              if (f.id == friend.id) {
                return f.copyWith(status: FriendshipStatus.suggestion);
              }
              return f;
            }).toList();
          });
          _showToast('Đã hủy kết bạn với ${friend.fullName}.');
          widget.onFriendsCountChanged?.call();
        },
      ),
    );
  }

  void _handleUnblock(FriendUser friend) {
    setState(() {
      _allFriends.removeWhere((f) => f.id == friend.id);
      _searchResults = _searchResults.map((f) {
        if (f.id == friend.id) {
          return f.copyWith(status: FriendshipStatus.suggestion);
        }
        return f;
      }).toList();
    });
    _showToast('Đã bỏ chặn ${friend.fullName}.');
  }

  void _handleStartChat(FriendUser friend) async {
    final res = await ChatApiService().getOrCreateDirectRoom(
      friend.id,
      targetUserName: friend.fullName,
      targetUserAvatar: friend.avatarUrl,
    );
    if (!mounted) return;
    if (res.success && res.data != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            roomId: res.data!,
            roomName: friend.fullName,
            roomAvatar: friend.avatarUrl,
            otherUserId: friend.id,
          ),
        ),
      );
    } else {
      _showToast('Không thể mở phòng chat lúc này');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'key': 'accepted', 'label': 'Tất cả bạn bè', 'count': _acceptedFriends.length, 'icon': Icons.people_alt_rounded},
      {'key': 'suggestions', 'label': 'Khám phá bạn mới', 'count': 0, 'icon': Icons.person_search_rounded},
      {'key': 'incoming', 'label': 'Lời mời kết bạn', 'count': _incomingRequests.length, 'icon': Icons.mark_email_unread_rounded},
      {'key': 'outgoing', 'label': 'Đã gửi', 'count': _outgoingRequests.length, 'icon': Icons.send_rounded},
      {'key': 'blocked', 'label': 'Đã chặn', 'count': _blockedUsers.length, 'icon': Icons.block_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Header Section =====
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people_rounded, color: Color(0xFF047857), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quản lý bạn bè',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${_acceptedFriends.length} bạn bè • Kết nối đam mê xê dịch',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF047857), size: 20),
                    tooltip: 'Làm mới',
                    onPressed: _fetchFriends,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Horizontal Tabs Scroll
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: tabs.map((tab) {
                    final key = tab['key'] as String;
                    final isSelected = _activeTab == key;
                    final count = tab['count'] as int;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _activeTab = key;
                            _filterSearchController.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF047857) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab['icon'] as IconData,
                                size: 14,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tab['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
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

              // Filter Search Bar (for tabs other than 'suggestions')
              if (_activeTab != 'suggestions') ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _filterSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tên hoặc email...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF047857), size: 18),
                      suffixIcon: _filterSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _filterSearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ===== Main Content Area =====
        if (_isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF047857)),
                ),
                SizedBox(height: 12),
                Text(
                  'Đang tải dữ liệu bạn bè...',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          _buildActiveTabContent(),
      ],
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 'accepted':
        final list = _filterList(_acceptedFriends);
        if (list.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Chưa có bạn bè nào',
            subtitle: 'Hãy sang tab "Khám phá bạn mới" để tìm kiếm và kết nối cùng cộng đồng du lịch!',
          );
        }
        return _buildUserGrid(list, isAcceptedTab: true);

      case 'suggestions':
        return _buildSuggestionsTab();

      case 'incoming':
        final list = _filterList(_incomingRequests);
        if (list.isEmpty) {
          return _buildEmptyState(
            icon: Icons.mark_email_read_rounded,
            title: 'Không có lời mời kết bạn nào mới',
            subtitle: 'Khi có thành viên gửi lời mời kết bạn, danh sách sẽ hiển thị tại đây.',
          );
        }
        return _buildUserGrid(list, isIncomingTab: true);

      case 'outgoing':
        final list = _filterList(_outgoingRequests);
        if (list.isEmpty) {
          return _buildEmptyState(
            icon: Icons.outbox_rounded,
            title: 'Chưa gửi lời mời kết bạn nào',
            subtitle: 'Tìm kiếm những người bạn đồng hành và gửi lời mời kết bạn ngay nhé!',
          );
        }
        return _buildUserGrid(list, isOutgoingTab: true);

      case 'blocked':
        final list = _filterList(_blockedUsers);
        if (list.isEmpty) {
          return _buildEmptyState(
            icon: Icons.shield_outlined,
            title: 'Danh sách chặn trống',
            subtitle: 'Bạn chưa chặn bất kỳ người dùng nào.',
          );
        }
        return _buildBlockedList(list);

      default:
        return const SizedBox();
    }
  }

  // ===== Suggestions Tab (Search & Discovery) =====
  Widget _buildSuggestionsTab() {
    return Column(
      children: [
        // Search Form Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tìm kiếm bạn bè mới',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Nhập tên người dùng hoặc ID (ví dụ: #10 hoặc 10) để gửi lời mời kết bạn:',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: _suggestionSearchController,
                        onSubmitted: (_) => _handleSearchUsers(),
                        decoration: InputDecoration(
                          hintText: 'Nhập tên hoặc ID người dùng...',
                          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF047857), size: 20),
                          suffixIcon: _suggestionSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    _suggestionSearchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSearching ? null : _handleSearchUsers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            children: [
                              Icon(Icons.search_rounded, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Tìm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (_isSearching)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF047857)),
            ),
          )
        else if (_hasSearched && _searchResults.isEmpty)
          _buildEmptyState(
            icon: Icons.person_off_rounded,
            title: 'Không tìm thấy kết quả',
            subtitle: 'Không có người dùng nào khớp với từ khóa "${_suggestionSearchController.text.trim()}".',
          )
        else if (_searchResults.isNotEmpty)
          _buildUserGrid(_searchResults, isSuggestionTab: true),
      ],
    );
  }

  // ===== User Grid (2 Column Cards) =====
  Widget _buildUserGrid(
    List<FriendUser> list, {
    bool isAcceptedTab = false,
    bool isIncomingTab = false,
    bool isOutgoingTab = false,
    bool isSuggestionTab = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.74,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final user = list[index];
            return _buildFriendCard(
              user,
              isAcceptedTab: isAcceptedTab,
              isIncomingTab: isIncomingTab,
              isOutgoingTab: isOutgoingTab,
              isSuggestionTab: isSuggestionTab,
            );
          },
        );
      },
    );
  }

  Widget _buildFriendCard(
    FriendUser user, {
    bool isAcceptedTab = false,
    bool isIncomingTab = false,
    bool isOutgoingTab = false,
    bool isSuggestionTab = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cover Header & Centered Avatar
          SizedBox(
            height: 90,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: user.coverUrl.isNotEmpty
                      ? Image.network(
                          user.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF064E3B), Color(0xFF047857)],
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF064E3B), Color(0xFF047857)],
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: -24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: user.avatarUrl.isNotEmpty
                            ? Image.network(
                                user.avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(user),
                              )
                            : _buildAvatarFallback(user),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // User Information
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
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
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '"${user.bio}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ],
                if (user.mutualFriendsCount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 11, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Text(
                        '${user.mutualFriendsCount} bạn chung',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Spacer(),

          // Card Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: _buildCardButtons(
              user,
              isAcceptedTab: isAcceptedTab,
              isIncomingTab: isIncomingTab,
              isOutgoingTab: isOutgoingTab,
              isSuggestionTab: isSuggestionTab,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(FriendUser user) {
    return Container(
      color: const Color(0xFF047857),
      child: Center(
        child: Text(
          (user.fullName.isNotEmpty ? user.fullName[0] : 'U').toUpperCase(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCardButtons(
    FriendUser user, {
    bool isAcceptedTab = false,
    bool isIncomingTab = false,
    bool isOutgoingTab = false,
    bool isSuggestionTab = false,
  }) {
    if (isAcceptedTab || user.status == FriendshipStatus.accepted) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _handleStartChat(user),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF047857)),
              label: const Text('Nhắn tin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFECFDF5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _promptUnfriend(user),
            icon: const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 16),
            tooltip: 'Hủy kết bạn',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      );
    }

    if (isIncomingTab || user.status == FriendshipStatus.pendingIncoming) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleAccept(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Xác nhận', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _handleDecline(user),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Xóa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            ),
          ),
        ],
      );
    }

    if (isOutgoingTab || user.status == FriendshipStatus.pendingOutgoing) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _handleCancelOutgoing(user),
          icon: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF64748B)),
          label: const Text('Hủy lời mời', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFF8FAFC),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    if (user.status == FriendshipStatus.self) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Tài khoản của bạn',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
      );
    }

    // Default Suggestion Button
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleSendRequest(user),
        icon: const Icon(Icons.person_add_rounded, size: 13, color: Colors.white),
        label: const Text('Thêm bạn bè', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF047857),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ===== Blocked Users List =====
  Widget _buildBlockedList(List<FriendUser> list) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = list[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                  child: user.avatarUrl.isNotEmpty
                      ? Image.network(user.avatarUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(user))
                      : _buildAvatarFallback(user),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.lineThrough,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _handleUnblock(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Bỏ chặn', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 28, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }
}

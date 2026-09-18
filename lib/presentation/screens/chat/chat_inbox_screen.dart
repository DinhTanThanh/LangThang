import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/services/chat_api_service.dart';
import 'chat_room_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final ChatApiService _chatService = ChatApiService();
  final TextEditingController _searchController = TextEditingController();

  List<InboxItem> _inboxList = [];
  bool _isLoading = true;
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
    if (!silent) setState(() => _isLoading = true);
    final res = await _chatService.getInbox();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _inboxList = res.data!;
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
      list = list.where((i) => i.name.toLowerCase().contains(q) || (i.lastMessage?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
    if (diff.inHours < 24 && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 2) return 'Hôm qua';
    return '${dt.day}/${dt.month}';
  }

  void _openCreateGroupDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tạo nhóm chat mới', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đặt tên cho nhóm hội thoại của bạn:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'VD: Hội Phượt Tây Bắc, Team Đà Lạt...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
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
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogContext);
                final res = await _chatService.createGroupRoom(name, [1, 2, 3]);
                if (res.success && res.data != null) {
                  _loadInbox();
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
                }
              }
            },
            child: const Text('Tạo nhóm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredList;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Tin nhắn',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined, color: AppColors.primary, size: 24),
            tooltip: 'Tạo nhóm mới',
            onPressed: _openCreateGroupDialog,
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm tin nhắn, bạn bè...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Tabs
                Row(
                  children: [
                    _buildFilterChip('all', 'Tất cả (${_inboxList.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('unread', 'Chưa đọc (${_inboxList.where((i) => i.unreadCount > 0).length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('group', 'Nhóm (${_inboxList.where((i) => i.isGroup).length})'),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Inbox List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined, size: 54, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'Không có cuộc trò chuyện nào',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Hãy kết nối với bạn bè để bắt đầu trò chuyện.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => _loadInbox(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, indent: 76, endIndent: 16, color: Color(0xFFF1F5F9)),
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
                                color: hasUnread ? AppColors.primary.withValues(alpha: 0.03) : Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Avatar with Online dot
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundImage: item.avatarUrl != null ? NetworkImage(item.avatarUrl!) : null,
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                          child: item.avatarUrl == null
                                              ? Icon(item.isGroup ? Icons.groups_rounded : Icons.person, color: AppColors.primary)
                                              : null,
                                        ),
                                        if (item.isOnline)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 13,
                                              height: 13,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2.5),
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
                                                    fontSize: 14.5,
                                                    fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _formatTime(item.lastMessageAt),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                                                  color: hasUnread ? AppColors.primary : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.lastMessage ?? 'Bắt đầu cuộc trò chuyện...',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                                    color: hasUnread ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              if (hasUnread) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    '${item.unreadCount}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
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

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

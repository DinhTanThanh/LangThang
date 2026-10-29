import 'package:flutter/material.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/services/notification_api_service.dart';
import '../../../data/services/place_api_service.dart';
import '../../screens/destinations/place_detail_screen.dart';

class HeaderNotificationDropdown extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(int tabIndex)? onNavigateTab;

  const HeaderNotificationDropdown({
    super.key,
    required this.onClose,
    this.onNavigateTab,
  });

  /// Hiển thị dropdown thông báo neo (anchored) ngay dưới icon Chuông thông báo
  static Future<void> show(
    BuildContext context, {
    required GlobalKey anchorKey,
    void Function(int tabIndex)? onNavigateTab,
    VoidCallback? onDismiss,
  }) async {
    final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    Offset targetOffset = const Offset(0, 70);
    if (renderBox != null) {
      final pos = renderBox.localToGlobal(Offset.zero);
      targetOffset = Offset(pos.dx + renderBox.size.width, pos.dy + renderBox.size.height + 8);
    }

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.15),
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (ctx, anim, secAnim) {
          final size = MediaQuery.of(ctx).size;
          final double dropdownWidth = size.width < 430 ? size.width - 24 : 400;
          final double rightPos = 12;
          final double topPos = targetOffset.dy.clamp(60.0, size.height - 300);

          return FadeTransition(
            opacity: anim,
            child: Stack(
              children: [
                // Backdrop dismiss tap
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),

                // Floating Dropdown Card
                Positioned(
                  top: topPos,
                  right: rightPos,
                  child: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: dropdownWidth,
                        maxHeight: size.height - topPos - 20,
                      ),
                      child: HeaderNotificationDropdown(
                        onClose: () => Navigator.of(ctx).pop(),
                        onNavigateTab: onNavigateTab,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    onDismiss?.call();
  }

  @override
  State<HeaderNotificationDropdown> createState() => _HeaderNotificationDropdownState();
}

class _HeaderNotificationDropdownState extends State<HeaderNotificationDropdown> {
  final NotificationApiService _apiService = NotificationApiService();

  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  bool _unreadFilter = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _unreadCount = _apiService.unreadCount;
    _fetchNotifications(reset: true);
  }

  Future<void> _fetchNotifications({bool reset = false, bool? unreadOnly}) async {
    final targetUnreadOnly = unreadOnly ?? _unreadFilter;
    final targetPage = reset ? 1 : _page;

    if (reset) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    final res = await _apiService.getNotifications(
      page: targetPage,
      pageSize: 20,
      unreadOnly: targetUnreadOnly,
    );

    if (!mounted) return;

    if (res.success && res.data != null) {
      final paged = res.data!;
      setState(() {
        if (reset) {
          _notifications = paged.items;
          _page = 1;
        } else {
          final existingIds = _notifications.map((n) => n.id).toSet();
          final newItems = paged.items.where((n) => !existingIds.contains(n.id)).toList();
          _notifications.addAll(newItems);
        }
        _hasMore = paged.hasNextPage;
        _unreadCount = paged.unreadCount;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _page++;
    await _fetchNotifications(reset: false);
  }

  Future<void> _onFilterChanged(bool unreadOnly) async {
    if (_unreadFilter == unreadOnly) return;
    setState(() {
      _unreadFilter = unreadOnly;
      _page = 1;
    });
    await _fetchNotifications(reset: true, unreadOnly: unreadOnly);
  }

  Future<void> _handleMarkAsRead(NotificationItem item) async {
    if (item.isRead) return;

    setState(() {
      _notifications = _notifications.map((n) {
        if (n.id == item.id) {
          return n.copyWith(isRead: true, readAt: DateTime.now());
        }
        return n;
      }).toList();
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
    });

    await _apiService.markAsRead(item.id);
  }

  Future<void> _handleMarkAllAsRead() async {
    if (_unreadCount <= 0) return;

    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true, readAt: DateTime.now())).toList();
      _unreadCount = 0;
    });

    await _apiService.markAllAsRead();
  }

  Future<void> _handleDeleteNotification(NotificationItem item) async {
    setState(() {
      _notifications.removeWhere((n) => n.id == item.id);
      if (!item.isRead) {
        _unreadCount = (_unreadCount - 1).clamp(0, 9999);
      }
    });

    await _apiService.deleteNotification(item.id);
  }

  Future<void> _navigateToPlace(int placeId) async {
    final res = await PlaceApiService().getPlaceDetail(placeId);
    if (res.data != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaceDetailScreen(place: res.data!),
        ),
      );
    }
  }

  void _handleClickItem(NotificationItem item) {
    if (!item.isRead) {
      _handleMarkAsRead(item);
    }

    widget.onClose();

    // Điều hướng theo targetUrl hoặc entityType
    if (item.targetUrl != null && item.targetUrl!.isNotEmpty) {
      final url = item.targetUrl!;
      if (url.contains('/places/')) {
        final segments = url.split('/');
        final lastPart = segments.last.split('#').first;
        final placeId = int.tryParse(lastPart);
        if (placeId != null && placeId > 0) {
          _navigateToPlace(placeId);
          return;
        }
      } else if (url.contains('/destinations')) {
        widget.onNavigateTab?.call(1);
        return;
      } else if (url.contains('/trips')) {
        widget.onNavigateTab?.call(3);
        return;
      } else if (url.contains('/profile')) {
        widget.onNavigateTab?.call(5);
        return;
      }
    }

    if (item.entityType == 'PLACE' && item.entityId != null && item.entityId! > 0) {
      _navigateToPlace(item.entityId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header (Title, Unread badge, Mark all as read button)
            _buildHeader(),

            // 2. Filter tabs ("Tất cả", "Chưa đọc")
            _buildFilterTabs(),

            // 3. Notification List
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 440),
                child: _buildNotificationList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Thông báo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              if (_unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                  ),
                  child: Text(
                    '$_unreadCount mới',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_unreadCount > 0)
            InkWell(
              onTap: _handleMarkAllAsRead,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF047857)),
                    SizedBox(width: 4),
                    Text(
                      'Đọc tất cả',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
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

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Tab "Tất cả"
          InkWell(
            onTap: () => _onFilterChanged(false),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: !_unreadFilter ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: !_unreadFilter
                    ? Border.all(color: const Color(0xFFE2E8F0), width: 1)
                    : null,
                boxShadow: !_unreadFilter
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Tất cả',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: !_unreadFilter ? FontWeight.w700 : FontWeight.w600,
                  color: !_unreadFilter ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Tab "Chưa đọc"
          InkWell(
            onTap: () => _onFilterChanged(true),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _unreadFilter ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: _unreadFilter
                    ? Border.all(color: const Color(0xFFE2E8F0), width: 1)
                    : null,
                boxShadow: _unreadFilter
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Chưa đọc',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _unreadFilter ? FontWeight.w700 : FontWeight.w600,
                      color: _unreadFilter ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _buildNotificationList() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF059669),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Đang tải thông báo...',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 24,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _unreadFilter ? 'Không có thông báo chưa đọc' : 'Chưa có thông báo nào',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _unreadFilter
                    ? 'Bạn đã xem hết các thông báo mới.'
                    : 'Các hoạt động và thông báo mới sẽ xuất hiện tại đây.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _notifications.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFF1F5F9),
      ),
      itemBuilder: (context, index) {
        if (index == _notifications.length) {
          return _buildLoadMoreButton();
        }
        final item = _notifications[index];
        return _buildNotificationItem(item);
      },
    );
  }

  Widget _buildNotificationItem(NotificationItem item) {
    final meta = item.typeMeta;
    final isUnread = !item.isRead;

    return InkWell(
      onTap: () => _handleClickItem(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: isUnread ? const Color(0xFFECFDF5).withValues(alpha: 0.5) : Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Avatar with type icon badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage: (item.actorAvatarUrl != null && item.actorAvatarUrl!.isNotEmpty)
                      ? NetworkImage(item.actorAvatarUrl!)
                      : null,
                  child: (item.actorAvatarUrl == null || item.actorAvatarUrl!.isEmpty)
                      ? Container(
                          decoration: BoxDecoration(
                            color: meta.bg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(meta.icon, size: 20, color: meta.color),
                        )
                      : null,
                ),

                // Corner type icon badge
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: meta.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(meta.icon, size: 9, color: meta.color),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Middle: Title, Content, Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isUnread ? const Color(0xFF0F172A) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                      color: isUnread ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.timeAgoFormatted,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Unread indicator & item actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4, right: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF94A3B8)),
                  tooltip: 'Tùy chọn',
                  onSelected: (val) {
                    if (val == 'read') {
                      _handleMarkAsRead(item);
                    } else if (val == 'delete') {
                      _handleDeleteNotification(item);
                    }
                  },
                  itemBuilder: (context) => [
                    if (isUnread)
                      const PopupMenuItem(
                        value: 'read',
                        height: 34,
                        child: Row(
                          children: [
                            Icon(Icons.check_rounded, size: 15, color: Color(0xFF047857)),
                            SizedBox(width: 8),
                            Text('Đã đọc', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      height: 34,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFE11D48)),
                          SizedBox(width: 8),
                          Text('Xóa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE11D48))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: InkWell(
        onTap: _loadMore,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: _isLoadingMore
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF047857)),
                  )
                : const Text(
                    'Xem thông báo cũ hơn',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/friend_api_service.dart';
import '../../../data/services/itinerary_api_service.dart';
import '../../screens/auth/login_screen.dart';

class ItineraryMembersSheet extends StatefulWidget {
  final int? tripId;
  final String tripTitle;
  final List<TripMemberModel> members;
  final String currentUserRole;
  final bool isLocked;
  final String? tripLink;
  final ValueChanged<List<TripMemberModel>>? onMembersChanged;
  final void Function(String email, String role)? onInviteMember;
  final void Function(int memberId)? onRemoveMember;

  const ItineraryMembersSheet({
    super.key,
    this.tripId,
    this.tripTitle = 'Chuyến đi của tôi',
    required this.members,
    this.currentUserRole = 'Owner',
    this.isLocked = false,
    this.tripLink,
    this.onMembersChanged,
    this.onInviteMember,
    this.onRemoveMember,
  });

  static void show(
    BuildContext context, {
    int? tripId,
    String tripTitle = 'Chuyến đi của tôi',
    required List<TripMemberModel> members,
    String currentUserRole = 'Owner',
    bool isLocked = false,
    String? tripLink,
    ValueChanged<List<TripMemberModel>>? onMembersChanged,
    void Function(String email, String role)? onInviteMember,
    void Function(int memberId)? onRemoveMember,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => ItineraryMembersSheet(
        tripId: tripId,
        tripTitle: tripTitle,
        members: members,
        currentUserRole: currentUserRole,
        isLocked: isLocked,
        tripLink: tripLink,
        onMembersChanged: onMembersChanged,
        onInviteMember: onInviteMember,
        onRemoveMember: onRemoveMember,
      ),
    );
  }

  @override
  State<ItineraryMembersSheet> createState() => _ItineraryMembersSheetState();
}

class _ItineraryMembersSheetState extends State<ItineraryMembersSheet> {
  late List<TripMemberModel> _currentMembers;
  late String _currentUserRole;
  final TextEditingController _searchController = TextEditingController();
  String _inviteRole = 'Viewer'; // 'Viewer' | 'Editor'
  bool _isLoadingFriends = false;
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _debounceTimer;

  // Friends & Search State
  List<FriendUser> _friends = [];
  List<FriendUser> _searchResults = [];

  // Default fallback mock friends if friend API is empty (matching screenshot)
  static final List<FriendUser> _defaultFallbackFriends = [
    FriendUser(id: 101, fullName: 'Trần Hoàng Nam', email: 'nam.tran@gmail.com', avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&h=120&fit=crop'),
    FriendUser(id: 102, fullName: 'Lê Minh Tuấn', email: 'tuan.le@gmail.com', avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=120&h=120&fit=crop'),
    FriendUser(id: 103, fullName: 'thanh', email: 'thanh.dinh@gmail.com', avatarUrl: ''),
    FriendUser(id: 104, fullName: 'Moba Light', email: 'mobalight@gmail.com', avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&h=120&fit=crop'),
    FriendUser(id: 105, fullName: 'Nguyễn Hương Giang', email: 'giang.nguyen@gmail.com', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&h=120&fit=crop'),
  ];

  @override
  void initState() {
    super.initState();
    _currentUserRole = widget.currentUserRole;
    _currentMembers = List.from(widget.members);

    if (_currentMembers.isEmpty) {
      final cachedUser = AuthService().currentUser;
      final myId = cachedUser != null ? (int.tryParse(cachedUser.id) ?? 0) : 0;
      final myName = cachedUser?.fullName.isNotEmpty == true ? cachedUser!.fullName : 'Dương Đức Thắng';
      final myEmail = cachedUser?.email.isNotEmpty == true ? cachedUser!.email : 'thang123@gmail.com';
      _currentMembers.add(
        TripMemberModel(
          id: myId > 0 ? myId : 1,
          name: myName,
          email: myEmail,
          avatar: cachedUser?.avatarUrl,
          role: 'Owner',
        ),
      );
    }
    _loadFriends();
    _checkUserRoleAfterLogin();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool get isOwner => _currentUserRole == 'Owner';
  bool get isEditor => _currentUserRole == 'Editor';
  bool get isViewer => _currentUserRole == 'Viewer';

  Future<void> _checkUserRoleAfterLogin() async {
    final cachedUser = await AuthService().getCachedUser() ?? AuthService().currentUser;
    if (cachedUser != null && _currentMembers.isNotEmpty) {
      final userIdInt = int.tryParse(cachedUser.id) ?? -1;
      final myRecord = _currentMembers.firstWhere(
        (m) => (userIdInt > 0 && m.id > 0 && m.id == userIdInt) ||
               (cachedUser.email.isNotEmpty && m.email.isNotEmpty && m.email.toLowerCase() == cachedUser.email.toLowerCase()),
        orElse: () => TripMemberModel(id: userIdInt, name: cachedUser.fullName, email: cachedUser.email, role: _currentUserRole),
      );
      if (myRecord.id != -1 && mounted) {
        setState(() {
          _currentUserRole = myRecord.role;
        });
      }
    }
  }

  Future<bool> _ensureAuthenticated(String actionName) async {
    final isAuthed = await AuthService().isLoggedIn();
    if (isAuthed) return true;

    if (!mounted) return false;

    final proceedToLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF065F46)),
            SizedBox(width: 8),
            Text('Yêu cầu đăng nhập', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Text(
          'Bạn cần đăng nhập tài khoản để $actionName. Bạn có muốn đăng nhập ngay bây giờ?',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065F46),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (proceedToLogin == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      final refreshedToken = await AuthService().getAccessToken();
      final hasToken = refreshedToken != null && refreshedToken.isNotEmpty;
      if (hasToken) {
        await _loadFriends();
        await _checkUserRoleAfterLogin();
      }
      return hasToken;
    }
    return false;
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final res = await FriendApiService().getFriends();
      if (mounted) {
        final apiFriends = res.data?.friends ?? [];
        setState(() {
          _friends = apiFriends.isNotEmpty ? apiFriends : _defaultFallbackFriends;
          _isLoadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _friends = _defaultFallbackFriends;
          _isLoadingFriends = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final trimmed = query.trim();
      setState(() {
        _searchQuery = trimmed;
      });

      if (trimmed.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);
      try {
        final res = await FriendApiService().searchUsers(trimmed);
        if (mounted) {
          final results = res.data ?? [];
          if (results.isEmpty) {
            final localMatches = _friends.where((f) => f.fullName.toLowerCase().contains(trimmed.toLowerCase()) || f.email.toLowerCase().contains(trimmed.toLowerCase())).toList();
            setState(() {
              _searchResults = localMatches;
              _isSearching = false;
            });
          } else {
            setState(() {
              _searchResults = results;
              _isSearching = false;
            });
          }
        }
      } catch (_) {
        if (mounted) {
          final localMatches = _friends.where((f) => f.fullName.toLowerCase().contains(trimmed.toLowerCase()) || f.email.toLowerCase().contains(trimmed.toLowerCase())).toList();
          setState(() {
            _searchResults = localMatches;
            _isSearching = false;
          });
        }
      }
    });
  }

  bool _isAlreadyMember({int? userId, String? email, String? name}) {
    return _currentMembers.any((m) {
      if (userId != null && userId > 0 && m.id > 0 && m.id == userId) return true;
      if (email != null && email.trim().isNotEmpty && m.email.trim().isNotEmpty && m.email.toLowerCase() == email.trim().toLowerCase()) return true;
      if (name != null && name.trim().isNotEmpty && m.name.trim().toLowerCase() == name.trim().toLowerCase()) return true;
      return false;
    });
  }

  Future<void> _handleAddUser(FriendUser user) async {
    final isAuthed = await _ensureAuthenticated('mời thành viên vào chuyến đi');
    if (!isAuthed || !mounted) return;

    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Bạn đang tham gia với vai trò ${_currentUserRole == 'Editor' ? 'Cùng lên lịch' : 'Thành viên (Chỉ xem)'}. Chỉ Trưởng đoàn mới có quyền mời thành viên mới.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isAlreadyMember(userId: user.id, email: user.email, name: user.fullName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.fullName} đã có trong danh sách thành viên.'),
          backgroundColor: const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final userEmail = user.email.trim().isNotEmpty
        ? user.email.trim()
        : '${user.fullName.toLowerCase().replaceAll(' ', '')}@gmail.com';

    final newMember = TripMemberModel(
      id: user.id > 0 ? user.id : (DateTime.now().millisecondsSinceEpoch % 100000),
      name: user.fullName,
      avatar: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
      email: userEmail,
      role: _inviteRole,
    );

    setState(() {
      _currentMembers.add(newMember);
      _searchController.clear();
      _searchQuery = '';
      _searchResults = [];
    });

    widget.onInviteMember?.call(userEmail, _inviteRole);
    widget.onMembersChanged?.call(_currentMembers);

    final roleName = _inviteRole == 'Editor' ? 'Cùng lên lịch' : 'Thành viên (Chỉ xem)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Đã thêm ${user.fullName} ($roleName) vào chuyến đi!')),
          ],
        ),
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    if (widget.tripId != null && widget.tripId! > 0) {
      try {
        ItineraryApiService().inviteMember(
          widget.tripId!,
          email: userEmail,
          role: _inviteRole,
        );
      } catch (_) {}
    }
  }

  void _handleChangeMemberRole(TripMemberModel member, String newRole) {
    if (!isOwner) return;
    if (member.role == 'Owner') return;

    final updated = _currentMembers.map((m) {
      if (m.id == member.id) {
        return m.copyWith(role: newRole);
      }
      return m;
    }).toList();

    setState(() {
      _currentMembers = updated;
    });

    widget.onMembersChanged?.call(_currentMembers);

    final roleText = newRole == 'Editor' ? 'Cùng lên lịch (Có quyền thêm, sửa, xóa điểm dừng)' : 'Thành viên (Chỉ xem và theo dõi lịch trình)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã đổi vai trò của "${member.name}" thành $roleText'),
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleRemoveMember(TripMemberModel member) {
    if (!isOwner) return;
    if (member.role == 'Owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa Trưởng đoàn (chủ chuyến đi).'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Xác nhận xóa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${member.name}" khỏi chuyến đi này?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.tripId != null && widget.tripId! > 0) {
                ItineraryApiService().removeMember(widget.tripId!, member.id);
              }

              setState(() {
                _currentMembers.removeWhere((m) => m.id == member.id);
              });
              widget.onRemoveMember?.call(member.id);
              widget.onMembersChanged?.call(_currentMembers);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã xóa ${member.name} khỏi chuyến đi.'),
                  backgroundColor: const Color(0xFF334155),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final displayTripTitle = widget.tripTitle.isNotEmpty ? widget.tripTitle : 'Chuyến đi của tôi';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Modal Header (matching Screenshot: "Thành viên - [Chuyến đi] ...")
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5), // emerald-50
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_add_outlined,
                      color: Color(0xFF059669), // emerald-600
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Thành viên - [Chuyến đi] $displayTripTitle',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Content Body
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Notice Banner
                    if (widget.isLocked) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chế độ Chỉ xem sau khi xuất bản:',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Sau khi xuất bản, chuyến đi sẽ được chia sẻ công khai và khóa ở chế độ chỉ xem. Bạn (và các thành viên) sẽ không thể chỉnh sửa điểm dừng, ngày đi hoặc mời thêm thành viên nữa.',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309), height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (!isOwner) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentUserRole == 'Editor'
                                    ? 'Bạn có quyền "Cùng lên lịch" (thêm, sửa, xóa điểm dừng). Chỉ Trưởng đoàn mới có quyền mời thành viên và công bố chuyến đi.'
                                    : 'Bạn có quyền "Thành viên" (chỉ xem lịch trình, không chỉnh sửa). Chỉ Trưởng đoàn mới có quyền mời thêm thành viên.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Top Form Box matching Screenshot
                    if (isOwner && !widget.isLocked) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Label: Chọn bạn bè tham gia *
                            Row(
                              children: const [
                                Text(
                                  'Chọn bạn bè tham gia ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '*',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Search Input Field
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: _onSearchChanged,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                                      decoration: const InputDecoration(
                                        hintText: 'Tìm kiếm bạn bè theo tên...',
                                        hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    InkWell(
                                      onTap: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Helper text: Chỉ có thể mời những người có trong danh sách bạn bè của bạn
                            const Text(
                              'Chỉ có thể mời những người có trong danh sách bạn bè của bạn',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Quick Friend Pills Row (matching Screenshot: + 👤 Trần Hoàng Nam, + 👤 Lê Minh Tuấn...)
                            if (_searchQuery.isEmpty) ...[
                              if (_isLoadingFriends)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                                    ),
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _friends.map((friend) {
                                  final isMember = _isAlreadyMember(userId: friend.id, email: friend.email, name: friend.fullName);

                                  return InkWell(
                                    onTap: isMember ? null : () => _handleAddUser(friend),
                                    borderRadius: BorderRadius.circular(20),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isMember ? const Color(0xFFF1F5F9) : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isMember ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!isMember) ...[
                                            const Text(
                                              '+ ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                          if (friend.avatarUrl.isNotEmpty) ...[
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: Image.network(friend.avatarUrl, fit: BoxFit.cover),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                          ] else ...[
                                            const Icon(Icons.person_rounded, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 3),
                                          ],
                                          Text(
                                            friend.fullName,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: isMember ? FontWeight.w500 : FontWeight.w600,
                                              color: isMember ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          if (isMember) ...[
                                            const SizedBox(width: 3),
                                            const Icon(Icons.check_rounded, size: 12, color: Color(0xFF059669)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            // Search suggestions dropdown if query is present
                            if (_searchQuery.isNotEmpty) ...[
                              Container(
                                constraints: const BoxConstraints(maxHeight: 180),
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                                          ),
                                        ),
                                      )
                                    : _searchResults.isEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(
                                              'Không tìm thấy bạn bè phù hợp với "$_searchQuery"',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                            ),
                                          )
                                        : ListView.separated(
                                            shrinkWrap: true,
                                            itemCount: _searchResults.length,
                                            separatorBuilder: (ctx, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                            itemBuilder: (ctx, idx) {
                                              final u = _searchResults[idx];
                                              final isMember = _isAlreadyMember(userId: u.id, email: u.email, name: u.fullName);

                                              return ListTile(
                                                dense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                                leading: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF059669)),
                                                title: Text(u.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                                subtitle: Text(u.email, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                                                trailing: isMember
                                                    ? const Text('Đã tham gia', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)))
                                                    : ElevatedButton(
                                                        onPressed: () => _handleAddUser(u),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF059669),
                                                          foregroundColor: Colors.white,
                                                          elevation: 0,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          minimumSize: Size.zero,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                        ),
                                                        child: const Text('Thêm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                                      ),
                                              );
                                            },
                                          ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // 2. Label: Vai trò trong chuyến đi *
                            Row(
                              children: const [
                                Text(
                                  'Vai trò trong chuyến đi ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '*',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Dropdown matching Screenshot
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _inviteRole,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1E293B),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Viewer',
                                      child: Text(
                                        'Thành viên (Chỉ xem và theo dõi lịch trình)',
                                        style: TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Editor',
                                      child: Text(
                                        'Cùng lên lịch (Có quyền thêm, sửa, xóa điểm dừng)',
                                        style: TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _inviteRole = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Section 3: DANH SÁCH NGƯỜI THAM GIA (N)
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'DANH SÁCH NGƯỜI THAM GIA (${_currentMembers.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Member List Cards matching Screenshot
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentMembers.length,
                      separatorBuilder: (ctx, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final member = _currentMembers[index];
                        final isMe = index == 0 || member.role == 'Owner';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  color: const Color(0xFF0F172A),
                                  child: member.avatar != null && member.avatar!.isNotEmpty
                                      ? Image.network(
                                          member.avatar!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Center(
                                            child: Text(
                                              member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Name & Email
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            member.name,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD1FAE5),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Bạn',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      member.email.isNotEmpty ? member.email : 'thang123@gmail.com',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Role Badge matching screenshot
                              if (member.role == 'Owner') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.shield_outlined, size: 12, color: Color(0xFF065F46)),
                                      SizedBox(width: 3.5),
                                      Text(
                                        'Trưởng đoàn',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF065F46),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (isOwner) ...[
                                // Owner can change role or delete member
                                PopupMenuButton<String>(
                                  onSelected: (val) {
                                    if (val == 'delete') {
                                      _handleRemoveMember(member);
                                    } else {
                                      _handleChangeMemberRole(member, val);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'Editor',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_note_rounded, size: 16, color: member.role == 'Editor' ? const Color(0xFF059669) : const Color(0xFF64748B)),
                                          const SizedBox(width: 8),
                                          Text('Cùng lên lịch', style: TextStyle(fontWeight: member.role == 'Editor' ? FontWeight.bold : FontWeight.normal)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Viewer',
                                      child: Row(
                                        children: [
                                          Icon(Icons.visibility_outlined, size: 16, color: member.role == 'Viewer' ? const Color(0xFF059669) : const Color(0xFF64748B)),
                                          const SizedBox(width: 8),
                                          Text('Thành viên (Chỉ xem)', style: TextStyle(fontWeight: member.role == 'Viewer' ? FontWeight.bold : FontWeight.normal)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                          SizedBox(width: 8),
                                          Text('Xóa khỏi chuyến đi', style: TextStyle(color: Color(0xFFDC2626))),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: member.role == 'Editor' ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: member.role == 'Editor' ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          member.role == 'Editor' ? Icons.edit_note_rounded : Icons.visibility_outlined,
                                          size: 13,
                                          color: member.role == 'Editor' ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                        ),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          member.role == 'Editor' ? 'Cùng lên lịch' : 'Thành viên',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: member.role == 'Editor' ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // Non-owner viewer
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: member.role == 'Editor' ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: member.role == 'Editor' ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        member.role == 'Editor' ? Icons.edit_note_rounded : Icons.visibility_outlined,
                                        size: 13,
                                        color: member.role == 'Editor' ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                      ),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        member.role == 'Editor' ? 'Cùng lên lịch' : 'Thành viên',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: member.role == 'Editor' ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Footer Action: Đóng button matching Screenshot
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE2E8F0),
                      foregroundColor: const Color(0xFF1E293B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

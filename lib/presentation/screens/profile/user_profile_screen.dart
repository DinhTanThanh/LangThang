import 'package:flutter/material.dart';
import '../../../data/models/user_profile_data_models.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../../data/services/friend_api_service.dart';
import '../../../data/services/chat_api_service.dart';
import '../../widgets/profile/share_profile_modal.dart';
import '../auth/login_screen.dart';
import '../chat/chat_room_screen.dart';

enum UserProfileTab {
  reviews,
  activity,
  trips,
  visitLogs,
  blogs,
  proposals,
}

class UserProfileScreen extends StatefulWidget {
  final int userId;
  final String? initialName;
  final String? initialAvatar;
  final String? initialCover;
  final String? initialBio;
  final String? initialRank;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialAvatar,
    this.initialCover,
    this.initialBio,
    this.initialRank,
  });

  static void navigate(
    BuildContext context, {
    dynamic userId,
    String? userName,
    String? userAvatar,
    String? userCover,
    String? userBio,
    String? userRank,
  }) {
    int parsedId = 1;
    if (userId is int) {
      parsedId = userId;
    } else if (userId is String) {
      parsedId = int.tryParse(userId) ?? 1;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: parsedId,
          initialName: userName,
          initialAvatar: userAvatar,
          initialCover: userCover,
          initialBio: userBio,
          initialRank: userRank,
        ),
      ),
    );
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserProfileApiService _profileService = UserProfileApiService();
  final FriendApiService _friendService = FriendApiService();

  PublicUserProfileModel? _profile;
  bool _isLoading = true;
  bool _isLoadingTabs = true;
  UserProfileTab _activeTab = UserProfileTab.reviews;
  bool _isCurrentUser = false;

  // Friend status: 'none', 'pending_sent', 'pending_received', 'accepted'
  String _friendStatus = 'none';
  bool _isSendingFriendAction = false;
  bool _isOpeningChat = false;

  // Real Tab Data Lists
  List<UserReviewItemModel> _reviews = [];
  List<UserCommentItemModel> _activities = [];
  List<UserTripItemModel> _trips = [];
  List<VisitLogItemModel> _visitLogs = [];
  List<UserBlogItemModel> _blogs = [];
  List<ProposalItemModel> _proposals = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final currentUser = await AuthService().getCachedUser();
    final isMe = currentUser != null && currentUser.id == widget.userId.toString();

    final res = await _profileService.getUserPublicProfile(widget.userId);
    if (mounted) {
      final data = res.data;
      final actualName = (data?.fullName != null && data!.fullName.isNotEmpty && !data.fullName.startsWith('Người dùng #'))
          ? data.fullName
          : (widget.initialName?.isNotEmpty == true ? widget.initialName! : (isMe ? currentUser.fullName : 'Người dùng #${widget.userId}'));
      final actualAvatar = (data?.avatarUrl != null && data!.avatarUrl!.isNotEmpty)
          ? data.avatarUrl
          : (widget.initialAvatar ?? (isMe ? currentUser.avatarUrl : null));
      final actualCover = (data?.coverUrl != null && data!.coverUrl!.isNotEmpty)
          ? data.coverUrl
          : (widget.initialCover ?? (isMe ? currentUser.coverUrl : null));
      final actualBio = (data?.bio != null && data!.bio!.isNotEmpty)
          ? data.bio
          : (widget.initialBio ?? '');

      setState(() {
        _isCurrentUser = isMe;
        _profile = (data != null)
            ? data.copyWith(
                fullName: actualName,
                avatarUrl: actualAvatar,
                coverUrl: actualCover,
                bio: actualBio,
                rankLevel: data.rankLevel.isNotEmpty ? data.rankLevel : (widget.initialRank ?? 'Tân binh'),
                isCurrentUser: isMe,
              )
            : PublicUserProfileModel(
                id: widget.userId,
                fullName: actualName,
                avatarUrl: actualAvatar,
                coverUrl: actualCover,
                bio: actualBio,
                joinedDate: 'Tham gia gần đây',
                rankLevel: widget.initialRank ?? 'Tân binh',
                reputationScore: 0,
                isCurrentUser: isMe,
              );
        _friendStatus = _profile?.friendStatus ?? 'none';
        _isLoading = false;
      });

      // Load all real sub-tab items in parallel
      _loadTabDetails();
    }
  }

  Future<void> _loadTabDetails() async {
    setState(() => _isLoadingTabs = true);
    try {
      final reviewsRes = await _profileService.getUserReviews(widget.userId);
      final activitiesRes = await _profileService.getUserActivities(widget.userId);
      final tripsRes = await _profileService.getUserTrips(widget.userId);
      final logsRes = await _profileService.getUserVisitLogs(widget.userId);
      final blogsRes = await _profileService.getUserBlogs(widget.userId);
      final propsRes = await _profileService.getUserProposals(widget.userId);

      if (mounted) {
        setState(() {
          _reviews = reviewsRes.data ?? [];
          _activities = activitiesRes.data ?? [];
          _trips = tripsRes.data ?? [];
          _visitLogs = logsRes.data ?? [];
          _blogs = blogsRes.data ?? [];
          _proposals = propsRes.data ?? [];
          _isLoadingTabs = false;
        });
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] _loadTabDetails error: $e');
      if (mounted) {
        setState(() => _isLoadingTabs = false);
      }
    }
  }

  Future<void> _handleFriendAction() async {
    if (_isSendingFriendAction) return;

    setState(() => _isSendingFriendAction = true);

    if (_friendStatus == 'none') {
      final res = await _friendService.sendFriendRequest(widget.userId);
      if (mounted) {
        setState(() {
          _isSendingFriendAction = false;
          if (res.success) {
            _friendStatus = 'pending_sent';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res.message.isNotEmpty ? res.message : 'Đã gửi lời mời kết bạn!'),
                backgroundColor: const Color(0xFF047857),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res.message),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        });
      }
    } else if (_friendStatus == 'pending_received') {
      final res = await _friendService.respondFriendRequest(widget.userId, 'accept');
      if (mounted) {
        setState(() {
          _isSendingFriendAction = false;
          if (res.success) {
            _friendStatus = 'accepted';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Đã chấp nhận lời mời kết bạn!'),
                backgroundColor: const Color(0xFF047857),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        });
      }
    } else if (_friendStatus == 'accepted' || _friendStatus == 'pending_sent') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(_friendStatus == 'accepted' ? 'Hủy kết bạn?' : 'Hủy lời mời kết bạn?'),
          content: Text(
            _friendStatus == 'accepted'
                ? 'Bạn có chắc chắn muốn hủy kết bạn với ${_profile?.fullName}?'
                : 'Bạn có muốn thu hồi lời mời kết bạn đã gửi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đồng ý', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final res = await _friendService.unfriend(widget.userId);
        if (mounted) {
          setState(() {
            _isSendingFriendAction = false;
            if (res.success) {
              _friendStatus = 'none';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_friendStatus == 'accepted' ? 'Đã hủy kết bạn' : 'Đã hủy lời mời kết bạn'),
                  backgroundColor: const Color(0xFF475569),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          });
        }
      } else {
        setState(() => _isSendingFriendAction = false);
      }
    } else {
      setState(() => _isSendingFriendAction = false);
    }
  }

  Future<void> _handleSendMessage() async {
    if (_isOpeningChat) return;

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

    setState(() => _isOpeningChat = true);

    if (!mounted) return;
    final profile = _profile;
    final nav = Navigator.of(context);

    try {
      final res = await ChatApiService().getOrCreateDirectRoom(
        widget.userId,
        targetUserName: profile?.fullName,
        targetUserAvatar: profile?.avatarUrl,
      );

      if (mounted) {
        setState(() => _isOpeningChat = false);
      }

      final roomId = (res.success && res.data != null && res.data! > 0) ? res.data! : 0;

      nav.push(
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            roomId: roomId,
            roomName: profile?.fullName ?? 'Người dùng',
            roomAvatar: profile?.avatarUrl,
            otherUserId: widget.userId,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
      nav.push(
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            roomId: 0,
            roomName: profile?.fullName ?? 'Người dùng',
            roomAvatar: profile?.avatarUrl,
            otherUserId: widget.userId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669), strokeWidth: 3))
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. HERO COVER BANNER WITH FLOATING GLASS CONTROLS & OVERLAPPING AVATAR (HIGH Z-INDEX)
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Base Column: Cover Banner + White Info Card below
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover Banner Image
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFF065F46),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  profile?.coverUrl?.isNotEmpty == true
                                      ? profile!.coverUrl!
                                      : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600&h=600&fit=crop',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF0F766E)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                ),
                                // Gradient Shadow for Text contrast
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.45),
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.35),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // White Info & Action Card (top padding 52 to make room for overlapping avatar)
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Full Name
                                Text(
                                  profile?.fullName ?? 'Người dùng',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Badges Row
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF065F46)),
                                          const SizedBox(width: 4),
                                          Text(
                                            profile?.rankLevel ?? 'Tân binh',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF065F46),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.stars_rounded, size: 13, color: Color(0xFFD97706)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${profile?.reputationScore ?? 0} điểm',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Action Buttons Bar (Nhắn tin & Bạn bè)
                                if (!_isCurrentUser) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 42,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF059669), Color(0xFF047857)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF059669).withValues(alpha: 0.28),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: _isOpeningChat ? null : _handleSendMessage,
                                            icon: _isOpeningChat
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                                            label: const Text(
                                              'Nhắn tin',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: SizedBox(
                                          height: 42,
                                          child: OutlinedButton.icon(
                                            onPressed: _isSendingFriendAction ? null : _handleFriendAction,
                                            icon: _isSendingFriendAction
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                                                  )
                                                : Icon(
                                                    _friendStatus == 'accepted'
                                                        ? Icons.how_to_reg_rounded
                                                        : (_friendStatus == 'pending_sent'
                                                            ? Icons.access_time_rounded
                                                            : (_friendStatus == 'pending_received'
                                                                ? Icons.person_add_alt_1_rounded
                                                                : Icons.person_add_rounded)),
                                                    size: 16,
                                                    color: _friendStatus == 'accepted'
                                                        ? const Color(0xFF059669)
                                                        : (_friendStatus == 'pending_sent'
                                                            ? const Color(0xFFD97706)
                                                            : const Color(0xFF334155)),
                                                  ),
                                            label: Text(
                                              _friendStatus == 'accepted'
                                                  ? 'Bạn bè'
                                                  : (_friendStatus == 'pending_sent'
                                                      ? 'Đã gửi lời mời'
                                                      : (_friendStatus == 'pending_received'
                                                          ? 'Chấp nhận'
                                                          : 'Kết bạn')),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: _friendStatus == 'accepted'
                                                    ? const Color(0xFF059669)
                                                    : (_friendStatus == 'pending_sent'
                                                        ? const Color(0xFFD97706)
                                                        : const Color(0xFF334155)),
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: _friendStatus == 'accepted'
                                                  ? const Color(0xFFECFDF5)
                                                  : (_friendStatus == 'pending_sent'
                                                      ? const Color(0xFFFFFBEB)
                                                      : const Color(0xFFF8FAFC)),
                                              side: BorderSide(
                                                color: _friendStatus == 'accepted'
                                                    ? const Color(0xFF10B981)
                                                    : (_friendStatus == 'pending_sent'
                                                        ? const Color(0xFFFDE68A)
                                                        : const Color(0xFFCBD5E1)),
                                                width: 1.2,
                                              ),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Safe Area Floating Controls (Back & Share)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.38),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
                                  ),
                                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  if (profile != null) {
                                    ShareProfileModal.show(context, profile: profile);
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.38),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
                                  ),
                                  child: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Avatar positioned on top of BOTH Cover and White Card (HIGHEST Z-INDEX)
                      Positioned(
                        top: 137,
                        left: 20,
                        child: Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              ClipOval(
                                child: Image.network(
                                  profile?.avatarUrl?.isNotEmpty == true
                                      ? profile!.avatarUrl!
                                      : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&h=200&fit=crop',
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFFE2E8F0),
                                    child: const Icon(Icons.person, size: 44, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // 3. INTRO & BIO CARD
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildIntroCard(profile!),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // 4. HORIZONTAL CONTENT TABS
                SliverToBoxAdapter(
                  child: _buildTabsNavigation(),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // 5. ACTIVE TAB CONTENT FEED
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverToBoxAdapter(
                    child: _buildActiveTabContent(profile),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildIntroCard(PublicUserProfileModel profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giới thiệu',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Join Date Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF059669)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tham gia từ', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              profile.joinedDate ?? 'Tháng 4, 2024',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Reputation Score Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Điểm uy tín', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${profile.reputationScore} điểm',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      profile.bio!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF475569),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabsNavigation() {
    final tabs = [
      {'id': UserProfileTab.reviews, 'label': 'Đánh giá (${_profile?.reviewCount ?? _reviews.length})', 'icon': Icons.rate_review_outlined},
      {'id': UserProfileTab.activity, 'label': 'Dòng hoạt động (${_activities.length})', 'icon': Icons.bolt_rounded},
      {'id': UserProfileTab.trips, 'label': 'Chuyến đi (${_profile?.tripCount ?? _trips.length})', 'icon': Icons.map_outlined},
      {'id': UserProfileTab.visitLogs, 'label': 'Nhật ký (${_profile?.visitLogCount ?? _visitLogs.length})', 'icon': Icons.location_on_outlined},
      {'id': UserProfileTab.blogs, 'label': 'Bài viết (${_profile?.blogCount ?? _blogs.length})', 'icon': Icons.article_outlined},
      {'id': UserProfileTab.proposals, 'label': 'Đề xuất (${_profile?.proposalCount ?? _proposals.length})', 'icon': Icons.add_location_alt_outlined},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.map((t) {
          final tab = t['id'] as UserProfileTab;
          final label = t['label'] as String;
          final icon = t['icon'] as IconData;
          final isSelected = _activeTab == tab;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF059669) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF059669).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveTabContent(PublicUserProfileModel profile) {
    if (_isLoadingTabs) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF059669)),
        ),
      );
    }

    switch (_activeTab) {
      case UserProfileTab.reviews:
        return _buildReviewsTab();
      case UserProfileTab.activity:
        return _buildActivityTab();
      case UserProfileTab.trips:
        return _buildTripsTab();
      case UserProfileTab.visitLogs:
        return _buildVisitLogsTab();
      case UserProfileTab.blogs:
        return _buildBlogsTab();
      case UserProfileTab.proposals:
        return _buildProposalsTab();
    }
  }

  Widget _buildEmptyTab(IconData icon, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return _buildEmptyTab(Icons.rate_review_outlined, 'Chưa có bài đánh giá nào');
    }

    return Column(
      children: _reviews.map((r) {
        final imgUrl = r.images.isNotEmpty
            ? r.images.first
            : (r.coverImg.isNotEmpty ? r.coverImg : (r.placeThumb.isNotEmpty ? r.placeThumb : null));

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r.placeName.isNotEmpty ? r.placeName : 'Đánh giá địa điểm',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: List.generate(5, (idx) {
                      return Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: idx < r.rating ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${r.province.isNotEmpty ? '${r.province} • ' : ''}${r.createdAt.isNotEmpty ? r.createdAt : r.visitDate}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
              if (r.content.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  r.content,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
                ),
              ],
              if (imgUrl != null && imgUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imgUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityTab() {
    if (_activities.isEmpty) {
      return _buildEmptyTab(Icons.bolt_rounded, 'Chưa có hoạt động tương tác nào');
    }

    return Column(
      children: _activities.map((d) {
        final isReview = d.targetType == 'review' || d.reviewId != null;
        final typeLabel = isReview ? 'Đánh giá điểm đến' : 'Bình luận địa điểm';
        final typeColor = isReview ? const Color(0xFF059669) : const Color(0xFF0284C7);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.displayImage.isNotEmpty)
                Stack(
                  children: [
                    Image.network(
                      d.displayImage,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 60,
                        color: const Color(0xFFF1F5F9),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isReview ? Icons.star_rounded : Icons.location_on_rounded, size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              typeLabel,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      right: 10,
                      child: Text(
                        d.displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.parentAuthor != null && d.parentAuthor!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: const Border(left: BorderSide(color: Color(0xFF0D9488), width: 3)),
                        ),
                        child: Text(
                          'Phản hồi @${d.parentAuthor}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.format_quote_rounded, size: 14, color: Color(0xFF059669)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              d.content,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF14532D), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (d.createdAt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        d.createdAt,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTripsTab() {
    if (_trips.isEmpty) {
      return _buildEmptyTab(Icons.map_outlined, 'Chưa có lịch trình chuyến đi công khai nào');
    }

    return Column(
      children: _trips.map((t) {
        final coverImg = t.coverImageUrl?.isNotEmpty == true
            ? t.coverImageUrl!
            : 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600&h=350&fit=crop';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.network(
                coverImg,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  color: const Color(0xFFE2E8F0),
                  child: const Center(child: Icon(Icons.map_outlined, size: 36, color: Color(0xFF94A3B8))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${t.durationDays} Ngày ${t.nightsCount > 0 ? '${t.nightsCount} Đêm' : ''}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${t.totalStopsCount} địa điểm ${t.estimatedBudget != null ? '• ${t.estimatedBudget!.toInt()}đ' : ''} ${t.province != null ? '• ${t.province}' : ''}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVisitLogsTab() {
    if (_visitLogs.isEmpty) {
      return _buildEmptyTab(Icons.location_on_outlined, 'Chưa có nhật ký check-in công khai nào');
    }

    return Column(
      children: _visitLogs.map((log) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.placeName,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${log.province.isNotEmpty ? '${log.province} • ' : ''}Ngày ghé thăm: ${log.visitedDate}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    if (log.note != null && log.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        log.note!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBlogsTab() {
    if (_blogs.isEmpty) {
      return _buildEmptyTab(Icons.article_outlined, 'Chưa có bài viết cẩm nang nào');
    }

    return Column(
      children: _blogs.map((b) {
        final imgUrl = b.coverImg.isNotEmpty
            ? b.coverImg
            : 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=400&h=250&fit=crop';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Image.network(
                imgUrl,
                width: 104,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 104,
                  height: 84,
                  color: const Color(0xFFE2E8F0),
                  child: const Icon(Icons.article_outlined, color: Color(0xFF94A3B8)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${b.readTimeMinutes} phút đọc • ${b.viewsCount} lượt xem • ${b.category}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProposalsTab() {
    if (_proposals.isEmpty) {
      return _buildEmptyTab(Icons.add_location_alt_outlined, 'Chưa có địa điểm đề xuất nào');
    }

    return Column(
      children: _proposals.map((p) {
        final statusColor = p.status == 1
            ? const Color(0xFF065F46)
            : (p.status == 2 ? const Color(0xFFDC2626) : const Color(0xFFD97706));
        final statusBg = p.status == 1
            ? const Color(0xFFD1FAE5)
            : (p.status == 2 ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
        final statusText = p.status == 1
            ? 'Đã duyệt'
            : (p.status == 2 ? 'Từ chối' : 'Chờ duyệt');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.place_rounded, color: Color(0xFF059669), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${p.category} • ${p.province}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

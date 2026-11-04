import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_profile_data_models.dart';
import '../../../data/models/place_model.dart';
import '../../../data/models/blog_model.dart';
import '../../../data/models/itinerary_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/blog_api_service.dart';
import '../../../data/services/itinerary_api_service.dart';
import '../../../data/services/friend_api_service.dart';
import '../../../data/services/chat_api_service.dart';
import '../../widgets/profile/share_profile_modal.dart';
import '../../widgets/common/user_utility_drawer_modal.dart';
import '../../widgets/mapbox_interactive_map.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../chat/chat_room_screen.dart';
import '../destinations/place_detail_screen.dart';
import '../blog/blog_detail_screen.dart';
import '../itineraries/itinerary_detail_screen.dart';
import 'edit_profile_dialog.dart';
import 'change_password_dialog.dart';

enum UserProfileTab {
  activity,
  reviews,
  trips,
  visitLogs,
  blogs,
  proposals,
}

class UserProfileScreen extends StatefulWidget {
  final int? userId;
  final bool isRootProfile;
  final Function(int)? onNavigateTab;
  final String? initialName;
  final String? initialAvatar;
  final String? initialCover;
  final String? initialBio;
  final String? initialRank;

  const UserProfileScreen({
    super.key,
    this.userId,
    this.isRootProfile = false,
    this.onNavigateTab,
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
    int? parsedId;
    if (userId is int) {
      parsedId = userId;
    } else if (userId is String) {
      parsedId = int.tryParse(userId);
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
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  PublicUserProfileModel? _profile;
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isLoadingTabs = true;
  bool _isCurrentUser = false;
  bool _isLoggedIn = false;

  UserProfileTab _activeTab = UserProfileTab.activity;

  // Friend status: 'none', 'pending_sent', 'pending_received', 'accepted'
  String _friendStatus = 'none';
  bool _isSendingFriendAction = false;
  bool _isOpeningChat = false;

  // Cover & Avatar Uploading state
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;

  // Real Tab Data Lists pulled from API & Database
  List<UserMapPlaceModel> _mapPlaces = [];
  List<UserReviewItemModel> _reviews = [];
  List<UserCommentItemModel> _activities = [];
  List<UserTripItemModel> _trips = [];
  List<VisitLogItemModel> _visitLogs = [];
  List<UserBlogItemModel> _blogs = [];
  List<ProposalItemModel> _proposals = [];

  // Filter States
  int? _reviewStarFilter; // null = all, 5, 4, 3, 2, 1
  String _activityFilter = 'all'; // all, review, visit_log, trip, blog, proposal, comment
  String _travelMapFilter = 'all'; // all, review, visit_log, proposal
  UserMapPlaceModel? _activeMapPlace;
  final GlobalKey<MapboxInteractiveMapState> _mapKey = GlobalKey<MapboxInteractiveMapState>();
  bool _showTimelineView = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  int? get _resolvedUserId {
    if (widget.userId != null && widget.userId! > 0) {
      return widget.userId;
    }
    if (_currentUser?.id != null) {
      return int.tryParse(_currentUser!.id);
    }
    return null;
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final loggedIn = await _authService.isLoggedIn();
    final cached = await _authService.getCachedUser();
    _isLoggedIn = loggedIn;
    _currentUser = cached;

    // Determine target user
    final currentUserIdNum = cached?.id != null ? int.tryParse(cached!.id) : null;
    final targetId = widget.userId ?? currentUserIdNum;

    if (targetId == null) {
      if (mounted) {
        setState(() {
          _isCurrentUser = true;
          _isLoading = false;
          _isLoadingTabs = false;
        });
      }
      return;
    }

    final isMe = widget.userId == null || (currentUserIdNum != null && targetId == currentUserIdNum);

    // Call API: GET /api/users/{targetId}/profile
    final res = await _profileService.getUserPublicProfile(targetId);

    if (mounted) {
      final data = res.data;
      final actualName = (data?.fullName != null && data!.fullName.isNotEmpty && !data.fullName.startsWith('Người dùng #'))
          ? data.fullName
          : (widget.initialName?.isNotEmpty == true ? widget.initialName! : (isMe ? (cached?.fullName ?? 'Người dùng') : 'Người dùng #$targetId'));
      final actualAvatar = (data?.avatarUrl != null && data!.avatarUrl!.isNotEmpty)
          ? data.avatarUrl
          : (widget.initialAvatar ?? (isMe ? cached?.avatarUrl : null));
      final actualCover = (data?.coverUrl != null && data!.coverUrl!.isNotEmpty)
          ? data.coverUrl
          : (widget.initialCover ?? (isMe ? cached?.coverUrl : null));
      final actualBio = (data?.bio != null && data!.bio!.isNotEmpty)
          ? data.bio
          : (widget.initialBio ?? (isMe ? (cached?.bio ?? '') : ''));

      setState(() {
        _isCurrentUser = isMe;
        _profile = (data != null)
            ? data.copyWith(
                fullName: actualName,
                avatarUrl: actualAvatar,
                coverUrl: actualCover,
                bio: actualBio,
                rankLevel: data.rankLevel.isNotEmpty ? data.rankLevel : (widget.initialRank ?? 'Chuyên gia khám phá'),
                reputationScore: data.reputationScore > 0 ? data.reputationScore : 1250,
                isCurrentUser: isMe,
              )
            : PublicUserProfileModel(
                id: targetId,
                fullName: actualName,
                avatarUrl: actualAvatar,
                coverUrl: actualCover,
                bio: actualBio,
                joinedDate: 'Tháng 4, 2024',
                rankLevel: widget.initialRank ?? 'Chuyên gia khám phá',
                reputationScore: 1250,
                isCurrentUser: isMe,
              );
        _friendStatus = _profile?.friendStatus ?? 'none';
        _isLoading = false;
      });

      // Load all sub-tab details from database API
      _loadTabDetails(targetId, isMe);
    }
  }

  Future<void> _loadTabDetails(int targetId, bool isMe) async {
    setState(() => _isLoadingTabs = true);
    try {
      final mapPlacesRes = await _profileService.getUserMapPlaces(targetId);
      final reviewsRes = await _profileService.getUserReviews(targetId);
      final activitiesRes = await _profileService.getUserActivities(targetId);
      final tripsRes = isMe ? await _profileService.getMyTrips() : await _profileService.getUserTrips(targetId);
      final logsRes = isMe ? await _profileService.getMyVisitLogs() : await _profileService.getUserVisitLogs(targetId);
      final blogsRes = isMe ? await _profileService.getMyBlogs() : await _profileService.getUserBlogs(targetId);
      final propsRes = isMe ? await _profileService.getMyProposals() : await _profileService.getUserProposals(targetId);

      if (mounted) {
        setState(() {
          _mapPlaces = mapPlacesRes.data ?? [];
          _reviews = reviewsRes.data ?? [];
          _activities = activitiesRes.data ?? [];
          _trips = tripsRes.data ?? [];
          _visitLogs = logsRes.data ?? [];
          _blogs = blogsRes.data ?? [];
          _proposals = propsRes.data ?? [];

          // Sync counts if not set
          if (_profile != null) {
            _profile = _profile!.copyWith(
              reviewCount: _reviews.length,
              tripCount: _trips.length,
              visitLogCount: _visitLogs.length,
              blogCount: _blogs.length,
              proposalCount: _proposals.length,
            );
          }
          _isLoadingTabs = false;
        });
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] _loadTabDetails error: $e');
      if (mounted) setState(() => _isLoadingTabs = false);
    }
  }

  // ==================== FRIEND & CHAT ACTIONS ====================
  Future<void> _handleFriendAction() async {
    if (_isSendingFriendAction || _resolvedUserId == null) return;

    setState(() => _isSendingFriendAction = true);

    if (_friendStatus == 'none') {
      final res = await _friendService.sendFriendRequest(_resolvedUserId!);
      if (mounted) {
        setState(() {
          _isSendingFriendAction = false;
          if (res.success) {
            _friendStatus = 'pending_sent';
            _showSuccessSnackBar(res.message.isNotEmpty ? res.message : 'Đã gửi lời mời kết bạn!');
          } else {
            _showErrorSnackBar(res.message);
          }
        });
      }
    } else if (_friendStatus == 'pending_received') {
      final res = await _friendService.respondFriendRequest(_resolvedUserId!, 'accept');
      if (mounted) {
        setState(() {
          _isSendingFriendAction = false;
          if (res.success) {
            _friendStatus = 'accepted';
            _showSuccessSnackBar('Đã chấp nhận lời mời kết bạn!');
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

      if (confirm == true && mounted) {
        final res = await _friendService.unfriend(_resolvedUserId!);
        if (mounted) {
          setState(() {
            _isSendingFriendAction = false;
            if (res.success) {
              _friendStatus = 'none';
              _showNeutralSnackBar(_friendStatus == 'accepted' ? 'Đã hủy kết bạn' : 'Đã hủy lời mời kết bạn');
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
    if (_isOpeningChat || _resolvedUserId == null) return;

    final isLoggedIn = await _authService.isLoggedIn();
    final token = await _authService.getAccessToken();
    if (!isLoggedIn || token == null || token.isEmpty) {
      if (!mounted) return;
      _showNeutralSnackBar('Vui lòng đăng nhập để gửi tin nhắn.');
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
        _resolvedUserId!,
        targetUserName: profile?.fullName,
        targetUserAvatar: profile?.avatarUrl,
      );

      if (mounted) setState(() => _isOpeningChat = false);

      final roomId = (res.success && res.data != null && res.data! > 0) ? res.data! : 0;

      nav.push(
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            roomId: roomId,
            roomName: profile?.fullName ?? 'Người dùng',
            roomAvatar: profile?.avatarUrl,
            otherUserId: _resolvedUserId!,
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _isOpeningChat = false);
      nav.push(
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            roomId: 0,
            roomName: profile?.fullName ?? 'Người dùng',
            roomAvatar: profile?.avatarUrl,
            otherUserId: _resolvedUserId!,
          ),
        ),
      );
    }
  }

  // ==================== AVATAR & COVER UPLOAD ====================
  Future<void> _pickAvatarImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _isUploadingAvatar = true);
        final res = await _authService.updateProfile(
          fullName: _profile?.fullName ?? (_currentUser?.fullName ?? 'Người dùng'),
          avatarFilePath: picked.path,
          avatarBytes: bytes,
          avatarFileName: picked.name,
        );
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
          if (res.success) {
            _showSuccessSnackBar('Đã cập nhật ảnh đại diện thành công!');
            _loadProfile();
          } else {
            _showErrorSnackBar(res.message.isNotEmpty ? res.message : 'Không thể tải ảnh đại diện lên.');
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _isUploadingCover = true);
        final res = await _authService.updateProfile(
          fullName: _profile?.fullName ?? (_currentUser?.fullName ?? 'Người dùng'),
          coverFilePath: picked.path,
          coverBytes: bytes,
          coverFileName: picked.name,
        );
        if (mounted) {
          setState(() => _isUploadingCover = false);
          if (res.success) {
            _showSuccessSnackBar('Đã cập nhật ảnh bìa thành công!');
            _loadProfile();
          } else {
            _showErrorSnackBar(res.message.isNotEmpty ? res.message : 'Không thể tải ảnh bìa lên.');
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  // ==================== EDIT PROFILE & SETTINGS MODALS ====================
  Future<void> _openEditProfileDialog() async {
    final user = _currentUser ?? (await _authService.getCachedUser());
    if (user == null) return;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => EditProfileDialog(
        user: user,
        onSave: ({required updatedUser, avatarFilePath, coverFilePath}) async {
          final res = await _authService.updateProfile(
            fullName: updatedUser.fullName,
            phone: updatedUser.phone,
            bio: updatedUser.bio,
            avatarFilePath: avatarFilePath,
            coverFilePath: coverFilePath,
          );
          if (res.success) {
            _loadProfile();
            return null;
          } else {
            return res.message;
          }
        },
      ),
    );
  }

  void _openSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cài đặt tài khoản',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                title: const Text('Chỉnh sửa thông tin cá nhân', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                subtitle: const Text('Họ tên, ảnh đại diện, ảnh bìa, tiểu sử', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openEditProfileDialog();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF059669), size: 20),
                ),
                title: const Text('Đổi mật khẩu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                subtitle: const Text('Cập nhật mật khẩu mới bảo mật tài khoản', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  ChangePasswordDialog.show(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.apps_rounded, color: Color(0xFF475569), size: 20),
                ),
                title: const Text('Tiện ích cá nhân', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                subtitle: const Text('Mục yêu thích, bạn bè, nhật ký check-in', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  UserUtilityDrawerModal.show(context, onNavigateTab: widget.onNavigateTab);
                },
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                title: const Text('Đăng xuất tài khoản', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Text('Đăng xuất?'),
                      content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B)))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Đăng xuất', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _authService.logout();
                    if (mounted) _loadProfile();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== LIGHTBOX & NAVIGATION HELPERS ====================
  void _openImageLightbox(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                color: Colors.black.withValues(alpha: 0.92),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToPlace(int placeId, {String? name, String? province, String? cover}) async {
    final res = await PlaceApiService().getPlaceDetail(placeId);
    PlaceModel? place = res.data;
    place ??= PlaceModel(
      id: placeId,
      name: name ?? 'Địa điểm du lịch',
      category: 'Địa điểm',
      location: province ?? 'Việt Nam',
      region: 'Việt Nam',
      province: province ?? 'Việt Nam',
      type: 'Tham quan',
      rating: 4.8,
      reviews: 0,
      price: '',
      priceMax: 0,
      priceRange: '',
      hours: '',
      status: 'Mở cửa',
      desc: 'Địa điểm du lịch khám phá.',
      tags: const [],
      img: cover ?? '',
    );
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: place!)));
    }
  }

  Future<void> _navigateToBlog(int blogId, {String? title, String? cover}) async {
    BlogModel? blog = await BlogApiService().getBlogDetail(blogId);
    blog ??= BlogModel(
      id: '$blogId',
      title: title ?? 'Cẩm nang du lịch',
      summary: 'Bài viết chia sẻ cẩm nang khám phá du lịch.',
      category: 'Cẩm nang',
      imageUrl: cover ?? '',
      author: BlogAuthorModel(name: _profile?.fullName ?? 'Tác giả', avatar: _profile?.avatarUrl ?? ''),
      publishedDate: 'Gần đây',
      readTimeMinutes: 5,
    );
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => BlogDetailScreen(blog: blog!)));
    }
  }

  Future<void> _handleToggleReviewLike(UserReviewItemModel review) async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      _showNeutralSnackBar('Vui lòng đăng nhập để thích bài đánh giá.');
      return;
    }

    final res = await PlaceApiService().toggleReviewLike(review.id);
    if (res.success && mounted) {
      setState(() {
        final idx = _reviews.indexWhere((r) => r.id == review.id);
        if (idx != -1) {
          final cur = _reviews[idx];
          final isLiked = res.data?['isLiked'] as bool? ?? true;
          final newCount = res.data?['likeCount'] as int? ?? (isLiked ? cur.helpfulCount + 1 : (cur.helpfulCount > 0 ? cur.helpfulCount - 1 : 0));
          _reviews[idx] = UserReviewItemModel(
            id: cur.id,
            placeId: cur.placeId,
            placeName: cur.placeName,
            placeThumb: cur.placeThumb,
            province: cur.province,
            category: cur.category,
            rating: cur.rating,
            content: cur.content,
            visitDate: cur.visitDate,
            coverImg: cur.coverImg,
            images: cur.images,
            helpfulCount: newCount,
            createdAt: cur.createdAt,
          );
        }
      });
      _showSuccessSnackBar(res.message.isNotEmpty ? res.message : 'Đã cập nhật lượt thích!');
    }
  }

  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF047857),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showNeutralSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== BUILD ROOT VIEW ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF047857), strokeWidth: 3)),
      );
    }

    // Guest view for own profile when not logged in
    if (!_isLoggedIn && (_resolvedUserId == null || _isCurrentUser)) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _buildGuestView(),
            ),
          ),
        ),
      );
    }

    final profile = _profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFF047857),
        onRefresh: () async {
          await _loadProfile();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. HERO COVER BANNER & OVERLAPPING AVATAR (MATCHING UserProfileHeader.tsx)
            SliverToBoxAdapter(
              child: _buildHeroHeader(profile),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // 2. INTRO & BIO CARD (MATCHING UserProfileSidebar.tsx)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildIntroCard(profile),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // 3. HORIZONTAL TABS NAVIGATION (MATCHING UserProfileHeader.tsx TABS)
            SliverToBoxAdapter(
              child: _buildTabsNavigation(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // 4. ACTIVE TAB CONTENT FEED
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
              sliver: SliverToBoxAdapter(
                child: _buildActiveTabContent(profile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 1. HERO HEADER WIDGET ====================
  Widget _buildHeroHeader(PublicUserProfileModel? profile) {
    final avatar = profile?.avatarUrl?.isNotEmpty == true
        ? profile!.avatarUrl!
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&h=200&fit=crop';
    final cover = profile?.coverUrl?.isNotEmpty == true
        ? profile!.coverUrl!
        : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600&h=600&fit=crop';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Banner (height 190, matching Web)
            Container(
              height: 190,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF065F46),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF0F766E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  // Dark Top & Bottom Gradient Overlay for readability
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                  // Change Cover Button for Current User
                  if (_isCurrentUser)
                    Positioned(
                      bottom: 12,
                      right: 14,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isUploadingCover ? null : _pickCoverImage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white38),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isUploadingCover) ...[
                                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.8)),
                                  const SizedBox(width: 6),
                                  const Text('Đang lưu...', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                ] else ...[
                                  const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  const Text('Đổi ảnh bìa', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // White Info Card below Cover
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name with Pencil Edit (Matching UserProfileHeader.tsx)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          profile?.fullName ?? 'Người dùng',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isCurrentUser) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _openEditProfileDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF047857)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Badges Row (Rank & Reputation Score matching Web)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_outlined, size: 13, color: Color(0xFF065F46)),
                            const SizedBox(width: 5),
                            Text(
                              profile?.rankLevel ?? 'Chuyên gia khám phá',
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 13, color: Color(0xFFD97706)),
                            const SizedBox(width: 5),
                            Text(
                              '${profile?.reputationScore ?? 1250} điểm',
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

                  // Action Buttons:
                  // Case A: For Other Users -> Nhắn tin & Kết bạn (Matching Web UserProfileHeader.tsx)
                  if (!_isCurrentUser) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: _isOpeningChat ? null : _handleSendMessage,
                              icon: _isOpeningChat
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                              label: const Text('Nhắn tin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF047857),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
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
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF047857)))
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
                                          ? const Color(0xFF047857)
                                          : (_friendStatus == 'pending_sent' ? const Color(0xFFD97706) : const Color(0xFF334155)),
                                    ),
                              label: Text(
                                _friendStatus == 'accepted'
                                    ? 'Bạn bè'
                                    : (_friendStatus == 'pending_sent'
                                        ? 'Đã gửi lời mời'
                                        : (_friendStatus == 'pending_received' ? 'Chấp nhận' : 'Kết bạn')),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _friendStatus == 'accepted'
                                      ? const Color(0xFF047857)
                                      : (_friendStatus == 'pending_sent' ? const Color(0xFFD97706) : const Color(0xFF334155)),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _friendStatus == 'accepted'
                                    ? const Color(0xFFECFDF5)
                                    : (_friendStatus == 'pending_sent' ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC)),
                                side: BorderSide(
                                  color: _friendStatus == 'accepted'
                                      ? const Color(0xFF10B981)
                                      : (_friendStatus == 'pending_sent' ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]
                  // Case B: For Current User -> Chỉnh sửa hồ sơ, Tiện ích, Cài đặt
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: _openEditProfileDialog,
                              icon: const Icon(Icons.edit_note_rounded, size: 17, color: Colors.white),
                              label: const Text('Chỉnh sửa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF047857),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: () => UserUtilityDrawerModal.show(context, onNavigateTab: widget.onNavigateTab),
                            icon: const Icon(Icons.apps_rounded, size: 16, color: Color(0xFF1D4ED8)),
                            label: const Text('Tiện ích', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFEFF6FF),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Color(0xFF475569)),
                          tooltip: 'Cài đặt tài khoản',
                          onPressed: _openSettingsMenu,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

        // Navigation Bar Overlays (Back Button & Share Button)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!widget.isRootProfile)
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  )
                else
                  const SizedBox.shrink(),
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
                      color: Colors.black.withValues(alpha: 0.4),
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

        // Overlapping Avatar with Camera Icon Badge (Top Z-Index matching Web)
        Positioned(
          top: 140,
          left: 20,
          child: Stack(
            children: [
              Container(
                width: 92,
                height: 92,
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
                child: ClipOval(
                  child: Image.network(
                    avatar,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFE2E8F0),
                      child: const Icon(Icons.person, size: 48, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
              if (_isCurrentUser)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAvatarImage,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _isUploadingAvatar
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.8))
                          : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== 2. INTRO & BIO CARD (UserProfileSidebar.tsx) ====================
  Widget _buildIntroCard(PublicUserProfileModel? profile) {
    if (profile == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Joined Date (Matching Web: Calendar icon + joinedDate)
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
                        child: const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF047857)),
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

              // Reputation Score (Matching Web: Sparkles icon + reputationScore)
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
                        child: const Icon(Icons.auto_awesome, size: 15, color: Color(0xFFD97706)),
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

          // Bio Quote Box (Matching Web UserProfileSidebar.tsx)
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
                  const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF047857)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.bio!,
                      style: const TextStyle(
                        fontSize: 12.5,
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

  // ==================== 3. TABS NAVIGATION (UserProfileHeader.tsx) ====================
  Widget _buildTabsNavigation() {
    final tabs = [
      {'id': UserProfileTab.activity, 'label': 'Dòng hoạt động', 'icon': Icons.bolt_rounded, 'count': _activities.length},
      {'id': UserProfileTab.reviews, 'label': 'Đánh giá', 'icon': Icons.rate_review_outlined, 'count': _reviews.length},
      {'id': UserProfileTab.trips, 'label': 'Chuyến đi', 'icon': Icons.alt_route_rounded, 'count': _trips.length},
      {'id': UserProfileTab.visitLogs, 'label': 'Nhật ký điểm đến', 'icon': Icons.calendar_today_rounded, 'count': _visitLogs.length},
      {'id': UserProfileTab.blogs, 'label': 'Cẩm nang', 'icon': Icons.article_outlined, 'count': _blogs.length},
      {'id': UserProfileTab.proposals, 'label': 'Địa điểm đề xuất', 'icon': Icons.add_location_alt_outlined, 'count': _proposals.length},
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
          final count = t['count'] as int;
          final isSelected = _activeTab == tab;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF047857) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF047857).withValues(alpha: 0.25),
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
                      size: 15,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$label ($count)',
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

  // ==================== 4. ACTIVE TAB CONTENT ====================
  Widget _buildActiveTabContent(PublicUserProfileModel? profile) {
    if (_isLoadingTabs) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const Column(
          children: [
            CircularProgressIndicator(color: Color(0xFF047857), strokeWidth: 2.5),
            SizedBox(height: 12),
            Text('Đang tải dữ liệu từ máy chủ...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    switch (_activeTab) {
      case UserProfileTab.activity:
        return _buildActivityTab();
      case UserProfileTab.reviews:
        return _buildReviewsTab();
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

  // -------------------- TAB 1: DÒNG HOẠT ĐỘNG & BẢN ĐỒ DẤU CHÂN --------------------
  List<UserMapPlaceModel> _getAllMapPlaces() {
    final List<UserMapPlaceModel> list = [];
    final Set<String> seenKeys = <String>{};

    double sanitizeLat(double? lat, double? lng) {
      double normLat = lat ?? 16.0544;
      double normLng = lng ?? 108.2022;
      if (normLat > 50 && normLng < 50) {
        final t = normLat;
        normLat = normLng;
        normLng = t;
      }
      if (normLng < 100 || normLng > 115 || normLat < 8 || normLat > 25) {
        normLat = 16.0544;
      }
      return normLat;
    }

    double sanitizeLng(double? lat, double? lng) {
      double normLat = lat ?? 16.0544;
      double normLng = lng ?? 108.2022;
      if (normLat > 50 && normLng < 50) {
        final t = normLat;
        normLat = normLng;
        normLng = t;
      }
      if (normLng < 100 || normLng > 115 || normLat < 8 || normLat > 25) {
        normLng = 108.2022;
      }
      return normLng;
    }

    // 1. Data from /api/users/{userId}/map-places
    for (final p in _mapPlaces) {
      final key = '${p.interactionType}-${p.placeId > 0 ? p.placeId : p.id}';
      seenKeys.add(key);
      list.add(p);
    }

    // 2. Visit logs
    for (int i = 0; i < _visitLogs.length; i++) {
      final v = _visitLogs[i];
      final key = 'visit_log-${v.placeId > 0 ? v.placeId : v.id}';
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      final rawLat = v.lat ?? (16.0544 + ((i * 0.04) % 0.2));
      final rawLng = v.lng ?? (108.2022 + ((i * 0.05) % 0.2));
      list.add(UserMapPlaceModel(
        id: 1000 + (v.id > 0 ? v.id : i),
        placeId: v.placeId > 0 ? v.placeId : i,
        title: v.placeName.isNotEmpty ? v.placeName : 'Địa điểm đã ghé',
        coverImg: v.coverImg,
        category: v.category.isNotEmpty ? v.category : 'Nhật ký điểm đến',
        province: v.province.isNotEmpty ? v.province : 'Việt Nam',
        latitude: sanitizeLat(rawLat, rawLng),
        longitude: sanitizeLng(rawLat, rawLng),
        interactionType: 'visit_log',
        interactionLabel: 'Đã ghé thăm ${v.visitedDate}',
        date: v.visitedDate,
      ));
    }

    // 3. Proposals
    for (int i = 0; i < _proposals.length; i++) {
      final p = _proposals[i];
      final key = 'proposal-${p.id}';
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      final rawLat = p.latitude ?? (21.02 + ((i * 0.04) % 0.2));
      final rawLng = p.longitude ?? (105.85 + ((i * 0.05) % 0.2));
      list.add(UserMapPlaceModel(
        id: 3000 + (p.id > 0 ? p.id : i),
        placeId: p.id,
        title: p.name.isNotEmpty ? p.name : 'Địa điểm đề xuất',
        coverImg: p.coverImg,
        category: p.category.isNotEmpty ? p.category : 'Đề xuất địa điểm',
        province: p.province.isNotEmpty ? p.province : 'Việt Nam',
        latitude: sanitizeLat(rawLat, rawLng),
        longitude: sanitizeLng(rawLat, rawLng),
        interactionType: 'proposal',
        interactionLabel: 'Địa điểm đề xuất thành công',
        date: p.createdAt,
      ));
    }

    // 4. Reviews
    for (int i = 0; i < _reviews.length; i++) {
      final r = _reviews[i];
      final key = 'review-${r.placeId > 0 ? r.placeId : r.id}';
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      final defaultLngs = [108.22, 106.66, 105.85, 108.45, 107.59, 109.19, 103.96];
      final defaultLats = [16.05, 10.76, 21.02, 11.94, 16.46, 12.23, 10.28];
      final coordLng = defaultLngs[i % defaultLngs.length] + (i * 0.02);
      final coordLat = defaultLats[i % defaultLats.length] + (i * 0.01);
      list.add(UserMapPlaceModel(
        id: r.id > 0 ? r.id : i,
        placeId: r.placeId > 0 ? r.placeId : i,
        title: r.placeName.isNotEmpty ? r.placeName : 'Địa điểm đánh giá',
        coverImg: r.coverImg.isNotEmpty ? r.coverImg : (r.images.isNotEmpty ? r.images.first : null),
        category: r.category.isNotEmpty ? r.category : 'Du lịch & Ẩm thực',
        province: r.province.isNotEmpty ? r.province : 'Việt Nam',
        latitude: sanitizeLat(coordLat, coordLng),
        longitude: sanitizeLng(coordLat, coordLng),
        interactionType: 'review',
        interactionLabel: 'Đã đánh giá ${r.rating}★',
        rating: r.rating.toDouble(),
        date: r.visitDate.isNotEmpty ? r.visitDate : r.createdAt,
      ));
    }

    return list;
  }

  Widget _buildTravelMapFilterButton({
    required String label,
    required String typeKey,
    required int count,
    Color? dotColor,
  }) {
    final isSelected = _travelMapFilter == typeKey;
    Color activeBg;
    Color activeTextColor = Colors.white;
    Color inactiveBg;
    Color inactiveTextColor;

    if (typeKey == 'review') {
      activeBg = const Color(0xFF059669);
      inactiveBg = const Color(0xFFECFDF5);
      inactiveTextColor = const Color(0xFF065F46);
    } else if (typeKey == 'visit_log') {
      activeBg = const Color(0xFFF59E0B);
      inactiveBg = const Color(0xFFFFFBEB);
      inactiveTextColor = const Color(0xFF92400E);
    } else if (typeKey == 'proposal') {
      activeBg = const Color(0xFF2563EB);
      inactiveBg = const Color(0xFFEFF6FF);
      inactiveTextColor = const Color(0xFF1E40AF);
    } else {
      activeBg = const Color(0xFF0F172A);
      inactiveBg = const Color(0xFFF1F5F9);
      inactiveTextColor = const Color(0xFF475569);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _travelMapFilter = typeKey;
              _activeMapPlace = null;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : inactiveBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? activeBg : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  '$label ($count)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? activeTextColor : inactiveTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivePlaceFloatingCard(UserMapPlaceModel place) {
    Color tagBg;
    Color tagText;
    if (place.interactionType == 'visit_log') {
      tagBg = const Color(0xFFFEF3C7);
      tagText = const Color(0xFF92400E);
    } else if (place.interactionType == 'proposal') {
      tagBg = const Color(0xFFDBEAFE);
      tagText = const Color(0xFF1E40AF);
    } else {
      tagBg = const Color(0xFFD1FAE5);
      tagText = const Color(0xFF065F46);
    }

    final cover = (place.coverImg != null && place.coverImg!.isNotEmpty)
        ? place.coverImg!
        : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=160&h=160&fit=crop';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  place.interactionLabel,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tagText),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _activeMapPlace = null),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  cover,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 52,
                    height: 52,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.image_outlined, size: 22, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (place.category != null && place.category!.isNotEmpty)
                      Text(
                        place.category!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (place.province != null && place.province!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              place.province!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () {
                if (place.placeId > 0) {
                  _navigateToPlace(
                    place.placeId,
                    name: place.title,
                    province: place.province,
                    cover: place.coverImg,
                  );
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Xem chi tiết địa điểm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFootprintTile(UserMapPlaceModel place) {
    Color badgeBg;
    Color badgeColor;
    if (place.interactionType == 'visit_log') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeColor = const Color(0xFF92400E);
    } else if (place.interactionType == 'proposal') {
      badgeBg = const Color(0xFFDBEAFE);
      badgeColor = const Color(0xFF1E40AF);
    } else {
      badgeBg = const Color(0xFFD1FAE5);
      badgeColor = const Color(0xFF065F46);
    }

    final cover = (place.coverImg != null && place.coverImg!.isNotEmpty)
        ? place.coverImg!
        : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=160&h=160&fit=crop';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeMapPlace = place;
          });
          _mapKey.currentState?.flyTo(place.latitude, place.longitude, 13, 500);
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                cover,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFF1F5F9),
                  child: const Icon(Icons.place_rounded, size: 20, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          place.interactionLabel,
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: badgeColor),
                        ),
                      ),
                      if (place.province != null && place.province!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${place.province}',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF047857)),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelMapCard(List<UserMapPlaceModel> allPlaces) {
    final reviewCount = allPlaces.where((p) => p.interactionType == 'review').length;
    final visitLogCount = allPlaces.where((p) => p.interactionType == 'visit_log').length;
    final proposalCount = allPlaces.where((p) => p.interactionType == 'proposal').length;

    final filteredPlaces = allPlaces.where((p) {
      if (_travelMapFilter == 'all') return true;
      return p.interactionType == _travelMapFilter;
    }).toList();

    final markers = filteredPlaces.map((place) {
      Color bg;
      IconData icon;

      if (place.interactionType == 'visit_log') {
        bg = const Color(0xFFF59E0B);
        icon = Icons.location_on_rounded;
      } else if (place.interactionType == 'proposal') {
        bg = const Color(0xFF2563EB);
        icon = Icons.check_circle_rounded;
      } else {
        bg = const Color(0xFF059669);
        icon = Icons.star_rounded;
      }

      final isSelected = _activeMapPlace?.id == place.id && _activeMapPlace?.interactionType == place.interactionType;

      return MapboxCustomMarker(
        id: '${place.interactionType}_${place.id}',
        latitude: place.latitude,
        longitude: place.longitude,
        onTap: () {
          setState(() {
            _activeMapPlace = place;
          });
          _mapKey.currentState?.flyTo(place.latitude, place.longitude, 12.5, 450);
        },
        child: AnimatedScale(
          scale: isSelected ? 1.25 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: bg.withValues(alpha: 0.45),
                  blurRadius: isSelected ? 10 : 4,
                  spreadRadius: isSelected ? 2 : 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
        ),
      );
    }).toList();

    final centerLat = filteredPlaces.isNotEmpty ? filteredPlaces.first.latitude : 16.0544;
    final centerLng = filteredPlaces.isNotEmpty ? filteredPlaces.first.longitude : 108.2022;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          // Filter buttons row matching web UserProfileTravelMap
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildTravelMapFilterButton(
                  label: 'Tất cả',
                  typeKey: 'all',
                  count: allPlaces.length,
                ),
                _buildTravelMapFilterButton(
                  label: 'Đánh giá',
                  typeKey: 'review',
                  count: reviewCount,
                  dotColor: const Color(0xFF10B981),
                ),
                _buildTravelMapFilterButton(
                  label: 'Nhật ký',
                  typeKey: 'visit_log',
                  count: visitLogCount,
                  dotColor: const Color(0xFFF59E0B),
                ),
                _buildTravelMapFilterButton(
                  label: 'Đề xuất',
                  typeKey: 'proposal',
                  count: proposalCount,
                  dotColor: const Color(0xFF3B82F6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Map Container
          Container(
            height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MapboxInteractiveMap(
                      key: _mapKey,
                      initialLat: centerLat,
                      initialLng: centerLng,
                      initialZoom: 5.5,
                      customMarkers: markers,
                      showZoomControls: true,
                    ),
                  ),

                  // Fit bounds / Zoom all button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        if (filteredPlaces.isNotEmpty) {
                          double minLat = filteredPlaces.first.latitude;
                          double maxLat = filteredPlaces.first.latitude;
                          double minLng = filteredPlaces.first.longitude;
                          double maxLng = filteredPlaces.first.longitude;
                          for (final p in filteredPlaces) {
                            if (p.latitude < minLat) minLat = p.latitude;
                            if (p.latitude > maxLat) maxLat = p.latitude;
                            if (p.longitude < minLng) minLng = p.longitude;
                            if (p.longitude > maxLng) maxLng = p.longitude;
                          }
                          _mapKey.currentState?.fitBounds(
                            minLat: minLat,
                            maxLat: maxLat,
                            minLng: minLng,
                            maxLng: maxLng,
                            screenSize: const Size(360, 380),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.crop_free_rounded, size: 18, color: Color(0xFF334155)),
                      ),
                    ),
                  ),

                  // Floating Info Badge Top-Left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pin_drop_rounded, size: 13, color: Color(0xFF34D399)),
                          const SizedBox(width: 5),
                          Text(
                            '${filteredPlaces.length} điểm ghi nhận',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating Active Place Preview Card (Matching Web UserProfileTravelMap)
                  if (_activeMapPlace != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: _buildActivePlaceFloatingCard(_activeMapPlace!),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- TAB 1: DÒNG HOẠT ĐỘNG --------------------
  Widget _buildActivityTab() {
    final allMapPlaces = _getAllMapPlaces();

    final List<Map<String, dynamic>> items = [];

    for (final r in _reviews) {
      items.add({
        'type': 'review',
        'title': 'Đánh giá địa điểm: ${r.placeName}',
        'subtitle': r.content.isNotEmpty ? r.content : 'Đã chia sẻ đánh giá ${r.rating}★',
        'date': r.createdAt.isNotEmpty ? r.createdAt : r.visitDate,
        'rating': r.rating,
        'image': r.images.isNotEmpty ? r.images.first : (r.coverImg.isNotEmpty ? r.coverImg : r.placeThumb),
        'placeId': r.placeId,
      });
    }

    for (final l in _visitLogs) {
      items.add({
        'type': 'visit_log',
        'title': 'Check-in: ${l.placeName}',
        'subtitle': 'Đã ghé thăm ${l.province.isNotEmpty ? 'tại ${l.province}' : ''}',
        'date': l.visitedDate,
        'image': l.coverImg,
        'placeId': l.placeId,
      });
    }

    for (final t in _trips) {
      items.add({
        'type': 'trip',
        'title': 'Hành trình: ${t.title}',
        'subtitle': '${t.durationDays} Ngày ${t.nightsCount > 0 ? '${t.nightsCount} Đêm' : ''} • ${t.totalStopsCount} điểm dừng',
        'date': t.createdAt,
        'image': t.coverImageUrl,
        'tripId': t.id,
      });
    }

    for (final b in _blogs) {
      items.add({
        'type': 'blog',
        'title': 'Cẩm nang: ${b.title}',
        'subtitle': '${b.readTimeMinutes} phút đọc • ${b.viewsCount} lượt xem',
        'date': b.createdAt,
        'image': b.coverImg,
        'blogId': b.id,
      });
    }

    for (final p in _proposals) {
      items.add({
        'type': 'proposal',
        'title': 'Đề xuất: ${p.name}',
        'subtitle': '${p.category} tại ${p.province}',
        'date': p.createdAt,
        'image': p.coverImg,
      });
    }

    for (final c in _activities) {
      items.add({
        'type': 'comment',
        'title': 'Bình luận tại: ${c.displayTitle}',
        'subtitle': c.content,
        'date': c.createdAt,
        'image': c.displayImage,
        'placeId': c.placeId,
      });
    }

    final filtered = items.where((it) {
      if (_activityFilter == 'all') return true;
      return it['type'] == _activityFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode switch row: Bản đồ dấu chân vs Dòng thời gian
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showTimelineView = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_showTimelineView ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: !_showTimelineView
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_rounded,
                          size: 15,
                          color: !_showTimelineView ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Bản đồ dấu chân (${allMapPlaces.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: !_showTimelineView ? FontWeight.w800 : FontWeight.w600,
                            color: !_showTimelineView ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showTimelineView = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _showTimelineView ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _showTimelineView
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 15,
                          color: _showTimelineView ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Dòng thời gian (${items.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _showTimelineView ? FontWeight.w800 : FontWeight.w600,
                            color: _showTimelineView ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (!_showTimelineView) ...[
          // Hero Map Section (Matching Share_Locations UserProfileTravelMap)
          _buildTravelMapCard(allMapPlaces),

          const SizedBox(height: 14),

          // Summary Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCol('Đánh giá', '${_reviews.length}', const Color(0xFF047857)),
                _buildDivider(),
                _buildStatCol('Chuyến đi', '${_trips.length}', const Color(0xFF0284C7)),
                _buildDivider(),
                _buildStatCol('Nhật ký', '${_visitLogs.length}', const Color(0xFFD97706)),
                _buildDivider(),
                _buildStatCol('Cẩm nang', '${_blogs.length}', const Color(0xFF7C3AED)),
              ],
            ),
          ),

          if (allMapPlaces.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dấu chân gần đây',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                TextButton(
                  onPressed: () => setState(() => _showTimelineView = true),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Xem tất cả', style: TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...allMapPlaces.take(3).map((place) => _buildRecentFootprintTile(place)),
          ],
        ] else ...[
          // Summary Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCol('Đánh giá', '${_reviews.length}', const Color(0xFF047857)),
                _buildDivider(),
                _buildStatCol('Chuyến đi', '${_trips.length}', const Color(0xFF0284C7)),
                _buildDivider(),
                _buildStatCol('Nhật ký', '${_visitLogs.length}', const Color(0xFFD97706)),
                _buildDivider(),
                _buildStatCol('Cẩm nang', '${_blogs.length}', const Color(0xFF7C3AED)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Activity Type Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('Tất cả', 'all'),
                _buildFilterChip('Đánh giá', 'review'),
                _buildFilterChip('Nhật ký', 'visit_log'),
                _buildFilterChip('Chuyến đi', 'trip'),
                _buildFilterChip('Cẩm nang', 'blog'),
                _buildFilterChip('Đề xuất', 'proposal'),
                _buildFilterChip('Bình luận', 'comment'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (filtered.isEmpty)
            _buildEmptyTab(Icons.bolt_rounded, 'Chưa có hoạt động tương tác nào trong danh mục này.')
          else
            ...filtered.map((item) => _buildActivityItemCard(item)),
        ],
      ],
    );
  }

  Widget _buildStatCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 24, color: const Color(0xFFE2E8F0));
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _activityFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF475569))),
        selected: isSelected,
        selectedColor: const Color(0xFF047857),
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) => setState(() => _activityFilter = key),
      ),
    );
  }

  Widget _buildActivityItemCard(Map<String, dynamic> item) {
    final type = item['type'] as String;
    IconData icon;
    Color iconColor;
    Color iconBg;
    String typeLabel;

    switch (type) {
      case 'review':
        icon = Icons.star_rounded;
        iconColor = const Color(0xFFD97706);
        iconBg = const Color(0xFFFEF3C7);
        typeLabel = 'Đánh giá';
        break;
      case 'visit_log':
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF047857);
        iconBg = const Color(0xFFECFDF5);
        typeLabel = 'Nhật ký điểm đến';
        break;
      case 'trip':
        icon = Icons.alt_route_rounded;
        iconColor = const Color(0xFF0284C7);
        iconBg = const Color(0xFFE0F2FE);
        typeLabel = 'Chuyến đi';
        break;
      case 'blog':
        icon = Icons.article_outlined;
        iconColor = const Color(0xFF7C3AED);
        iconBg = const Color(0xFFF3E8FF);
        typeLabel = 'Cẩm nang';
        break;
      case 'proposal':
        icon = Icons.add_location_alt_outlined;
        iconColor = const Color(0xFFEA580C);
        iconBg = const Color(0xFFFFEDD5);
        typeLabel = 'Đề xuất địa điểm';
        break;
      case 'comment':
      default:
        icon = Icons.chat_bubble_outline_rounded;
        iconColor = const Color(0xFF475569);
        iconBg = const Color(0xFFF1F5F9);
        typeLabel = 'Bình luận';
        break;
    }

    final imgUrl = item['image'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
      child: InkWell(
        onTap: () {
          if (item['placeId'] != null) {
            _navigateToPlace(item['placeId'] as int, name: item['title'] as String?);
          } else if (item['blogId'] != null) {
            _navigateToBlog(item['blogId'] as int, title: item['title'] as String?);
          } else if (item['tripId'] != null) {
            _navigateToTripDetail(item['tripId'] as int);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                        child: Text(typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: iconColor)),
                      ),
                      Text(item['date'] ?? '', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item['title'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(item['subtitle'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (imgUrl != null && imgUrl.isNotEmpty) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(imgUrl, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------- TAB 2: ĐÁNH GIÁ (UserProfileReviewsTab.tsx) --------------------
  Widget _buildReviewsTab() {
    final filtered = _reviewStarFilter == null
        ? _reviews
        : _reviews.where((r) => r.rating == _reviewStarFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Star Rating Filters (Matching Web: All, 5★, 4★, 3★, 2★, 1★)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildStarFilterChip('Tất cả (${_reviews.length})', null),
              ...[5, 4, 3, 2, 1].map((s) {
                final count = _reviews.where((r) => r.rating == s).length;
                return _buildStarFilterChip('$s★ ($count)', s);
              }),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (filtered.isEmpty)
          _buildEmptyTab(Icons.rate_review_outlined, 'Chưa có bài đánh giá nào trong danh mục này.')
        else
          ...filtered.map((r) => _buildReviewCard(r)),
      ],
    );
  }

  Widget _buildStarFilterChip(String label, int? star) {
    final isSelected = _reviewStarFilter == star;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF475569))),
        selected: isSelected,
        selectedColor: const Color(0xFF047857),
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) => setState(() => _reviewStarFilter = star),
      ),
    );
  }

  Widget _buildReviewCard(UserReviewItemModel r) {
    final authorAvatar = _profile?.avatarUrl?.isNotEmpty == true
        ? _profile!.avatarUrl!
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&h=120&fit=crop';
    final authorName = _profile?.fullName ?? 'Người dùng';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // Author Header with Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ClipOval(
                    child: Image.network(authorAvatar, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person, size: 24)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      Text(r.createdAt.isNotEmpty ? r.createdAt : r.visitDate, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 3),
                    Text('${r.rating}.0', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Rating Stars Row
          Row(
            children: [
              ...List.generate(5, (idx) {
                return Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: idx < r.rating ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                );
              }),
              const SizedBox(width: 6),
              Text('${r.rating}.0 / 5', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
            ],
          ),

          if (r.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.content,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
            ),
          ],

          // Attached Images Gallery
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: r.images.map((img) {
                return GestureDetector(
                  onTap: () => _openImageLightbox(img),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      img,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // Destination Card inside Review (Matching UserProfileReviewCard.tsx)
          InkWell(
            onTap: () => _navigateToPlace(r.placeId, name: r.placeName, province: r.province, cover: r.placeThumb),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      r.placeThumb.isNotEmpty ? r.placeThumb : (r.coverImg.isNotEmpty ? r.coverImg : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=160&h=160&fit=crop'),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 44, height: 44, color: const Color(0xFFE2E8F0)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.placeName,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                r.province.isNotEmpty ? r.province : 'Việt Nam',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),

          // Like Button (Hữu ích)
          Row(
            children: [
              InkWell(
                onTap: () => _handleToggleReviewLike(r),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        r.helpfulCount > 0 ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                        size: 14,
                        color: r.helpfulCount > 0 ? const Color(0xFF047857) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        r.helpfulCount > 0 ? 'Hữu ích (${r.helpfulCount})' : 'Hữu ích',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: r.helpfulCount > 0 ? FontWeight.w800 : FontWeight.w600,
                          color: r.helpfulCount > 0 ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------- TAB 3: CHUYẾN ĐI (UserProfileTripsTab.tsx) --------------------
  Widget _buildTripsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isCurrentUser) ...[
          // "Tạo chuyến đi" Header Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lịch trình của bạn', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                    SizedBox(height: 2),
                    Text('Lên kế hoạch và theo dõi các chuyến đi', style: TextStyle(fontSize: 11, color: Color(0xFF047857))),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (widget.onNavigateTab != null) {
                      widget.onNavigateTab!(3); // Tab 3 is Itineraries
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                  label: const Text('Tạo chuyến', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_trips.isEmpty)
          _buildEmptyTab(Icons.alt_route_rounded, 'Chưa có lịch trình chuyến đi nào.')
        else
          ..._trips.map((t) => _buildTripCard(t)),
      ],
    );
  }

  Widget _buildTripCard(UserTripItemModel t) {
    final coverImg = t.coverImageUrl?.isNotEmpty == true
        ? t.coverImageUrl!
        : 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600&h=350&fit=crop';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToTripDetail(t.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Image.network(
                    coverImg,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(height: 120, color: const Color(0xFFE2E8F0)),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.privacy == 1 ? const Color(0xFF047857) : Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t.privacy == 1 ? 'Công khai' : 'Riêng tư',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            t.title,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isCurrentUser)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                            tooltip: 'Xóa chuyến đi',
                            onPressed: () => _handleDeleteTrip(t),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(6)),
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
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF047857)),
                      ],
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

  Future<void> _handleDeleteTrip(UserTripItemModel t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xóa chuyến đi?'),
        content: Text('Bạn có chắc chắn muốn xóa "${t.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _profileService.deleteTrip(t.id);
      if (success && mounted) {
        setState(() => _trips.removeWhere((item) => item.id == t.id));
        _showSuccessSnackBar('Đã xóa chuyến đi thành công!');
      }
    }
  }

  Future<void> _navigateToTripDetail(int tripId) async {
    ItineraryModel? detail = await ItineraryApiService().getItineraryDetail(tripId);
    detail ??= ItineraryModel(
      id: tripId,
      title: 'Hành trình du lịch',
      destination: 'Việt Nam',
      region: 'Việt Nam',
      duration: 'Chi tiết lịch trình',
      overview: 'Chi tiết lịch trình chuyến đi.',
      coverUrl: '',
      author: ItineraryAuthorModel(
        name: _profile?.fullName ?? 'Người dùng',
        avatar: _profile?.avatarUrl ?? '',
      ),
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ItineraryDetailScreen(itinerary: detail!)),
      );
    }
  }

  // -------------------- TAB 4: NHẬT KÝ ĐIỂM ĐẾN (UserProfileVisitLogsTab.tsx) --------------------
  Widget _buildVisitLogsTab() {
    if (_visitLogs.isEmpty) {
      return _buildEmptyTab(Icons.calendar_today_rounded, 'Chưa có nhật ký check-in điểm đến nào.');
    }

    return Column(
      children: _visitLogs.map((log) {
        final coverImage = log.coverImg.isNotEmpty
            ? log.coverImg
            : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400&h=250&fit=crop';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
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
          child: InkWell(
            onTap: () => _navigateToPlace(log.placeId, name: log.placeName, province: log.province, cover: log.coverImg),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(coverImage, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 64, height: 64, color: const Color(0xFFE2E8F0))),
                    ),
                    Positioned(
                      top: 3,
                      left: 3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0xFF047857), shape: BoxShape.circle),
                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text('Đã ghé thăm: ${log.visitedDate}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(log.placeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (log.province.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFFD97706)),
                            const SizedBox(width: 3),
                            Expanded(child: Text(log.province, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isCurrentUser)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: const Text('Xóa nhật ký?'),
                          content: Text('Xóa điểm đến "${log.placeName}" khỏi nhật ký check-in?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B)))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final res = await _profileService.deleteVisitLog(log.id);
                        if (res.success && mounted) {
                          setState(() => _visitLogs.removeWhere((i) => i.id == log.id));
                          _showSuccessSnackBar('Đã xóa khỏi nhật ký.');
                        }
                      }
                    },
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // -------------------- TAB 5: CẨM NANG (UserProfileBlogsTab.tsx) --------------------
  Widget _buildBlogsTab() {
    if (_blogs.isEmpty) {
      return _buildEmptyTab(Icons.article_outlined, 'Chưa có bài viết cẩm nang nào.');
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
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _navigateToBlog(b.id, title: b.title, cover: b.coverImg),
            child: Row(
              children: [
                Image.network(
                  imgUrl,
                  width: 110,
                  height: 94,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(width: 110, height: 94, color: const Color(0xFFE2E8F0)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text('${b.readTimeMinutes} phút đọc • ${b.viewsCount} lượt xem • ${b.category}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // -------------------- TAB 6: ĐỊA ĐIỂM ĐỀ XUẤT (UserProfileProposalsTab.tsx) --------------------
  Widget _buildProposalsTab() {
    if (_proposals.isEmpty) {
      return _buildEmptyTab(Icons.add_location_alt_outlined, 'Chưa có địa điểm đề xuất nào.');
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.place_rounded, color: Color(0xFF047857), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${p.category} • ${p.province}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(statusText, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // -------------------- EMPTY TAB & GUEST VIEW --------------------
  Widget _buildEmptyTab(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGuestView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded, size: 48, color: Color(0xFF047857)),
          ),
          const SizedBox(height: 18),
          const Text('Trang cá nhân', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          const Text(
            'Đăng nhập để xem trang cá nhân, lưu giữ hành trình, đánh giá địa điểm và kết nối bạn bè trên LangThang.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final didLogin = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (didLogin == true) _loadProfile();
              },
              child: const Text('Đăng nhập ngay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF047857)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final didRegister = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
                if (didRegister == true) _loadProfile();
              },
              child: const Text('Đăng ký tài khoản', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
            ),
          ),
        ],
      ),
    );
  }
}

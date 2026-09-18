import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/api_response.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/favorite_model.dart';
import '../../../data/models/user_profile_data_models.dart';
import '../../../data/services/favorite_api_service.dart';
import '../../../data/services/place_api_service.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../../data/services/friend_api_service.dart';
import '../../../data/models/friend_model.dart';
import '../../widgets/profile/favorites_section_widget.dart';
import '../../widgets/profile/visited_log_section_widget.dart';
import '../../widgets/profile/user_proposals_section_widget.dart';
import '../../widgets/profile/friends_section_widget.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../destinations/place_detail_screen.dart';
import 'edit_profile_dialog.dart';
import 'change_password_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FavoriteApiService _favoriteApiService = FavoriteApiService();
  final UserProfileApiService _profileApiService = UserProfileApiService();
  final FriendApiService _friendApiService = FriendApiService();

  UserModel? _user;
  bool _isLoading = true;
  bool _isLoggedIn = true;
  bool _isTabLoading = false;

  // 0: favorites, 1: friends, 2: visitLogs, 3: reviews, 4: comments, 5: blogs, 6: proposals
  int _activeTabIndex = 0;

  int _favoritesCount = 0;
  int _friendsCount = 0;
  List<VisitLogItemModel> _visitLogs = [];
  List<UserReviewItemModel> _reviews = [];
  List<UserCommentItemModel> _comments = [];
  List<UserBlogItemModel> _blogs = [];
  List<ProposalItemModel> _proposals = [];

  int? _reviewRatingFilter; // null = all, 1..5

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchAllTabData(showLoading: true);
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_user == null) {
      setState(() => _isLoading = true);
    }

    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) {
      final cached = await _authService.getCachedUser();
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
          _user = cached;
        });
      }
      return;
    }

    final res = await _authService.getProfile();
    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
        if (res.success && res.data != null) {
          _user = res.data;
        } else if (_user == null) {
          _loadCachedUser();
        }
      });
    }
  }

  Future<void> _loadCachedUser() async {
    final cached = await _authService.getCachedUser();
    if (mounted) {
      setState(() {
        _user = cached;
      });
    }
  }

  Future<void> _fetchAllTabData({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isTabLoading = true);
    }
    try {
      final results = await Future.wait([
        _favoriteApiService.getFavoriteCounts(),
        _profileApiService.getMyVisitLogs(),
        _profileApiService.getMyReviews(),
        _profileApiService.getMyComments(),
        _profileApiService.getMyBlogs(),
        _profileApiService.getMyProposals(),
        _friendApiService.getFriends(),
      ]);

      if (mounted) {
        final favCounts = results[0] as Map<FavoriteTargetType, int>;
        final logsRes = results[1] as ApiResponse<List<VisitLogItemModel>>;
        final revRes = results[2] as ApiResponse<List<UserReviewItemModel>>;
        final comRes = results[3] as ApiResponse<List<UserCommentItemModel>>;
        final blogRes = results[4] as ApiResponse<List<UserBlogItemModel>>;
        final propRes = results[5] as ApiResponse<List<ProposalItemModel>>;
        final friendsRes = results[6] as ApiResponse<FriendsResponseModel>;

        setState(() {
          _favoritesCount = favCounts[FavoriteTargetType.all] ?? 0;
          _visitLogs = logsRes.data ?? [];
          _reviews = revRes.data ?? [];
          _comments = comRes.data ?? [];
          _blogs = blogRes.data ?? [];
          _proposals = propRes.data ?? [];
          _friendsCount = friendsRes.data?.friends.length ?? 0;
          _isTabLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProfileScreen] _fetchAllTabData error: $e');
      if (mounted) setState(() => _isTabLoading = false);
    }
  }

  void _navigateToPlace(int placeId, String placeName, String coverImg, String province, {double? rating}) async {
    final res = await PlaceApiService().getPlaceDetail(placeId);
    if (!mounted) return;
    final place = (res.success && res.data != null)
        ? res.data!
        : PlaceModel(
            id: placeId,
            name: placeName.isNotEmpty ? placeName : 'Địa điểm #$placeId',
            category: 'Điểm tham quan',
            location: province,
            region: 'Việt Nam',
            province: province,
            type: 'Điểm tham quan',
            rating: rating ?? 5.0,
            reviews: 0,
            price: 'Miễn phí',
            priceMax: 0,
            priceRange: 'Miễn phí',
            hours: '07:30 – 17:30',
            status: 'Đang mở cửa',
            desc: '',
            detailedDescription: '',
            phoneNumber: '',
            website: '',
            img: coverImg,
            mediaUrls: coverImg.isNotEmpty ? [coverImg] : [],
            latitude: 21.0285,
            longitude: 105.8542,
            tags: const ['Điểm tham quan'],
            amenities: const [],
            isSaved: false,
          );
    Navigator.push(context, MaterialPageRoute(builder: (context) => PlaceDetailScreen(place: place)));
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return 'Chưa cập nhật';
    final cleaned = phone.replaceAll(' ', '');
    if (cleaned.length > 6) {
      return '${cleaned.substring(0, 4)} *** ${cleaned.substring(cleaned.length - 3)}';
    }
    return phone;
  }

  void _openEditProfileDialog() {
    if (_user == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditProfileDialog(
        user: _user!,
        onSave: ({required updatedUser, avatarFilePath, coverFilePath}) async {
          final res = await _authService.updateProfile(
            fullName: updatedUser.fullName,
            phone: updatedUser.phone,
            bio: updatedUser.bio,
            avatarFilePath: avatarFilePath,
            coverFilePath: coverFilePath,
          );
          if (res.success && res.data != null) {
            setState(() => _user = res.data);
            return null;
          }
          return res.message.isNotEmpty ? res.message : 'Không thể cập nhật hồ sơ';
        },
      ),
    );
  }

  void _openChangePasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Đăng xuất tài khoản',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng LangThang không?',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy bỏ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _authService.logout();
              if (mounted) {
                setState(() {
                  _isLoggedIn = false;
                  _user = null;
                  _favoritesCount = 0;
                  _friendsCount = 0;
                  _visitLogs = [];
                  _reviews = [];
                  _comments = [];
                  _blogs = [];
                  _proposals = [];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Đã đăng xuất tài khoản thành công!'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
        ),
      );
    }

    if (!_isLoggedIn || _user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _buildGuestView(),
              ),
            ),
          ),
        ),
      );
    }

    final user = _user!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await _loadProfile(forceRefresh: true);
          await _fetchAllTabData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ===== 1. HERO HEADER CARD =====
                  _buildHeroHeaderCard(user),

                  const SizedBox(height: 18),

                  // ===== 2. TABS NAVIGATION (6 TABS - Exactly matching Share_Locations) =====
                  _buildTabsNavigation(),

                  const SizedBox(height: 18),

                  // ===== 3. ACTIVE TAB CONTENT =====
                  _buildActiveTabContent(),

                  const SizedBox(height: 20),

                  // ===== 4. PERSONAL INFO & REPUTATION (Responsive Layout matching Share_Locations) =====
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 768) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPersonalInfoCard(user)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildReputationScoreCard(user)),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildPersonalInfoCard(user),
                            const SizedBox(height: 16),
                            _buildReputationScoreCard(user),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // ===== 5. ACCOUNT SETTINGS CARD =====
                  _buildAccountSettingsCard(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 1. HERO HEADER CARD ====================
  Widget _buildHeroHeaderCard(UserModel user) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Banner Image with Avatar Overlapping
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 160,
                width: double.infinity,
                color: const Color(0xFF0F172A),
                child: Image.network(
                  user.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF134E4A), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                ),
              ),
              // Overlapping Avatar at Bottom Left
              Positioned(
                left: 20,
                bottom: -36,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    user.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF047857),
                      child: Center(
                        child: Text(
                          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // User Profile Info & Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF047857)),
                          const SizedBox(width: 4),
                          Text(
                            user.jobTitle.isNotEmpty ? user.jobTitle : 'Tân binh',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bio
                Text(
                  user.bio.isNotEmpty ? user.bio : 'Người dùng chưa thêm mô tả bản thân.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 18),

                // Action Buttons: Sửa hồ sơ & Đổi mật khẩu
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Sửa hồ sơ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _openEditProfileDialog,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.key_outlined, size: 16),
                        label: const Text('Đổi mật khẩu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _openChangePasswordDialog,
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
  }

  // ==================== 2. PERSONAL INFO CARD ====================
  Widget _buildPersonalInfoCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.how_to_reg_outlined, size: 18, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Text(
                'Thông tin cá nhân',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Email
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mail_outline, size: 18, color: Color(0xFF047857)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EMAIL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      user.email.isNotEmpty ? user.email : 'Chưa cập nhật',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Phone
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SỐ ĐIỆN THOẠI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      _formatPhone(user.phone),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 3. REPUTATION SCORE CARD ====================
  Widget _buildReputationScoreCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.emoji_events_outlined, size: 18, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text(
                'Điểm cống hiến',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  const Color(0xFFF59E0B).withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user.reviewsCount}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD97706),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Điểm uy tín tích lũy',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 22, color: Color(0xFFD97706)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Điểm cống hiến được tích lũy thông qua việc đóng góp địa điểm (+50đ), viết review chất lượng và chia sẻ cẩm nang.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==================== 4. ACCOUNT SETTINGS CARD ====================
  Widget _buildAccountSettingsCard() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.lock_reset_outlined, size: 17, color: Color(0xFF047857)),
            ),
            title: const Text('Đổi mật khẩu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
            onTap: _openChangePasswordDialog,
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.logout, size: 17, color: Color(0xFFEF4444)),
            ),
            title: const Text('Đăng xuất tài khoản', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
            trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFEF4444)),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  // ==================== 5. TABS NAVIGATION (7 TABS) ====================
  Widget _buildTabsNavigation() {
    final tabs = [
      {'title': 'Đã lưu ($_favoritesCount)', 'icon': Icons.bookmark_outline_rounded},
      {'title': 'Bạn bè ($_friendsCount)', 'icon': Icons.people_outline_rounded},
      {'title': 'Nhật ký (${_visitLogs.length})', 'icon': Icons.explore_outlined},
      {'title': 'Đánh giá (${_reviews.length})', 'icon': Icons.star_outline_rounded},
      {'title': 'Bình luận (${_comments.length})', 'icon': Icons.chat_bubble_outline_rounded},
      {'title': 'Bài viết (${_blogs.length})', 'icon': Icons.menu_book_outlined},
      {'title': 'Đề xuất (${_proposals.length})', 'icon': Icons.add_circle_outline_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _activeTabIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => setState(() => _activeTabIndex = index),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabs[index]['icon'] as IconData,
                        size: 15,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabs[index]['title'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ==================== 6. ACTIVE TAB CONTENT ====================
  Widget _buildActiveTabContent() {
    if (_isTabLoading) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
        ),
      );
    }

    switch (_activeTabIndex) {
      case 0:
        return FavoritesSectionWidget(
          onFavoriteChanged: _fetchAllTabData,
        );
      case 1:
        return FriendsSectionWidget(
          onFriendsCountChanged: _fetchAllTabData,
        );
      case 2:
        return VisitedLogSectionWidget(
          onLogChanged: _fetchAllTabData,
        );
      case 3:
        return _buildReviewsTab();
      case 4:
        return _buildCommentsTab();
      case 5:
        return _buildBlogsTab();
      case 6:
      default:
        return _buildProposalsTab();
    }
  }

  // ==================== TAB 3: REVIEWS ====================
  Widget _buildReviewsTab() {
    var filtered = _reviews;
    if (_reviewRatingFilter != null) {
      filtered = filtered.where((r) => r.rating == _reviewRatingFilter).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đánh giá của tôi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_reviews.length} nhận xét trải nghiệm bạn đã chia sẻ',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _fetchAllTabData,
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                    tooltip: 'Làm mới',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Rating Filters (Tất cả, 5★, 4★, 3★, 2★, 1★)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildRatingPill(
                      label: 'Tất cả (${_reviews.length})',
                      isSelected: _reviewRatingFilter == null,
                      onTap: () => setState(() => _reviewRatingFilter = null),
                    ),
                    for (int star = 5; star >= 1; star--)
                      _buildRatingPill(
                        label: '$star ★ (${_reviews.where((r) => r.rating == star).length})',
                        isSelected: _reviewRatingFilter == star,
                        onTap: () => setState(() => _reviewRatingFilter = star),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          _buildEmptyCard(
            icon: Icons.star_outline_rounded,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            title: 'Chưa có bài đánh giá nào',
            desc: 'Khám phá các địa điểm và viết cảm nhận chân thực để chia sẻ kinh nghiệm cùng cộng đồng nhé!',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final rev = filtered[index];
              return InkWell(
                onTap: () => _navigateToPlace(
                  rev.placeId,
                  rev.placeName,
                  rev.placeThumb,
                  rev.province,
                  rating: rev.rating.toDouble(),
                ),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: rev.placeThumb.isNotEmpty
                                  ? Image.network(
                                      rev.placeThumb,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xFFF1F5F9),
                                        child: const Icon(Icons.place, size: 20, color: Color(0xFF047857)),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(Icons.place, size: 20, color: Color(0xFF047857)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rev.placeName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                if (rev.province.isNotEmpty)
                                  Text(
                                    rev.province,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: i < rev.rating ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (rev.visitDate.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event_available_outlined, size: 12, color: Color(0xFF047857)),
                              const SizedBox(width: 4),
                              Text(
                                'Đã ghé thăm: ${rev.visitDate}',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        rev.content,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45),
                      ),
                      if (rev.images.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 64,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: rev.images.length,
                            separatorBuilder: (context, i) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  rev.images[i],
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, e, st) => Container(
                                    width: 64,
                                    height: 64,
                                    color: const Color(0xFFF1F5F9),
                                    child: const Icon(Icons.broken_image, size: 18, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.thumb_up_alt_outlined, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            '${rev.helpfulCount} hữu ích',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                          const Spacer(),
                          Text(
                            rev.createdAt.length >= 10 ? rev.createdAt.substring(0, 10) : rev.createdAt,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRatingPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== TAB 4: COMMENTS ====================
  Widget _buildCommentsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bình luận & Thảo luận',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_comments.length} đóng góp thảo luận bạn đã tham gia',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              IconButton(
                onPressed: _fetchAllTabData,
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Làm mới',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_comments.isEmpty)
          _buildEmptyCard(
            icon: Icons.chat_bubble_outline_rounded,
            iconBg: const Color(0xFFCCFBF1),
            iconColor: const Color(0xFF0D9488),
            title: 'Chưa có bình luận nào',
            desc: 'Tham gia bình luận tại các bài viết cẩm nang và hỏi đáp địa điểm cùng cộng đồng phượt thủ nhé!',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final com = _comments[index];
              return InkWell(
                onTap: () => _navigateToPlace(
                  com.placeId,
                  com.placeName,
                  com.placeThumb,
                  '',
                ),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: com.placeThumb.isNotEmpty
                                  ? Image.network(
                                      com.placeThumb,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, e, st) => Container(
                                        color: const Color(0xFFF1F5F9),
                                        child: const Icon(Icons.place_outlined, size: 16, color: Color(0xFF047857)),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(Icons.place_outlined, size: 16, color: Color(0xFF047857)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              com.placeName,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            com.createdAt.length >= 10 ? com.createdAt.substring(0, 10) : com.createdAt,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      if (com.parentAuthor != null && com.parentAuthor!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Phản hồi tới: ${com.parentAuthor}',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        com.content,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ==================== TAB 5: BLOGS ====================
  Widget _buildBlogsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bài viết của tôi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_blogs.length} bài viết cẩm nang du lịch',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tính năng soạn bài viết mới đang được kích hoạt.')),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tạo bài viết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_blogs.isEmpty)
          _buildEmptyCard(
            icon: Icons.menu_book_outlined,
            iconBg: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4F46E5),
            title: 'Chưa có bài viết nào',
            desc: 'Bạn chưa đăng bài viết chia sẻ cẩm nang du lịch nào. Hãy viết bài đầu tiên để chia sẻ với cộng đồng LangThang!',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _blogs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final blog = _blogs[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Image.network(
                        blog.coverImg,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.article_outlined, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: blog.status == 1 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    blog.status == 1 ? 'Đã xuất bản' : 'Bản nháp',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: blog.status == 1 ? const Color(0xFF047857) : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  blog.category,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              blog.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.visibility_outlined, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 3),
                                Text('${blog.viewsCount} xem', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                                const Spacer(),
                                Text(blog.createdAt, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ],
                        ),
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

  // ==================== TAB 6: PROPOSALS ====================
  Widget _buildProposalsTab() {
    return UserProposalsSectionWidget(
      proposals: _proposals,
      onRefresh: _fetchAllTabData,
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String desc,
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
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 26, color: iconColor),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==================== GUEST / UNAUTHENTICATED VIEW ====================
  Widget _buildGuestView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Hero Avatar & Greeting Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF047857), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF047857).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chào mừng bạn đến với LangThang',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Đăng nhập để đồng bộ thông tin tài khoản, lưu các điểm đến yêu thích, viết đánh giá và chia sẻ cẩm nang của riêng bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text(
                        'Đăng nhập ngay',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        ).then((_) {
                          _loadProfile(forceRefresh: true);
                          _fetchAllTabData();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Tạo tài khoản',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        ).then((_) {
                          _loadProfile(forceRefresh: true);
                          _fetchAllTabData();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Features Highlight
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Quyền lợi khi có tài khoản',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
        ),
        const SizedBox(height: 12),

        _buildGuestFeatureTile(
          icon: Icons.bookmark_added_outlined,
          color: const Color(0xFF047857),
          title: 'Lưu & Đồng bộ địa điểm',
          description: 'Lưu lại điểm đến, quán ăn và cẩm nang du lịch yêu thích mọi lúc mọi nơi.',
        ),
        const SizedBox(height: 10),
        _buildGuestFeatureTile(
          icon: Icons.rate_review_outlined,
          color: const Color(0xFF3B82F6),
          title: 'Viết đánh giá & Đăng ảnh',
          description: 'Chia sẻ trải nghiệm thực tế và cảm nhận của bạn cùng cộng đồng du lịch.',
        ),
        const SizedBox(height: 10),
        _buildGuestFeatureTile(
          icon: Icons.add_location_alt_outlined,
          color: const Color(0xFFF59E0B),
          title: 'Đề xuất địa điểm mới',
          description: 'Góp phần giới thiệu những nét đẹp cảnh sắc và văn hóa ẩm thực Việt Nam.',
        ),

        const SizedBox(height: 24),

        // App Information Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'LangThang App • Phiên bản 1.0.0',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuestFeatureTile({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

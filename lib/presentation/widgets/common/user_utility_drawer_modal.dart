import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_profile_data_models.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/user_profile_api_service.dart';
import '../../../data/services/place_api_service.dart';
import '../profile/favorites_section_widget.dart';
import '../profile/user_trips_section_widget.dart';
import '../profile/visited_log_section_widget.dart';
import '../profile/friends_section_widget.dart';
import '../profile/user_proposals_section_widget.dart';
import '../../screens/destinations/place_detail_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/blog/blog_editor_screen.dart';
import '../../screens/blog/blog_detail_screen.dart';
import '../../screens/main_navigation_screen.dart';
import '../../../data/models/blog_model.dart';
import '../../../data/models/report_model.dart';
import '../report/report_modal_sheet.dart';

enum UtilityType {
  favorites,
  trips,
  visitLogs,
  friends,
  reviews,
  comments,
  blogs,
  proposals,
  reports,
}

class UserUtilityDrawerModal extends StatefulWidget {
  final UtilityType? initialUtility;
  final VoidCallback? onOpenSettings;
  final Function(int)? onNavigateTab;

  const UserUtilityDrawerModal({
    super.key,
    this.initialUtility,
    this.onOpenSettings,
    this.onNavigateTab,
  });

  static Future<void> show(
    BuildContext context, {
    UtilityType? initialUtility,
    VoidCallback? onOpenSettings,
    Function(int tabIndex)? onNavigateTab,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserUtilityDrawerModal(
        initialUtility: initialUtility,
        onOpenSettings: onOpenSettings,
        onNavigateTab: onNavigateTab,
      ),
    );
  }

  @override
  State<UserUtilityDrawerModal> createState() => _UserUtilityDrawerModalState();
}

class _UserUtilityDrawerModalState extends State<UserUtilityDrawerModal> {
  final AuthService _authService = AuthService();
  final UserProfileApiService _profileApiService = UserProfileApiService();
  StreamSubscription<UserModel?>? _userSub;

  UserModel? _user;
  bool _isLoggedIn = true;

  UtilityType? _activeUtility;
  String? _toastMessage;

  // Cached data for utilities inside drawer
  List<UserReviewItemModel> _reviews = [];
  List<UserCommentItemModel> _comments = [];
  List<UserBlogItemModel> _blogs = [];
  List<ProposalItemModel> _proposals = [];
  int? _reviewRatingFilter;
  int? _blogStatusFilter; // null = all, 1 = published, 2 = pending, 0 = draft
  bool _isLoadingUtilityData = false;

  @override
  void initState() {
    super.initState();
    _activeUtility = widget.initialUtility;
    _userSub = _authService.onUserUpdated.listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
          _isLoggedIn = user != null;
        });
      }
    });
    _loadUser();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _user = null;
        });
      }
      return;
    }

    final cached = await _authService.getCachedUser();
    if (cached != null && mounted) {
      setState(() {
        _user = cached;
        _isLoggedIn = true;
      });
    }

    final profileRes = await _authService.getProfile();
    if (profileRes.success && profileRes.data != null && mounted) {
      setState(() {
        _user = profileRes.data;
        _isLoggedIn = true;
      });
    } else if (!profileRes.success && mounted) {
      setState(() {
        _user = null;
        _isLoggedIn = false;
      });
    }
  }

  Future<void> _loadUtilityData(UtilityType type) async {
    if (!_isLoggedIn) return;
    setState(() => _isLoadingUtilityData = true);

    try {
      if (type == UtilityType.reviews) {
        final res = await _profileApiService.getMyReviews();
        if (res.success && res.data != null && mounted) {
          setState(() => _reviews = res.data!);
        }
      } else if (type == UtilityType.comments) {
        final res = await _profileApiService.getMyComments();
        if (res.success && res.data != null && mounted) {
          setState(() => _comments = res.data!);
        }
      } else if (type == UtilityType.blogs) {
        final res = await _profileApiService.getMyBlogs();
        if (res.success && res.data != null && mounted) {
          setState(() => _blogs = res.data!);
        }
      } else if (type == UtilityType.proposals) {
        final res = await _profileApiService.getMyProposals();
        if (res.success && res.data != null && mounted) {
          setState(() => _proposals = res.data!);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingUtilityData = false);
    }
  }

  void _selectUtility(UtilityType type) {
    setState(() {
      _activeUtility = type;
    });
    _loadUtilityData(type);
  }

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  Future<void> _navigateToPlace(int placeId) async {
    try {
      final res = await PlaceApiService().getPlaceDetail(placeId);
      if (res.success && res.data != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceDetailScreen(place: res.data!),
          ),
        );
      }
    } catch (_) {}
  }

  void _handleOpenSettings() {
    Navigator.pop(context);
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!();
    } else if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(5); // Tab 5 is Profile/Settings
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Đăng xuất', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen(redirectToHome: true)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              // Top drag pill
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: _activeUtility == null
                    ? _buildLevel1MainMenu()
                    : _buildLevel2ActiveUtility(),
              ),
            ],
          ),

          // Toast Alert
          if (_toastMessage != null)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _toastMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
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

  // ==================== LEVEL 1: MAIN MENU ====================
  Widget _buildLevel1MainMenu() {
    final displayName = _user?.fullName.isNotEmpty == true ? _user!.fullName : 'Người dùng';
    final email = _user?.email ?? '';
    final avatarUrl = _user?.avatarUrl ?? '';

    final utilityMenuItems = [
      {
        'type': UtilityType.favorites,
        'title': 'Yêu thích',
        'subtitle': 'Địa điểm, ẩm thực, cẩm nang đã lưu',
        'icon': Icons.bookmark_outline_rounded,
      },
      {
        'type': UtilityType.trips,
        'title': 'Hành trình',
        'subtitle': 'Lịch trình du lịch do bản thân tạo ra',
        'icon': Icons.alt_route_rounded,
      },
      {
        'type': UtilityType.visitLogs,
        'title': 'Nhật ký',
        'subtitle': 'Địa điểm đã check-in, đánh giá & ghi nhớ',
        'icon': Icons.calendar_today_outlined,
      },
      {
        'type': UtilityType.friends,
        'title': 'Bạn bè',
        'subtitle': 'Danh sách bạn bè & kết nối du lịch',
        'icon': Icons.people_outline_rounded,
      },
      {
        'type': UtilityType.reviews,
        'title': 'Bài đánh giá',
        'subtitle': 'Các đánh giá địa điểm của bạn',
        'icon': Icons.star_outline_rounded,
      },
      {
        'type': UtilityType.comments,
        'title': 'Bình luận',
        'subtitle': 'Các bình luận về địa điểm đã chia sẻ',
        'icon': Icons.chat_bubble_outline_rounded,
      },
      {
        'type': UtilityType.blogs,
        'title': 'Cẩm nang',
        'subtitle': 'Cẩm nang & bài viết kinh nghiệm du lịch',
        'icon': Icons.menu_book_outlined,
      },
      {
        'type': UtilityType.proposals,
        'title': 'Đóng góp',
        'subtitle': 'Địa điểm bạn đã đề xuất lên hệ thống',
        'icon': Icons.add_location_alt_outlined,
      },
      {
        'type': UtilityType.reports,
        'title': 'Báo cáo vi phạm',
        'subtitle': 'Lịch sử phản ánh nội dung & thẩm định',
        'icon': Icons.flag_outlined,
      },
    ];

    return Column(
      children: [
        // User Profile Banner (Matching Share_Locations UserUtilityDrawer.tsx)
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              // Avatar with green status badge
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl.isNotEmpty
                        ? buildAppImage(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: Center(
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ),
                  ),
                  if (_isLoggedIn)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
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

              // User Name, Email, and Settings Link
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoggedIn ? displayName : 'Khách vãng lai',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoggedIn ? email : 'Đăng nhập để đồng bộ tiện ích du lịch',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (_isLoggedIn)
                      InkWell(
                        onTap: _handleOpenSettings,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Quản lý tài khoản',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right, size: 14, color: Color(0xFF047857)),
                          ],
                        ),
                      )
                    else
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen(redirectToHome: true)),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF047857),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.login_rounded, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Đăng nhập ngay',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Close button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                tooltip: 'Đóng',
              ),
            ],
          ),
        ),

        // Section Title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            children: [
              Text(
                'TIỆN ÍCH CÁ NHÂN (${utilityMenuItems.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
            ],
          ),
        ),

        // List of 9 Utilities - Clean Flat Icon Style matching System Nav Drawer (Menu 3 gạch)
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: utilityMenuItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = utilityMenuItems[index];
              return InkWell(
                onTap: () => _selectUtility(item['type'] as UtilityType),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: Icon(
                            item['icon'] as IconData,
                            size: 20,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              item['subtitle'] as String,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom Actions (Cài đặt & Đăng xuất)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Cài đặt tài khoản', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  onPressed: _handleOpenSettings,
                ),
              ),
              const SizedBox(width: 10),
              if (_isLoggedIn)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Đăng xuất', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  onPressed: _handleLogout,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== LEVEL 2: ACTIVE UTILITY ====================
  Widget _buildLevel2ActiveUtility() {
    final title = _getUtilityTitle(_activeUtility!);

    return Column(
      children: [
        // Level 2 Header with Back button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _activeUtility = null),
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF334155), size: 20),
                tooltip: 'Quay lại',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                tooltip: 'Đóng',
              ),
            ],
          ),
        ),

        // Sub-utility dynamic content
        Expanded(
          child: _isLoadingUtilityData
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                )
              : _buildSubUtilityBody(_activeUtility!),
        ),
      ],
    );
  }

  String _getUtilityTitle(UtilityType type) {
    switch (type) {
      case UtilityType.favorites:
        return 'Địa điểm yêu thích';
      case UtilityType.trips:
        return 'Hành trình của tôi';
      case UtilityType.visitLogs:
        return 'Nhật ký hành trình';
      case UtilityType.friends:
        return 'Bạn bè & Kết nối';
      case UtilityType.reviews:
        return 'Đánh giá của tôi';
      case UtilityType.comments:
        return 'Bình luận & Thảo luận';
      case UtilityType.blogs:
        return 'Bài viết cẩm nang';
      case UtilityType.proposals:
        return 'Đề xuất địa điểm';
      case UtilityType.reports:
        return 'Lịch sử báo cáo vi phạm';
    }
  }

  Widget _buildSubUtilityBody(UtilityType type) {
    switch (type) {
      case UtilityType.favorites:
        return FavoritesSectionWidget(
          onFavoriteChanged: () => _showToast('Đã cập nhật danh sách yêu thích'),
        );

      case UtilityType.visitLogs:
        return VisitedLogSectionWidget(
          onLogChanged: () => _showToast('Đã cập nhật nhật ký chuyến đi'),
          onGoToExplore: () {
            Navigator.of(context).pop();
            if (widget.onNavigateTab != null) {
              widget.onNavigateTab!(1);
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MainNavigationScreen(initialIndex: 1)),
                (route) => false,
              );
            }
          },
        );

      case UtilityType.friends:
        return SingleChildScrollView(
          child: FriendsSectionWidget(
            isDrawer: true,
            onClose: () => Navigator.pop(context),
            onToast: _showToast,
            onFriendsCountChanged: () {},
          ),
        );

      case UtilityType.reviews:
        return _buildReviewsUtilityView();

      case UtilityType.comments:
        return _buildCommentsUtilityView();

      case UtilityType.blogs:
        return _buildBlogsUtilityView();

      case UtilityType.proposals:
        return UserProposalsSectionWidget(
          proposals: _proposals,
          onRefresh: () => _loadUtilityData(UtilityType.proposals),
        );

      case UtilityType.reports:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ReportModalSheet(
            targetInfo: const ReportTargetInfo(
              targetType: ReportTargetType.place,
              targetId: 0,
              targetTitle: 'Trung tâm kiểm duyệt phản ánh',
              targetSubtitle: 'Báo cáo vi phạm cộng đồng',
            ),
            defaultView: ReportModalView.history,
          ),
        );

      case UtilityType.trips:
        return UserTripsSectionWidget(
          isDrawer: true,
          onClose: () => Navigator.pop(context),
          onToast: _showToast,
        );
    }
  }

  // Sub-views for Reviews
  Widget _buildReviewsUtilityView() {
    var filtered = _reviews;
    if (_reviewRatingFilter != null) {
      filtered = filtered.where((r) => r.rating == _reviewRatingFilter).toList();
    }

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.star_outline_rounded,
        title: 'Chưa có bài đánh giá nào',
        desc: 'Khám phá các điểm đến và chia sẻ cảm nhận chân thực cùng cộng đồng nhé!',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final rev = filtered[index];
        return InkWell(
          onTap: () => _navigateToPlace(rev.placeId),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rev.placeName,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: i < rev.rating ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  rev.content,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Sub-views for Comments & Discussions (Lịch sử bình luận & thảo luận với hình ảnh trực quan)
  Widget _buildCommentsUtilityView() {
    if (_comments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chưa có lịch sử bình luận',
        desc: 'Hãy tham gia bình luận tại các bài viết cẩm nang và địa điểm để lưu lại những kỷ niệm đáng nhớ nhé!',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _comments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final com = _comments[index];
        final isReview = com.targetType == 'review' || com.reviewId != null;
        final isBlog = com.targetType == 'blog';

        return InkWell(
          onTap: () {
            if (isBlog) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlogDetailScreen(
                    blog: BlogModel(
                      id: com.placeId.toString(),
                      title: com.displayTitle,
                      summary: com.targetSummary ?? '',
                      content: com.targetSummary ?? '',
                      imageUrl: com.displayImage,
                      publishedDate: com.createdAt,
                      category: 'Cẩm nang du lịch',
                      author: BlogAuthorModel(
                        name: com.parentAuthor ?? 'LangThang',
                        avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&h=200&fit=crop',
                        role: 'Tác giả',
                        rank: 'Thổ địa',
                      ),
                      readTimeMinutes: 5,
                      likesCount: 18,
                      commentsCount: 4,
                    ),
                  ),
                ),
              );
            } else {
              _navigateToPlace(com.placeId);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Post/Place Image Banner with Gradient & Badges
                Stack(
                  children: [
                    SizedBox(
                      height: 125,
                      width: double.infinity,
                      child: buildAppImage(
                        com.displayImage,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Gradient Overlay for text contrast
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Top Badges (Category & Time)
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isBlog
                                  ? const Color(0xFF6D28D9).withValues(alpha: 0.9)
                                  : (isReview ? const Color(0xFF059669).withValues(alpha: 0.9) : const Color(0xFF0284C7).withValues(alpha: 0.9)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isBlog ? Icons.menu_book_outlined : (isReview ? Icons.star_rounded : Icons.place_rounded),
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isBlog ? 'Cẩm nang' : (isReview ? 'Đánh giá' : 'Địa điểm'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (com.createdAt.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 10.5, color: Colors.white70),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    com.createdAt,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Bottom Title Overlay
                    Positioned(
                      bottom: 8,
                      left: 12,
                      right: 12,
                      child: Text(
                        com.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Card Content (Context + User's Comment)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Context: Quoted Author / Snippet
                      if (com.parentAuthor != null && com.parentAuthor!.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(
                              left: BorderSide(color: Color(0xFF0D9488), width: 3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.reply_rounded, size: 12, color: Color(0xFF0D9488)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Phản hồi bình luận của @${com.parentAuthor}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F766E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Original Target Snippet if available
                      if (com.targetSummary != null && com.targetSummary!.isNotEmpty && com.parentAuthor == null) ...[
                        Text(
                          '"${com.targetSummary!}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // User's Comment Bubble
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                com.content,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF14532D),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Card Footer Action Link
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            isBlog ? 'Xem bài viết cẩm nang' : 'Xem chi tiết địa điểm',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF0D9488)),
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
    );
  }

  // Sub-views for Blogs (Quản lý bài viết & bản nháp giống BlogsUtility.tsx)
  Widget _buildBlogsUtilityView() {
    var filtered = _blogs;
    if (_blogStatusFilter != null) {
      filtered = filtered.where((b) => b.status == _blogStatusFilter).toList();
    }

    return Column(
      children: [
        // Status Filter Chips & Action Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildBlogFilterChip('Tất cả', null),
                      const SizedBox(width: 6),
                      _buildBlogFilterChip('Đã xuất bản', 1),
                      const SizedBox(width: 6),
                      _buildBlogFilterChip('Chờ duyệt', 2),
                      const SizedBox(width: 6),
                      _buildBlogFilterChip('Bản nháp', 0),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nút Tạo bài viết mới
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BlogEditorScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Viết bài', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // List View of Blogs / Drafts
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: _blogStatusFilter == 0
                      ? 'Chưa có bản nháp nào'
                      : _blogStatusFilter == 2
                          ? 'Chưa có bài viết chờ duyệt'
                          : 'Chưa có bài viết nào',
                  desc: 'Hãy bấm nút "Viết bài" để chia sẻ cẩm nang du lịch và lưu lại bản nháp nhé!',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final blog = filtered[index];
                    return InkWell(
                      onTap: () async {
                        if (blog.status == 0 || blog.status == 2) {
                          // Bản nháp (0) hoặc Chờ duyệt (2) -> Mở trong Editor
                          Navigator.pop(context);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BlogEditorScreen(
                                blogId: blog.id,
                                initialTitle: blog.title,
                                initialSummary: blog.excerpt,
                                initialCategory: blog.category,
                                initialCategoryId: blog.categoryId,
                                initialCoverUrl: blog.coverImg,
                                initialStatus: blog.status,
                              ),
                            ),
                          );
                        } else {
                          // Đã xuất bản (1) -> Mở màn hình đọc bài viết
                          final blogModel = BlogModel(
                            id: blog.id.toString(),
                            title: blog.title,
                            summary: blog.excerpt,
                            category: blog.category,
                            imageUrl: blog.coverImg,
                            author: const BlogAuthorModel(name: 'Bạn', role: 'Thành viên', rank: 'Lữ khách'),
                            publishedDate: blog.createdAt.isNotEmpty ? blog.createdAt : 'Vừa xong',
                            readTimeMinutes: blog.readTimeMinutes,
                          );
                          Navigator.pop(context);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BlogDetailScreen(blog: blogModel),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: blog.status == 0
                                ? const Color(0xFFCBD5E1)
                                : blog.status == 2
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 70,
                                height: 70,
                                child: blog.coverImg.isNotEmpty
                                    ? Image.network(
                                        blog.coverImg,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: const Color(0xFFF1F5F9),
                                          child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFFF1F5F9),
                                        child: const Icon(Icons.menu_book_outlined, color: Color(0xFF94A3B8)),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status Badge + Category
                                  Row(
                                    children: [
                                      _buildBlogStatusBadge(blog.status),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          blog.category,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    blog.title.isNotEmpty ? blog.title : 'Chưa có tiêu đề',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    blog.status == 1
                                        ? '${blog.viewsCount} xem • ${blog.likesCount} thích'
                                        : blog.status == 0
                                            ? 'Bản nháp chưa xuất bản'
                                            : 'Đang gửi ban quản trị xét duyệt',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: blog.status == 0 ? const Color(0xFF64748B) : (blog.status == 2 ? const Color(0xFFB45309) : const Color(0xFF047857)),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Action / Delete icon
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                              tooltip: 'Xóa',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Xác nhận xóa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    content: Text('Bạn có chắc chắn muốn xóa bài viết "${blog.title}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                                        child: const Text('Xóa'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final res = await _profileApiService.deleteBlog(blog.id);
                                  if (res.success && mounted) {
                                    setState(() {
                                      _blogs.removeWhere((b) => b.id == blog.id);
                                    });
                                    _showToast('Đã xóa bài viết thành công.');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBlogFilterChip(String label, int? status) {
    final isSelected = _blogStatusFilter == status;
    return InkWell(
      onTap: () => setState(() => _blogStatusFilter = status),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildBlogStatusBadge(int status) {
    if (status == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Text('Bản nháp', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
      );
    } else if (status == 2) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 10, color: Color(0xFFB45309)),
            SizedBox(width: 3),
            Text('Chờ duyệt', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Text('Đã xuất bản', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
      );
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
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
      ),
    );
  }
}

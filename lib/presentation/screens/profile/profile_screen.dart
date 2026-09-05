import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/mock/mock_data.dart';
import '../auth/login_screen.dart';
import 'edit_profile_dialog.dart';
import 'change_password_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;
  bool _isLoggedIn = true;
  int _activeTabIndex = 0; // 0: posts, 1: itineraries, 2: saved, 3: suggested

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_user == null) {
      setState(() => _isLoading = true);
    }

    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
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
          _loadCachedOrMock();
        }
      });

      if (!res.success && forceRefresh && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'Không thể làm mới dữ liệu từ máy chủ'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadCachedOrMock() async {
    final cached = await _authService.getCachedUser();
    if (mounted) {
      setState(() {
        _user = cached ?? MockData.currentUser;
      });
    }
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return 'Chưa cập nhật';
    final cleaned = phone.replaceAll(' ', '');
    if (cleaned.length > 6) {
      return '${cleaned.substring(0, 4)} *** ${cleaned.substring(cleaned.length - 3)}';
    }
    return phone;
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

    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.person_outline, size: 38, color: Color(0xFF047857)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bạn chưa đăng nhập',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vui lòng đăng nhập để xem thông tin cá nhân và quản lý hành trình của bạn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Đăng nhập ngay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        ).then((_) => _loadProfile(forceRefresh: true));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final user = _user ?? MockData.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadProfile(forceRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ===== 1. HERO HEADER CARD (Cover + Avatar + Info + Actions) =====
                  _buildHeroHeaderCard(user),

                  const SizedBox(height: 20),

                  // ===== 2. MAIN CONTENT (Responsive 2-column on wide, stacked on mobile) =====
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 768) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: User Info & Reputation Score
                            SizedBox(
                              width: 360,
                              child: Column(
                                children: [
                                  _buildPersonalInfoCard(user),
                                  const SizedBox(height: 16),
                                  _buildReputationScoreCard(user),
                                  const SizedBox(height: 16),
                                  _buildAccountSettingsCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Right Column: Tabs & Tab Content
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTabsNavigation(),
                                  const SizedBox(height: 16),
                                  _buildTabContent(),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildPersonalInfoCard(user),
                            const SizedBox(height: 16),
                            _buildReputationScoreCard(user),
                            const SizedBox(height: 16),
                            _buildTabsNavigation(),
                            const SizedBox(height: 16),
                            _buildTabContent(),
                            const SizedBox(height: 16),
                            _buildAccountSettingsCard(),
                          ],
                        );
                      }
                    },
                  ),

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
        borderRadius: BorderRadius.circular(28),
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
                color: const Color(0xFFE2E8F0),
                child: Image.network(
                  user.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Image.network(
                    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=1920&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black54,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Overlapping Avatar at Bottom Left
              Positioned(
                left: 20,
                bottom: -36,
                child: Container(
                  width: 84,
                  height: 84,
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
                    errorBuilder: (context, error, stackTrace) => Image.network(
                      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200&auto=format&fit=crop',
                      fit: BoxFit.cover,
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
                // Full Name & Rank Badge Row
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons: 2 buttons side-by-side with balanced width
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF334155)),
                        label: const Text(
                          'Sửa hồ sơ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _openEditDialog(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.vpn_key_outlined, size: 15, color: Colors.white),
                        label: const Text(
                          'Đổi mật khẩu',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _openChangePasswordDialog(),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline, size: 18, color: Color(0xFF047857)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Thông tin cá nhân',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Email item
          _buildInfoItem(
            icon: Icons.email_outlined,
            iconBg: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF047857),
            label: 'EMAIL',
            value: user.email.isNotEmpty ? user.email : 'Chưa cập nhật',
          ),
          const SizedBox(height: 14),

          // Phone item
          _buildInfoItem(
            icon: Icons.phone_outlined,
            iconBg: const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFD97706),
            label: 'SỐ ĐIỆN THOẠI',
            value: _formatPhone(user.phone),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== 3. REPUTATION SCORE CARD ====================
  Widget _buildReputationScoreCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_outlined, size: 18, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Điểm cống hiến',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Score highlight box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  const Color(0xFFF59E0B).withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
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
          const SizedBox(height: 12),
          const Text(
            'Điểm cống hiến được tích lũy thông qua việc đóng góp địa điểm, viết review chất lượng và chia sẻ lịch trình hữu ích.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.5),
          ),
        ],
      ),
    );
  }

  // ==================== 4. ACCOUNT SETTINGS CARD ====================
  Widget _buildAccountSettingsCard() {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.lock_reset_outlined, size: 18, color: Color(0xFF047857)),
            ),
            title: const Text('Đổi mật khẩu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
            onTap: () => _openChangePasswordDialog(),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.logout, size: 18, color: Color(0xFFEF4444)),
            ),
            title: const Text('Đăng xuất tài khoản', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
            trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFEF4444)),
            onTap: () => _confirmLogout(),
          ),
        ],
      ),
    );
  }

  // ==================== 5. TABS NAVIGATION ====================
  Widget _buildTabsNavigation() {
    final tabs = [
      {'title': 'Bài viết (0)', 'icon': Icons.menu_book_outlined},
      {'title': 'Lịch trình (0)', 'icon': Icons.explore_outlined},
      {'title': 'Đã lưu (0)', 'icon': Icons.bookmark_border_outlined},
      {'title': 'Đề xuất (0)', 'icon': Icons.add_circle_outline},
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 450;
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(tabs.length, (index) {
              final isSelected = _activeTabIndex == index;
              return InkWell(
                onTap: () => setState(() => _activeTabIndex = index),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 12 : 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabs[index]['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabs[index]['title'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // ==================== 6. TAB CONTENT (EMPTY STATES) ====================
  Widget _buildTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return _buildEmptyState(
          icon: Icons.article_outlined,
          iconBg: const Color(0xFFECFDF5),
          iconColor: const Color(0xFF047857),
          title: 'Chưa có bài viết nào',
          description: 'Bạn chưa đăng bài viết chia sẻ kinh nghiệm du lịch nào. Hãy viết bài đầu tiên để chia sẻ với cộng đồng LangThang!',
        );
      case 1:
        return _buildEmptyState(
          icon: Icons.explore_outlined,
          iconBg: const Color(0xFFFFFBEB),
          iconColor: const Color(0xFFD97706),
          title: 'Chưa có lịch trình nào',
          description: 'Bạn chưa lên lịch trình khám phá nào. Hãy tạo kế hoạch cho chuyến đi tiếp theo của bạn!',
        );
      case 2:
        return _buildEmptyState(
          icon: Icons.bookmark_border_outlined,
          iconBg: const Color(0xFFF1F5F9),
          iconColor: const Color(0xFF475569),
          title: 'Chưa lưu địa điểm nào',
          description: 'Danh sách các địa điểm yêu thích của bạn đang trống. Hãy dạo quanh trang chủ để lưu lại các địa điểm hấp dẫn!',
        );
      case 3:
      default:
        return _buildEmptyState(
          icon: Icons.inbox_outlined,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF2563EB),
          title: 'Chưa có đề xuất địa điểm nào',
          description: 'Bạn chưa gửi đề xuất địa điểm mới nào cho hệ thống. Đóng góp địa điểm để tích lũy điểm cống hiến nhé!',
        );
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DIALOGS ====================
  void _openEditDialog() {
    final current = _user ?? MockData.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => EditProfileDialog(
        user: current,
        onSave: ({
          required updatedUser,
          avatarFilePath,
          coverFilePath,
        }) async {
          final res = await _authService.updateProfile(
            fullName: updatedUser.fullName,
            phone: updatedUser.phone,
            bio: updatedUser.bio,
            avatarFilePath: avatarFilePath,
            coverFilePath: coverFilePath,
          );
          if (res.success) {
            if (mounted) {
              setState(() => _user = res.data ?? updatedUser);
            }
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Đã lưu thay đổi hồ sơ thành công.'),
                backgroundColor: Color(0xFF047857),
              ),
            );
            return null;
          } else {
            final errorMsg = (res.errors != null && res.errors!.isNotEmpty)
                ? res.errors!.join('\n')
                : (res.message.isNotEmpty ? res.message : 'Cập nhật thất bại');
            return errorMsg;
          }
        },
      ),
    );
  }

  void _openChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            child: const Text(
              'Đăng xuất',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

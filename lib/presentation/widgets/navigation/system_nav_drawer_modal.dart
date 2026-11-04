import 'package:flutter/material.dart';
import '../../../data/services/auth_service.dart';
import '../../screens/leaderboard/leaderboard_index_screen.dart';

class SystemNavDrawerModal extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final String activeRoute;

  const SystemNavDrawerModal({
    super.key,
    this.onNavigateTab,
    this.activeRoute = 'rankings',
  });

  static Future<void> show(
    BuildContext context, {
    Function(int)? onNavigateTab,
    String activeRoute = 'home',
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'NavigationDrawer',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: SystemNavDrawerModal(
              onNavigateTab: onNavigateTab,
              activeRoute: activeRoute,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  State<SystemNavDrawerModal> createState() => _SystemNavDrawerModalState();
}

class _SystemNavDrawerModalState extends State<SystemNavDrawerModal> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = await AuthService().getCachedUser();
    if (user != null && mounted) {
      final role = user.jobTitle.toLowerCase();
      setState(() {
        _isAdmin = role.contains('quản trị') || role.contains('admin');
      });
    }
  }

  void _onItemTap(String route, int? tabIndex) {
    Navigator.of(context).pop();
    if (route == 'rankings') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LeaderboardIndexScreen(
            onNavigateTab: widget.onNavigateTab,
          ),
        ),
      );
    } else if (tabIndex != null && widget.onNavigateTab != null) {
      widget.onNavigateTab!(tabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.78).clamp(280.0, 340.0);

    return Container(
      width: drawerWidth,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with logo and close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.6,
                      ),
                      children: [
                        TextSpan(text: 'LangThang'),
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    tooltip: 'Đóng menu',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  // Section: KHÁM PHÁ HỆ THỐNG
                  const Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 8),
                    child: Text(
                      'KHÁM PHÁ HỆ THỐNG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  _buildNavItem(
                    title: 'Trang chủ',
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    isActive: widget.activeRoute == 'home',
                    onTap: () => _onItemTap('home', 0),
                  ),
                  const SizedBox(height: 3),

                  _buildNavItem(
                    title: 'Khám phá',
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore_rounded,
                    isActive: widget.activeRoute == 'explore',
                    onTap: () => _onItemTap('explore', 1),
                  ),
                  const SizedBox(height: 3),

                  _buildNavItem(
                    title: 'Bảng xếp hạng',
                    icon: Icons.emoji_events_outlined,
                    activeIcon: Icons.emoji_events_rounded,
                    isActive: widget.activeRoute == 'rankings',
                    onTap: () => _onItemTap('rankings', null),
                  ),
                  const SizedBox(height: 3),

                  _buildNavItem(
                    title: 'Bản đồ',
                    icon: Icons.location_on_outlined,
                    activeIcon: Icons.location_on_rounded,
                    isActive: widget.activeRoute == 'map',
                    onTap: () => _onItemTap('map', 2),
                  ),
                  const SizedBox(height: 3),

                  _buildNavItem(
                    title: 'Chuyến đi',
                    icon: Icons.alt_route_rounded,
                    activeIcon: Icons.alt_route_rounded,
                    isActive: widget.activeRoute == 'itinerary',
                    onTap: () => _onItemTap('itinerary', 3),
                  ),
                  const SizedBox(height: 3),

                  _buildNavItem(
                    title: 'Cẩm nang',
                    icon: Icons.menu_book_outlined,
                    activeIcon: Icons.menu_book_rounded,
                    isActive: widget.activeRoute == 'blog',
                    onTap: () => _onItemTap('blog', 4),
                  ),

                  // Section: QUẢN TRỊ (if admin)
                  if (_isAdmin) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFFF1F5F9), height: 1),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 12, bottom: 8),
                      child: Text(
                        'QUẢN TRỊ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildNavItem(
                      title: 'Trang quản trị',
                      icon: Icons.shield_outlined,
                      activeIcon: Icons.shield_rounded,
                      isActive: widget.activeRoute == 'admin',
                      onTap: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng truy cập trang quản trị trên bản web để sử dụng đầy đủ tính năng.'),
                            backgroundColor: Color(0xFF065F46),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String title,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11.5),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFECFDF5) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isActive
                ? Border.all(color: const Color(0xFFA7F3D0), width: 1)
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 20,
                color: isActive ? const Color(0xFF047857) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? const Color(0xFF065F46) : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

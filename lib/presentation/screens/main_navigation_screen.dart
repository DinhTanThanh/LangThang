import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'home/home_screen.dart';
import 'destinations/destinations_screen.dart';
import 'destinations/travel_map_screen.dart';
import 'itineraries/itineraries_screen.dart';
import 'blog/blog_screen.dart';
import 'profile/profile_screen.dart';
import '../widgets/common/recent_visited_floating_dock.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  final GlobalKey<DestinationsScreenState> _destinationsKey = GlobalKey<DestinationsScreenState>();
  final Set<int> _loadedIndices = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadedIndices.add(_currentIndex);
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _loadedIndices.add(index);
    });
  }

  void _onNavigateToSearch({String? query, String? region, String? category}) {
    setState(() {
      _currentIndex = 1;
      _loadedIndices.add(1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _destinationsKey.currentState?.applySearch(
        query: query,
        region: region,
        category: category,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _loadedIndices.contains(0)
          ? HomeScreen(
              onNavigateTab: _onTabTapped,
              onNavigateToSearch: _onNavigateToSearch,
            )
          : const SizedBox.shrink(),
      _loadedIndices.contains(1)
          ? DestinationsScreen(key: _destinationsKey)
          : const SizedBox.shrink(),
      _loadedIndices.contains(2)
          ? const TravelMapScreen()
          : const SizedBox.shrink(),
      _loadedIndices.contains(3)
          ? const ItinerariesScreen()
          : const SizedBox.shrink(),
      _loadedIndices.contains(4)
          ? const BlogScreen()
          : const SizedBox.shrink(),
      _loadedIndices.contains(5)
          ? ProfileScreen(onNavigateTab: _onTabTapped)
          : const SizedBox.shrink(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          RecentVisitedFloatingDock(
            bottomMargin: 16,
            onOpenProfile: () => _onTabTapped(5),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 10),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Điểm đến',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Bản đồ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.route_outlined),
              activeIcon: Icon(Icons.route),
              label: 'Lịch trình',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Cẩm nang',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}

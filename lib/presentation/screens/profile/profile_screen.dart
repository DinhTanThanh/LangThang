import 'package:flutter/material.dart';
import 'user_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const ProfileScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    return UserProfileScreen(
      userId: null,
      isRootProfile: true,
      onNavigateTab: onNavigateTab,
    );
  }
}

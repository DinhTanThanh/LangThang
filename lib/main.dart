import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/destinations/destinations_screen.dart';
import 'presentation/screens/destinations/collections_screen.dart';
import 'presentation/screens/food/food_screen.dart';
import 'presentation/screens/itineraries/itineraries_screen.dart';
import 'presentation/screens/blog/blog_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    HttpOverrides.global = DevHttpOverrides();
  }
  runApp(const LangThangApp());
}

class LangThangApp extends StatelessWidget {
  const LangThangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LangThang - Du lịch & Ẩm thực Việt Nam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainNavigationScreen(),
      routes: {
        '/main': (context) => const MainNavigationScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/destinations': (context) => const DestinationsScreen(),
        '/collections': (context) => const CollectionsScreen(),
        '/food': (context) => const FoodScreen(),
        '/itineraries': (context) => const ItinerariesScreen(),
        '/blogs': (context) => const BlogScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

// ============================================================================
// NETFLIX PRO MOBILE MAIN ENTRY POINT (FINAL ERROR-FREE)
// ============================================================================
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tmdb_config.dart';
import 'mobile_home_screen.dart';

void main() {
  HttpOverrides.global = MobileHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NetflixMobileApp());
}

class NetflixMobileApp extends StatelessWidget {
  const NetflixMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        fontFamily: 'sans-serif',
      ),
      home: const NetflixSplashScreen(),
    );
  }
}

// ============================================================================
// NETFLIX INTRO / SPLASH SCREEN
// ============================================================================
class NetflixSplashScreen extends StatefulWidget {
  const NetflixSplashScreen({super.key});

  @override
  State<NetflixSplashScreen> createState() => _NetflixSplashScreenState();
}

class _NetflixSplashScreenState extends State<NetflixSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            // Fixed: Pointing to MobileRootScreen which safely wraps bottom navigation & providers
            pageBuilder: (_, __, ___) => const MobileRootScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'N',
                      style: TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 90,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.0,
                        fontFamily: 'Helvetica Neue',
                        shadows: [
                          Shadow(
                            blurRadius: 25.0,
                            color: Color(0x99E50914),
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'NETFLIX PRO',
                      style: TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4.0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// NETFLIX PRO TV MAIN ENTRY POINT ('N' RIBBON + ZOOM-THROUGH SPLASH)
// ============================================================================
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_config.dart';
import 'tv_home_screen.dart';

void main() async {
  HttpOverrides.global = TVHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  bool skipIntro = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastIntroMs = prefs.getInt('tv_last_intro_ms') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Agar pichle 4 ghante (14400000 ms) me intro chal chuka hai, to dubara nahi chalega
    if (nowMs - lastIntroMs < 14400000) {
      skipIntro = true;
    }
  } catch (_) {}

  runApp(NetflixTvApp(skipIntro: skipIntro));
}

class NetflixTvApp extends StatelessWidget {
  final bool skipIntro;

  const NetflixTvApp({super.key, required this.skipIntro});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        fontFamily: 'sans-serif',
      ),
      // ऑटो-पॉपअप नहीं खुलेगा; सीधे TvHomeScreen खुलेगी (जहाँ Sidebar में Gist लिंक बटन है)
      home: skipIntro ? const TvHomeScreen() : const NetflixNIntroScreen(),
    );
  }
}

// ============================================================================
// REAL NETFLIX 'N' RIBBON DRAW + ZOOM-THROUGH ANIMATION (STORAGE LOCKED)
// ============================================================================
class NetflixNIntroScreen extends StatefulWidget {
  const NetflixNIntroScreen({super.key});

  @override
  State<NetflixNIntroScreen> createState() => _NetflixNIntroScreenState();
}

class _NetflixNIntroScreenState extends State<NetflixNIntroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _leftBarProgress;
  late Animation<double> _diagonalBarProgress;
  late Animation<double> _rightBarProgress;
  late Animation<double> _zoomScale;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _saveIntroTimestamp();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _leftBarProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.22, curve: Curves.easeOutCubic),
      ),
    );

    _diagonalBarProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.18, 0.42, curve: Curves.easeInOutCubic),
      ),
    );

    _rightBarProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _zoomScale = Tween<double>(begin: 1.0, end: 22.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 1.0, curve: Curves.easeInExpo),
      ),
    );

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.82, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 450),
            pageBuilder: (_, __, ___) => const TvHomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  Future<void> _saveIntroTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'tv_last_intro_ms',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
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
          builder: (context, _) {
            return Opacity(
              opacity: _fadeOut.value,
              child: Transform.scale(
                scale: _zoomScale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 150,
                      height: 220,
                      decoration: BoxDecoration(
                        boxShadow: [
                          if (_diagonalBarProgress.value > 0.3)
                            BoxShadow(
                              color: const Color(0xFFE50914)
                                  .withOpacity(0.35 * _rightBarProgress.value),
                              blurRadius: 60,
                              spreadRadius: 8,
                            ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: _NetflixNPainter(
                          leftProgress: _leftBarProgress.value,
                          diagProgress: _diagonalBarProgress.value,
                          rightProgress: _rightBarProgress.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: (_rightBarProgress.value *
                              (1.0 - (_zoomScale.value - 1.0).clamp(0.0, 1.0)))
                          .clamp(0.0, 1.0),
                      child: const Text(
                        'N E T F L I X   P R O',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                        ),
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

class _NetflixNPainter extends CustomPainter {
  final double leftProgress;
  final double diagProgress;
  final double rightProgress;

  _NetflixNPainter({
    required this.leftProgress,
    required this.diagProgress,
    required this.rightProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double barW = w * 0.28;

    final Paint sideBarPaint = Paint()
      ..color = const Color(0xFFB1060F)
      ..style = PaintingStyle.fill;

    if (leftProgress > 0) {
      final double currentTop = h * (1.0 - leftProgress);
      canvas.drawRect(Rect.fromLTRB(0, currentTop, barW, h), sideBarPaint);
    }

    if (rightProgress > 0) {
      final double currentTop = h * (1.0 - rightProgress);
      canvas.drawRect(Rect.fromLTRB(w - barW, currentTop, w, h), sideBarPaint);
    }

    if (diagProgress > 0) {
      final double endXTop = barW + (w - barW) * diagProgress;
      final double endXBottom = (w - barW) * diagProgress;
      final double endY = h * diagProgress;

      final Path diagPath = Path()
        ..moveTo(0, 0)
        ..lineTo(barW, 0)
        ..lineTo(endXTop, endY)
        ..lineTo(endXBottom, endY)
        ..close();

      canvas.drawShadow(diagPath, Colors.black, 14.0, true);

      final Paint diagPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF1F2A),
            Color(0xFFE50914),
            Color(0xFFC90812),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.fill;

      canvas.drawPath(diagPath, diagPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetflixNPainter oldDelegate) {
    return oldDelegate.leftProgress != leftProgress ||
        oldDelegate.diagProgress != diagProgress ||
        oldDelegate.rightProgress != rightProgress;
  }
}
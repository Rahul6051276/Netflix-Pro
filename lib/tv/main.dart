import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tmdb_config.dart';
import 'tv_home_screen.dart';

void main() {
  HttpOverrides.global = TVHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const NetflixTvApp());
}

class NetflixTvApp extends StatelessWidget {
  const NetflixTvApp({super.key});

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
      home: const TvHomeScreen(),
    );
  }
}

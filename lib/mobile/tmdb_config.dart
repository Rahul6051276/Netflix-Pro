import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

// SSL Handshake Override
class MobileHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

// Global Configuration
class MobileConfig {
  static const String _gistPrefKey = 'custom_gist_raw_url';

  // GitHub Actions Secrets se aayegi (koi hardcoded key nahi)
  static const String tmdbKey =
      String.fromEnvironment('TMDB_KEY', defaultValue: '');

  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String imgBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/w1280';

  static Future<String> getGistUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return (prefs.getString(_gistPrefKey) ?? '').trim();
  }

  static Future<void> saveGistUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gistPrefKey, url.trim());
  }
}

// Strict Daily Soap & TV Serial Filter
bool isSoapShow(String title) {
  final t = title.toLowerCase();
  const blocked = [
    'c.i.d.', 'cid', 'bhabiji', 'balika vadhu', 'kapil sharma', 'roadies',
    'pavitra rishta', 'kumkum bhagya', 'jhanak', 'kundali bhagya',
    'ye rishta', 'yrkkh', 'taarak mehta', 'tmkoc', 'kasautii', 'ishqbaaaz',
    'anupamaa', 'bigg boss', 'khatron ke khiladi', 'splitsvilla',
    'crime patrol', 'savdhaan india', 'diya aur baati', 'qubool hai',
    'jamai raja', 'tujhse hai raabta', 'radhakrishn', 'koffee with karan',
    'chudail', 'sasural', 'fitoor', 'bhojpuri', 'nagin', 'naagin', 'parineetii',
    'udaariyaan', 'imlie', 'ghukk', 'shravani', 'suhaagan', 'dharampatnii',
    'lo chudail', 'chali sasural'
  ];
  return blocked.any((b) => t.contains(b));
}
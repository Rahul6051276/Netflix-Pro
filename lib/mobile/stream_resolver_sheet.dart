// ============================================================================
// 4. MORE SCREEN (ONLY REQUESTED OTT WEB SERIES HUB WITH FILTERS)
// ============================================================================
class MobileMoreScreen extends StatelessWidget {
  final List<dynamic> providers;
  const MobileMoreScreen({super.key, required this.providers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('OTT Web Series Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Netflix Web Series
          ListTile(
            leading: const Icon(Icons.video_collection, color: Color(0xFFE50914)),
            title: const Text('Netflix Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Netflix Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=213&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 2. Amazon Web Series
          ListTile(
            leading: const Icon(Icons.video_library, color: Color(0xFFE50914)),
            title: const Text('Amazon Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Amazon Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=1024&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 3. Disney+ Hotstar Web Series
          ListTile(
            leading: const Icon(Icons.live_tv, color: Color(0xFFE50914)),
            title: const Text('Disney+ Hotstar Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Disney+ Hotstar Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=2739&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 4. Zee5 Web Series
          ListTile(
            leading: const Icon(Icons.tv_rounded, color: Color(0xFFE50914)),
            title: const Text('Zee5 Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Zee5 Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=2377&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 5. SonyLIV Web Series
          ListTile(
            leading: const Icon(Icons.monitor_rounded, color: Color(0xFFE50914)),
            title: const Text('SonyLIV Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'SonyLIV Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=2334&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/file_manager_tab.dart';
import 'screens/library_playlists_tab.dart';
import 'screens/youtube_browser_tab.dart';
import 'services/app_state.dart';
import 'widgets/apple_music_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AppleMusicYTApp());
}

class AppleMusicYTApp extends StatefulWidget {
  const AppleMusicYTApp({super.key});

  @override
  State<AppleMusicYTApp> createState() => _AppleMusicYTAppState();
}

class _AppleMusicYTAppState extends State<AppleMusicYTApp> {
  final AppState _appState = AppState();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apple Music YT Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF111113),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pinkAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: ListenableBuilder(
        listenable: _appState,
        builder: (context, _) {
          return Scaffold(
            body: SafeArea(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  YoutubeBrowserTab(appState: _appState),
                  LibraryPlaylistsTab(appState: _appState),
                  FileManagerTab(appState: _appState),
                ],
              ),
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppleMusicMiniPlayer(appState: _appState),
                NavigationBar(
                  height: 66,
                  backgroundColor: const Color(0xFF18181B),
                  indicatorColor: Colors.pinkAccent.withOpacity(0.22),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) {
                    setState(() => _selectedIndex = idx);
                  },
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.public_rounded),
                      selectedIcon: Icon(Icons.public_rounded, color: Colors.pinkAccent),
                      label: 'YouTube',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.library_music_outlined),
                      selectedIcon: Icon(Icons.library_music_rounded, color: Colors.pinkAccent),
                      label: 'Biblioteca',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: _appState.activeDownloads
                            .any((d) => d.status == 'Descargando...'),
                        child: const Icon(Icons.folder_outlined),
                      ),
                      selectedIcon: const Icon(Icons.folder_rounded, color: Colors.pinkAccent),
                      label: 'Archivos',
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

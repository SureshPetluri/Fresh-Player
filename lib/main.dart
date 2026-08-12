import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fresh_player/theme/app_theme.dart';
import 'folders_showing_screen.dart';
import 'video_player_for_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fresh Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: kIsWeb ? const VideoPlayerForWeb() : const FoldersShowingScreen(),
    );
  }
}

